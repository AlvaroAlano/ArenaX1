-- Execute este script no SQL Editor do seu painel Supabase (depois do 12).
--
-- Terceiro bug real encontrado reverificando o fluxo depois do 12: a final
-- e a disputa de 3º lugar podem terminar em QUALQUER ordem (não existe
-- garantia de que a final acaba depois do 3º lugar) — mas assim que a final
-- resolve, `tournaments.status` vira 'completed', e tanto
-- fn_submit_online_match_result quanto fn_resolve_online_match_dispute
-- recusavam qualquer ação com `TOURNAMENT_NOT_IN_PROGRESS` se o torneio não
-- estivesse mais 'in_progress'. Resultado: se a final terminasse ANTES da
-- disputa de 3º lugar (bem comum — cada partida termina no seu tempo), a
-- partida de 3º/4º lugar ficava travada pra sempre em `status='ready'`,
-- sem ninguém conseguir reportar resultado — os dois jogadores nunca
-- recebiam prêmio, reembolso ou liberação do saldo travado.
--
-- Testado na prática: um torneio de 4 onde a final foi resolvida primeiro
-- deixou a partida de 3º lugar travada em 'ready' com o torneio já
-- 'completed' — tentar submeter o resultado dela batia direto nesse erro.
--
-- Correção: o guard de status do torneio passa a aceitar também
-- 'completed' (não só 'in_progress') — quem realmente impede reenviar
-- resultado de uma partida já decidida é o status da PRÓPRIA PARTIDA
-- (`v_match.status != 'ready'`, que já existia e continua intacto), então
-- relaxar esse guard não abre brecha nenhuma pra resultado duplicado.

