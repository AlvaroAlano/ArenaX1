-- Execute este script no SQL Editor do seu painel Supabase (depois do 36).
--
-- Objetivo: fechar DOIS achados do teste geral, que estão acoplados:
--
--   ACHADO-02 — o banco estava pagando torneio pago pelo esquema ANTIGO
--   (50/30 fixo) em vez do escalonado por tamanho de chave que
--   regras-do-sistema.md §"Torneio Online" e 19_tiered_prize_distribution.sql
--   definem como a regra atual. Padrão "migração fantasma": o arquivo 19
--   existe no repo, mas a versão rodando no banco era anterior. Este arquivo
--   reafirma a versão correta e escalonada (4 jog: campeão 100%; 8 jog:
--   55/30/15; 16 jog: 50/25/15/10).
--
--   ACHADO-04 — trava de saldo: numa chave de 4 (campeão leva 100%), a
--   "disputa de 3º lugar" NÃO paga nada, mas o valor da inscrição dos dois
--   perdedores de semifinal só saía do locked_balance quando essa partida sem
--   prêmio era jogada. Sem incentivo pra jogar, o dinheiro ficava preso pra
--   sempre (não saca, não aposta) e não havia rota de admin pra liberar.
--
-- A correção do ACHADO-04 é cirúrgica e única: na ramificação de semifinal,
-- só mandamos o perdedor pra disputa de 3º lugar QUANDO essa chave realmente
-- paga 3º lugar (v_third_pct > 0, ou seja, 8/16 jogadores). Na chave de 4, o
-- perdedor de semifinal não tem próxima partida — libera o valor travado na
-- hora, exatamente como já acontecia com quem é eliminado antes da semifinal
-- em chaves maiores. O resto das duas funções é idêntico ao 19.
--
-- (Cosmético, fora do escopo de dinheiro: a chave de 4 ainda gera uma linha de
-- partida de 3º lugar em tournament_matches que agora fica sem ser preenchida.
-- Não trava nada nem prende saldo; se quiser, dá pra parar de gerá-la em
-- fn_create_online_tournament num passo futuro.)