CREATE OR REPLACE FUNCTION public.fn_submit_online_match_result(
  p_tournament_id uuid,
  p_match_id uuid,
  p_user_id uuid,
  p_result text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_match public.tournament_matches;
  v_side text;
  v_winner_id uuid;
  v_loser_id uuid;
  v_total_rounds int;
  v_next_round int;
  v_next_slot int;
  v_next_match public.tournament_matches;
  v_third_match public.tournament_matches;
  v_net_pool numeric;
  v_adjusted_pool numeric;
  v_fourth_refund numeric;
  v_wallet_id uuid;
BEGIN
  IF p_result NOT IN ('win', 'loss') THEN
    RAISE EXCEPTION 'INVALID_RESULT: Resultado inválido. Deve ser ''win'' ou ''loss''.';
  END IF;

  SELECT * INTO v_tournament FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Torneio não encontrado.';
  END IF;
  IF v_tournament.type != 'online_paid' THEN
    RAISE EXCEPTION 'INVALID_TOURNAMENT_TYPE: Este torneio não usa reporte por consenso.';
  END IF;
  IF v_tournament.status NOT IN ('in_progress', 'completed') THEN
    RAISE EXCEPTION 'TOURNAMENT_NOT_IN_PROGRESS: Este torneio não está com a chave em andamento.';
  END IF;

  SELECT * INTO v_match FROM public.tournament_matches
    WHERE id = p_match_id AND tournament_id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Partida não encontrada.';
  END IF;
  IF v_match.status != 'ready' THEN
    RAISE EXCEPTION 'MATCH_NOT_READY: Esta partida ainda não pode receber um resultado.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.tournament_participants WHERE id = v_match.participant_a_id AND user_id = p_user_id) THEN
    v_side := 'a';
  ELSIF EXISTS (SELECT 1 FROM public.tournament_participants WHERE id = v_match.participant_b_id AND user_id = p_user_id) THEN
    v_side := 'b';
  ELSE
    RAISE EXCEPTION 'FORBIDDEN: Você não faz parte desta partida.';
  END IF;

  IF v_side = 'a' THEN
    IF v_match.result_a IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado desta partida.';
    END IF;
    UPDATE public.tournament_matches SET result_a = p_result WHERE id = p_match_id RETURNING * INTO v_match;
  ELSE
    IF v_match.result_b IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado desta partida.';
    END IF;
    UPDATE public.tournament_matches SET result_b = p_result WHERE id = p_match_id RETURNING * INTO v_match;
  END IF;

  IF v_match.result_a IS NULL OR v_match.result_b IS NULL THEN
    RETURN jsonb_build_object('status', 'waiting', 'message', 'Resultado reportado. Aguardando o oponente confirmar.');
  END IF;

  -- Divergência: os dois reportaram o mesmo lado (dois "win" ou dois "loss").
  IF NOT ((v_match.result_a = 'win' AND v_match.result_b = 'loss') OR (v_match.result_a = 'loss' AND v_match.result_b = 'win')) THEN
    UPDATE public.tournament_matches SET status = 'disputed' WHERE id = p_match_id;
    INSERT INTO public.disputes (tournament_match_id, status) VALUES (p_match_id, 'open');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'match_disputed', 'Resultado em disputa ⚠️',
      'Sua partida no torneio "' || v_tournament.title || '" teve resultados divergentes e foi pra mediação da ArenaX1.',
      p_tournament_id, p_match_id
    FROM public.tournament_participants tp
    WHERE tp.id IN (v_match.participant_a_id, v_match.participant_b_id);

    RETURN jsonb_build_object('status', 'disputed', 'message', 'Resultados divergentes. Partida em disputa — a moderação da ArenaX1 vai analisar.');
  END IF;

  v_winner_id := CASE WHEN v_match.result_a = 'win' THEN v_match.participant_a_id ELSE v_match.participant_b_id END;
  v_loser_id := CASE WHEN v_match.result_a = 'win' THEN v_match.participant_b_id ELSE v_match.participant_a_id END;

  UPDATE public.tournament_matches
  SET winner_participant_id = v_winner_id, status = 'completed', completed_at = now()
  WHERE id = p_match_id
  RETURNING * INTO v_match;

  v_total_rounds := CASE v_tournament.max_players WHEN 4 THEN 2 WHEN 8 THEN 3 WHEN 16 THEN 4 END;
  v_net_pool := v_tournament.prize_pool - v_tournament.rake_amount;
  -- Em torneios de 8/16, reserva 1 taxa de inscrição pra devolver ao 4º
  -- lugar (empate, sem lucro) — os 50/30/20% de sempre passam a incidir
  -- sobre o que sobra. Em torneios de 4 nada muda (reembolso = 0).
  v_fourth_refund := CASE WHEN v_tournament.max_players > 4 THEN v_tournament.entry_fee ELSE 0 END;
  v_adjusted_pool := v_net_pool - v_fourth_refund;

  -- Disputa de 3º lugar: paga o vencedor e libera o valor travado dos DOIS
  -- (pra quem participou dessa partida, o torneio acabou aqui).
  IF v_match.is_third_place THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;

    UPDATE public.wallets SET balance = balance + round(v_adjusted_pool * 0.2, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_adjusted_pool * 0.2, 2), 'completed',
      '3º lugar no torneio "' || v_tournament.title || '"');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
      'Você ficou em 3º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_adjusted_pool * 0.2, 2) || '.',
      p_tournament_id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    -- 4º lugar (perdeu a disputa de 3º): em torneios de 8/16, recebe de
    -- volta a própria inscrição (empate, sem lucro).
    IF v_fourth_refund > 0 THEN
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_loser_id;

      UPDATE public.wallets SET balance = balance + v_fourth_refund, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'bet_refund', v_fourth_refund, 'completed',
        '4º lugar no torneio "' || v_tournament.title || '" — inscrição devolvida');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Inscrição de volta 💸',
        'Você ficou em 4º lugar no torneio "' || v_tournament.title || '" — sem prêmio, mas sua inscrição de R$ ' || v_fourth_refund || ' voltou pra sua carteira.',
        p_tournament_id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_loser_id;
    END IF;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (
      SELECT user_id FROM public.tournament_participants WHERE id IN (v_match.participant_a_id, v_match.participant_b_id)
    );

    UPDATE public.tournaments SET third_place_participant_id = v_winner_id WHERE id = p_tournament_id;

    RETURN jsonb_build_object('status', 'completed', 'tournament_completed', false, 'match', to_jsonb(v_match));
  END IF;

  -- Final: paga campeão (50%) e vice (30%), libera o valor travado dos dois, fecha o torneio.
  IF v_match.round = v_total_rounds THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;
    UPDATE public.wallets SET balance = balance + round(v_adjusted_pool * 0.5, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_adjusted_pool * 0.5, 2), 'completed',
      'Campeão do torneio "' || v_tournament.title || '"');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Você é o campeão 🏆',
      'Você venceu o torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_adjusted_pool * 0.5, 2) || '.',
      p_tournament_id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_loser_id;
    UPDATE public.wallets SET balance = balance + round(v_adjusted_pool * 0.3, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_adjusted_pool * 0.3, 2), 'completed',
      'Vice-campeão do torneio "' || v_tournament.title || '"');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
      'Você ficou em 2º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_adjusted_pool * 0.3, 2) || '.',
      p_tournament_id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_loser_id;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (
      SELECT user_id FROM public.tournament_participants WHERE id IN (v_winner_id, v_loser_id)
    );

    UPDATE public.tournaments
    SET status = 'completed', completed_at = now(),
        champion_participant_id = v_winner_id,
        runner_up_participant_id = v_loser_id
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('status', 'completed', 'tournament_completed', true, 'champion_participant_id', v_winner_id, 'match', to_jsonb(v_match));
  END IF;

  -- Rodadas anteriores à final: propaga o vencedor pro slot certo da
  -- próxima rodada (mesma aritmética de fn_submit_tournament_match_result).
  v_next_round := v_match.round + 1;
  v_next_slot := v_match.slot / 2;

  IF v_match.slot % 2 = 0 THEN
    UPDATE public.tournament_matches SET participant_a_id = v_winner_id
    WHERE tournament_id = p_tournament_id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  ELSE
    UPDATE public.tournament_matches SET participant_b_id = v_winner_id
    WHERE tournament_id = p_tournament_id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  END IF;

  IF v_next_match.participant_a_id IS NOT NULL AND v_next_match.participant_b_id IS NOT NULL THEN
    UPDATE public.tournament_matches SET status = 'ready' WHERE id = v_next_match.id RETURNING * INTO v_next_match;

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT pa.user_id, 'match_ready', 'Sua partida está pronta ⚔️',
      'Você avançou! Enfrente ' || pb.display_name || ' em "' || v_tournament.title || '". Reporta o resultado assim que jogar.',
      p_tournament_id, v_next_match.id
    FROM public.tournament_participants pa, public.tournament_participants pb
    WHERE pa.id = v_next_match.participant_a_id AND pb.id = v_next_match.participant_b_id
    UNION ALL
    SELECT pb.user_id, 'match_ready', 'Sua partida está pronta ⚔️',
      'Você avançou! Enfrente ' || pa.display_name || ' em "' || v_tournament.title || '". Reporta o resultado assim que jogar.',
      p_tournament_id, v_next_match.id
    FROM public.tournament_participants pa, public.tournament_participants pb
    WHERE pa.id = v_next_match.participant_a_id AND pb.id = v_next_match.participant_b_id;
  END IF;

  IF v_match.round = v_total_rounds - 1 THEN
    -- Semifinal: o perdedor vai pra disputa de 3º lugar (ainda tem uma
    -- partida pela frente) — mesma rodada da final, slot fixo 1.
    IF v_match.slot % 2 = 0 THEN
      UPDATE public.tournament_matches SET participant_a_id = v_loser_id
      WHERE tournament_id = p_tournament_id AND round = v_total_rounds AND slot = 1
      RETURNING * INTO v_third_match;
    ELSE
      UPDATE public.tournament_matches SET participant_b_id = v_loser_id
      WHERE tournament_id = p_tournament_id AND round = v_total_rounds AND slot = 1
      RETURNING * INTO v_third_match;
    END IF;

    IF v_third_match.participant_a_id IS NOT NULL AND v_third_match.participant_b_id IS NOT NULL THEN
      UPDATE public.tournament_matches SET status = 'ready' WHERE id = v_third_match.id;

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT pa.user_id, 'match_ready', 'Disputa de 3º lugar ⚔️',
        'Você caiu na semifinal, mas ainda dá pra faturar: enfrente ' || pb.display_name || ' na disputa de 3º lugar de "' || v_tournament.title || '".',
        p_tournament_id, v_third_match.id
      FROM public.tournament_participants pa, public.tournament_participants pb
      WHERE pa.id = v_third_match.participant_a_id AND pb.id = v_third_match.participant_b_id
      UNION ALL
      SELECT pb.user_id, 'match_ready', 'Disputa de 3º lugar ⚔️',
        'Você caiu na semifinal, mas ainda dá pra faturar: enfrente ' || pa.display_name || ' na disputa de 3º lugar de "' || v_tournament.title || '".',
        p_tournament_id, v_third_match.id
      FROM public.tournament_participants pa, public.tournament_participants pb
      WHERE pa.id = v_third_match.participant_a_id AND pb.id = v_third_match.participant_b_id;
    END IF;
  ELSE
    -- Rodada anterior à semifinal (só existe em torneios de 8/16 jogadores):
    -- o perdedor é eliminado sem chance de 3º lugar — libera o valor
    -- travado dele agora, sem prêmio.
    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (SELECT user_id FROM public.tournament_participants WHERE id = v_loser_id);
  END IF;

  RETURN jsonb_build_object('status', 'completed', 'tournament_completed', false, 'match', to_jsonb(v_match), 'next_match', to_jsonb(v_next_match));
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_resolve_online_match_dispute(
  p_match_id uuid,
  p_winner_participant_id uuid,
  p_admin_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match public.tournament_matches;
  v_tournament public.tournaments;
  v_winner_id uuid;
  v_loser_id uuid;
  v_loser_user_id uuid;
  v_new_rating numeric;
  v_total_rounds int;
  v_next_round int;
  v_next_slot int;
  v_next_match public.tournament_matches;
  v_third_match public.tournament_matches;
  v_net_pool numeric;
  v_adjusted_pool numeric;
  v_fourth_refund numeric;
  v_wallet_id uuid;
BEGIN
  SELECT * INTO v_match FROM public.tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Partida não encontrada.';
  END IF;
  IF v_match.status != 'disputed' THEN
    RAISE EXCEPTION 'MATCH_NOT_DISPUTED: Esta partida não está em disputa.';
  END IF;
  IF p_winner_participant_id NOT IN (v_match.participant_a_id, v_match.participant_b_id) THEN
    RAISE EXCEPTION 'INVALID_WINNER: O vencedor precisa ser um dos dois participantes da partida.';
  END IF;

  SELECT * INTO v_tournament FROM public.tournaments WHERE id = v_match.tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Torneio não encontrado.';
  END IF;
  IF v_tournament.status NOT IN ('in_progress', 'completed') THEN
    RAISE EXCEPTION 'TOURNAMENT_NOT_IN_PROGRESS: Este torneio não está com a chave em andamento.';
  END IF;

  v_winner_id := p_winner_participant_id;
  v_loser_id := CASE WHEN v_winner_id = v_match.participant_a_id THEN v_match.participant_b_id ELSE v_match.participant_a_id END;

  UPDATE public.tournament_matches
  SET winner_participant_id = v_winner_id, status = 'completed', completed_at = now()
  WHERE id = p_match_id
  RETURNING * INTO v_match;

  UPDATE public.disputes
  SET status = 'resolved',
      resolution = 'Moderação da ArenaX1 analisou as provas e confirmou o resultado real.',
      mediator_id = p_admin_user_id,
      updated_at = now()
  WHERE tournament_match_id = p_match_id;

  -- Penaliza quem mentiu: derruba o Fair Play Rating (piso em 0) e avisa.
  SELECT user_id INTO v_loser_user_id FROM public.tournament_participants WHERE id = v_loser_id;
  UPDATE public.profiles
  SET fair_play_rating = GREATEST(fair_play_rating - 1.5, 0)
  WHERE id = v_loser_user_id
  RETURNING fair_play_rating INTO v_new_rating;

  INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
  VALUES (v_loser_user_id, 'dispute_resolved_loss', 'Resultado falso identificado 🚩',
    'A moderação da ArenaX1 analisou as provas da sua partida em "' || v_tournament.title || '" e confirmou que o resultado que você reportou era falso. Seu Fair Play Rating caiu para ' || v_new_rating || '. Reincidência leva a banimento.',
    v_tournament.id, p_match_id);

  INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
  SELECT tp.user_id, 'dispute_resolved_win', 'Disputa resolvida a seu favor ✅',
    'A moderação da ArenaX1 confirmou seu resultado na partida em "' || v_tournament.title || '". Segue o jogo.',
    v_tournament.id, p_match_id
  FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

  v_total_rounds := CASE v_tournament.max_players WHEN 4 THEN 2 WHEN 8 THEN 3 WHEN 16 THEN 4 END;
  v_net_pool := v_tournament.prize_pool - v_tournament.rake_amount;
  -- Em torneios de 8/16, reserva 1 taxa de inscrição pra devolver ao 4º
  -- lugar (empate, sem lucro) — os 50/30/20% de sempre passam a incidir
  -- sobre o que sobra. Em torneios de 4 nada muda (reembolso = 0).
  v_fourth_refund := CASE WHEN v_tournament.max_players > 4 THEN v_tournament.entry_fee ELSE 0 END;
  v_adjusted_pool := v_net_pool - v_fourth_refund;

  IF v_match.is_third_place THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;

    UPDATE public.wallets SET balance = balance + round(v_adjusted_pool * 0.2, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_adjusted_pool * 0.2, 2), 'completed',
      '3º lugar no torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
      'Você ficou em 3º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_adjusted_pool * 0.2, 2) || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    -- 4º lugar (perdeu a disputa de 3º): em torneios de 8/16, recebe de
    -- volta a própria inscrição (empate, sem lucro).
    IF v_fourth_refund > 0 THEN
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_loser_id;

      UPDATE public.wallets SET balance = balance + v_fourth_refund, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'bet_refund', v_fourth_refund, 'completed',
        '4º lugar no torneio "' || v_tournament.title || '" — inscrição devolvida');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Inscrição de volta 💸',
        'Você ficou em 4º lugar no torneio "' || v_tournament.title || '" — sem prêmio, mas sua inscrição de R$ ' || v_fourth_refund || ' voltou pra sua carteira.',
        v_tournament.id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_loser_id;
    END IF;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (
      SELECT user_id FROM public.tournament_participants WHERE id IN (v_match.participant_a_id, v_match.participant_b_id)
    );

    UPDATE public.tournaments SET third_place_participant_id = v_winner_id WHERE id = v_tournament.id;

    RETURN jsonb_build_object('status', 'resolved', 'match', to_jsonb(v_match), 'message', 'Disputa de 3º lugar resolvida.');
  END IF;

  IF v_match.round = v_total_rounds THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;
    UPDATE public.wallets SET balance = balance + round(v_adjusted_pool * 0.5, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_adjusted_pool * 0.5, 2), 'completed',
      'Campeão do torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Você é o campeão 🏆',
      'Você venceu o torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_adjusted_pool * 0.5, 2) || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_loser_id;
    UPDATE public.wallets SET balance = balance + round(v_adjusted_pool * 0.3, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_adjusted_pool * 0.3, 2), 'completed',
      'Vice-campeão do torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
      'Você ficou em 2º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_adjusted_pool * 0.3, 2) || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_loser_id;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (
      SELECT user_id FROM public.tournament_participants WHERE id IN (v_winner_id, v_loser_id)
    );

    UPDATE public.tournaments
    SET status = 'completed', completed_at = now(),
        champion_participant_id = v_winner_id,
        runner_up_participant_id = v_loser_id
    WHERE id = v_tournament.id;

    RETURN jsonb_build_object('status', 'resolved', 'tournament_completed', true, 'champion_participant_id', v_winner_id, 'match', to_jsonb(v_match));
  END IF;

  v_next_round := v_match.round + 1;
  v_next_slot := v_match.slot / 2;

  IF v_match.slot % 2 = 0 THEN
    UPDATE public.tournament_matches SET participant_a_id = v_winner_id
    WHERE tournament_id = v_tournament.id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  ELSE
    UPDATE public.tournament_matches SET participant_b_id = v_winner_id
    WHERE tournament_id = v_tournament.id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  END IF;

  IF v_next_match.participant_a_id IS NOT NULL AND v_next_match.participant_b_id IS NOT NULL THEN
    UPDATE public.tournament_matches SET status = 'ready' WHERE id = v_next_match.id RETURNING * INTO v_next_match;

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT pa.user_id, 'match_ready', 'Sua partida está pronta ⚔️',
      'Você avançou! Enfrente ' || pb.display_name || ' em "' || v_tournament.title || '". Reporta o resultado assim que jogar.',
      v_tournament.id, v_next_match.id
    FROM public.tournament_participants pa, public.tournament_participants pb
    WHERE pa.id = v_next_match.participant_a_id AND pb.id = v_next_match.participant_b_id
    UNION ALL
    SELECT pb.user_id, 'match_ready', 'Sua partida está pronta ⚔️',
      'Você avançou! Enfrente ' || pa.display_name || ' em "' || v_tournament.title || '". Reporta o resultado assim que jogar.',
      v_tournament.id, v_next_match.id
    FROM public.tournament_participants pa, public.tournament_participants pb
    WHERE pa.id = v_next_match.participant_a_id AND pb.id = v_next_match.participant_b_id;
  END IF;

  IF v_match.round = v_total_rounds - 1 THEN
    IF v_match.slot % 2 = 0 THEN
      UPDATE public.tournament_matches SET participant_a_id = v_loser_id
      WHERE tournament_id = v_tournament.id AND round = v_total_rounds AND slot = 1
      RETURNING * INTO v_third_match;
    ELSE
      UPDATE public.tournament_matches SET participant_b_id = v_loser_id
      WHERE tournament_id = v_tournament.id AND round = v_total_rounds AND slot = 1
      RETURNING * INTO v_third_match;
    END IF;

    IF v_third_match.participant_a_id IS NOT NULL AND v_third_match.participant_b_id IS NOT NULL THEN
      UPDATE public.tournament_matches SET status = 'ready' WHERE id = v_third_match.id;

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT pa.user_id, 'match_ready', 'Disputa de 3º lugar ⚔️',
        'Você caiu na semifinal, mas ainda dá pra faturar: enfrente ' || pb.display_name || ' na disputa de 3º lugar de "' || v_tournament.title || '".',
        v_tournament.id, v_third_match.id
      FROM public.tournament_participants pa, public.tournament_participants pb
      WHERE pa.id = v_third_match.participant_a_id AND pb.id = v_third_match.participant_b_id
      UNION ALL
      SELECT pb.user_id, 'match_ready', 'Disputa de 3º lugar ⚔️',
        'Você caiu na semifinal, mas ainda dá pra faturar: enfrente ' || pa.display_name || ' na disputa de 3º lugar de "' || v_tournament.title || '".',
        v_tournament.id, v_third_match.id
      FROM public.tournament_participants pa, public.tournament_participants pb
      WHERE pa.id = v_third_match.participant_a_id AND pb.id = v_third_match.participant_b_id;
    END IF;
  ELSE
    -- Mesma correção do fn_submit_online_match_result: eliminado sem chance
    -- de 3º lugar libera o valor travado na hora.
    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (SELECT user_id FROM public.tournament_participants WHERE id = v_loser_id);
  END IF;

  RETURN jsonb_build_object('status', 'resolved', 'tournament_completed', false, 'match', to_jsonb(v_match), 'next_match', to_jsonb(v_next_match));
END;
$$;

REVOKE ALL ON FUNCTION public.fn_submit_online_match_result(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_submit_online_match_result(uuid, uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid, uuid) TO service_role;