-- ─────────────────────────────────────────────────────────────────────────
-- 0) Coluna do 4º colocado (idempotente — já deve existir do 19).
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS fourth_place_participant_id uuid REFERENCES public.tournament_participants(id);

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Reporte por consenso (jogador).
-- ─────────────────────────────────────────────────────────────────────────
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
  v_champion_pct numeric;
  v_runner_up_pct numeric;
  v_third_pct numeric;
  v_fourth_pct numeric;
  v_prize numeric;
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

  -- Tabela de premiação por tamanho de chave (sempre sobre o pote líquido,
  -- já descontado o rake de 10%).
  CASE v_tournament.max_players
    WHEN 4 THEN
      v_champion_pct := 1.00; v_runner_up_pct := 0; v_third_pct := 0; v_fourth_pct := 0;
    WHEN 8 THEN
      v_champion_pct := 0.55; v_runner_up_pct := 0.30; v_third_pct := 0.15; v_fourth_pct := 0;
    ELSE -- 16
      v_champion_pct := 0.50; v_runner_up_pct := 0.25; v_third_pct := 0.15; v_fourth_pct := 0.10;
  END CASE;

  -- Disputa de 3º lugar: paga 3º (se essa chave paga 3º) e 4º (só chave de
  -- 16), e sempre libera o valor travado dos DOIS (pra quem jogou essa
  -- partida, o torneio acabou aqui).
  IF v_match.is_third_place THEN
    IF v_third_pct > 0 THEN
      v_prize := round(v_net_pool * v_third_pct, 2);
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_winner_id;

      UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
        '3º lugar no torneio "' || v_tournament.title || '"');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
        'Você ficou em 3º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
        p_tournament_id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_winner_id;
    END IF;

    IF v_fourth_pct > 0 THEN
      v_prize := round(v_net_pool * v_fourth_pct, 2);
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_loser_id;

      UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
        '4º lugar no torneio "' || v_tournament.title || '"');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
        'Você ficou em 4º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
        p_tournament_id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_loser_id;
    END IF;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (
      SELECT user_id FROM public.tournament_participants WHERE id IN (v_match.participant_a_id, v_match.participant_b_id)
    );

    UPDATE public.tournaments
    SET third_place_participant_id = v_winner_id, fourth_place_participant_id = v_loser_id
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('status', 'completed', 'tournament_completed', false, 'match', to_jsonb(v_match));
  END IF;

  -- Final: paga campeão (sempre) e vice (se essa chave paga 2º lugar),
  -- libera o valor travado dos dois, fecha o torneio.
  IF v_match.round = v_total_rounds THEN
    v_prize := round(v_net_pool * v_champion_pct, 2);
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;
    UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
      'Campeão do torneio "' || v_tournament.title || '"');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Você é o campeão 🏆',
      'Você venceu o torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
      p_tournament_id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    IF v_runner_up_pct > 0 THEN
      v_prize := round(v_net_pool * v_runner_up_pct, 2);
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_loser_id;
      UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
        'Vice-campeão do torneio "' || v_tournament.title || '"');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
        'Você ficou em 2º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
        p_tournament_id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_loser_id;
    END IF;

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

  -- ═══ CORREÇÃO ACHADO-04 (única mudança em relação ao 19) ═══
  -- Só manda o perdedor de semifinal pra disputa de 3º lugar QUANDO essa chave
  -- paga 3º lugar (v_third_pct > 0 → 8/16 jogadores). Na chave de 4 (campeão
  -- leva 100%), o 3º lugar não rende nada: forçar essa partida só prendia o
  -- valor da inscrição no locked_balance pra sempre. Aqui o perdedor de semi
  -- da chave de 4 cai no ELSE e tem o valor liberado na hora.
  IF v_match.round = v_total_rounds - 1 AND v_third_pct > 0 THEN
    -- Semifinal (chave que paga 3º lugar): o perdedor vai pra disputa de 3º
    -- lugar (ainda tem uma partida pela frente) — mesma rodada da final, slot 1.
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
    -- Eliminado sem próxima partida — seja porque caiu antes da semifinal
    -- (chaves de 8/16), seja porque perdeu a semi numa chave de 4 (onde o 3º
    -- lugar não paga): libera o valor travado dele agora, sem prêmio, senão
    -- fica preso pra sempre no locked_balance.
    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (SELECT user_id FROM public.tournament_participants WHERE id = v_loser_id);
  END IF;

  RETURN jsonb_build_object('status', 'completed', 'tournament_completed', false, 'match', to_jsonb(v_match), 'next_match', to_jsonb(v_next_match));
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Resolver disputa (admin): mesma correção do ACHADO-04 na ramificação de
--    semifinal. Idêntica ao 19 no resto.
-- ─────────────────────────────────────────────────────────────────────────
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
  v_champion_pct numeric;
  v_runner_up_pct numeric;
  v_third_pct numeric;
  v_fourth_pct numeric;
  v_prize numeric;
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

  CASE v_tournament.max_players
    WHEN 4 THEN
      v_champion_pct := 1.00; v_runner_up_pct := 0; v_third_pct := 0; v_fourth_pct := 0;
    WHEN 8 THEN
      v_champion_pct := 0.55; v_runner_up_pct := 0.30; v_third_pct := 0.15; v_fourth_pct := 0;
    ELSE -- 16
      v_champion_pct := 0.50; v_runner_up_pct := 0.25; v_third_pct := 0.15; v_fourth_pct := 0.10;
  END CASE;

  IF v_match.is_third_place THEN
    IF v_third_pct > 0 THEN
      v_prize := round(v_net_pool * v_third_pct, 2);
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_winner_id;

      UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
        '3º lugar no torneio "' || v_tournament.title || '" (resolvido por disputa)');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
        'Você ficou em 3º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
        v_tournament.id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_winner_id;
    END IF;

    IF v_fourth_pct > 0 THEN
      v_prize := round(v_net_pool * v_fourth_pct, 2);
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_loser_id;

      UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
        '4º lugar no torneio "' || v_tournament.title || '" (resolvido por disputa)');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
        'Você ficou em 4º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
        v_tournament.id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_loser_id;
    END IF;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (
      SELECT user_id FROM public.tournament_participants WHERE id IN (v_match.participant_a_id, v_match.participant_b_id)
    );

    UPDATE public.tournaments
    SET third_place_participant_id = v_winner_id, fourth_place_participant_id = v_loser_id
    WHERE id = v_tournament.id;

    RETURN jsonb_build_object('status', 'resolved', 'match', to_jsonb(v_match), 'message', 'Disputa de 3º lugar resolvida.');
  END IF;

  IF v_match.round = v_total_rounds THEN
    v_prize := round(v_net_pool * v_champion_pct, 2);
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;
    UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
      'Campeão do torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Você é o campeão 🏆',
      'Você venceu o torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    IF v_runner_up_pct > 0 THEN
      v_prize := round(v_net_pool * v_runner_up_pct, 2);
      SELECT w.id INTO v_wallet_id
      FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
      WHERE tp.id = v_loser_id;
      UPDATE public.wallets SET balance = balance + v_prize, updated_at = now() WHERE id = v_wallet_id;
      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      VALUES (v_wallet_id, 'tournament_prize', v_prize, 'completed',
        'Vice-campeão do torneio "' || v_tournament.title || '" (resolvido por disputa)');

      INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
      SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
        'Você ficou em 2º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || v_prize || '.',
        v_tournament.id, p_match_id
      FROM public.tournament_participants tp WHERE tp.id = v_loser_id;
    END IF;

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

  -- ═══ CORREÇÃO ACHADO-04 (mesma do fn_submit acima) ═══
  IF v_match.round = v_total_rounds - 1 AND v_third_pct > 0 THEN
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
    UPDATE public.wallets
    SET locked_balance = locked_balance - v_tournament.entry_fee, updated_at = now()
    WHERE user_id IN (SELECT user_id FROM public.tournament_participants WHERE id = v_loser_id);
  END IF;

  RETURN jsonb_build_object('status', 'resolved', 'tournament_completed', false, 'match', to_jsonb(v_match), 'next_match', to_jsonb(v_next_match));
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants (defensivo — mesmas assinaturas).
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_submit_online_match_result(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_submit_online_match_result(uuid, uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid, uuid) TO service_role;
