-- Execute este script no SQL Editor do seu painel Supabase (depois do 08_notifications_and_rules.sql).
--
-- Objetivo: dar um jeito de FECHAR uma partida de torneio online que caiu em
-- disputa (os dois reportaram resultados divergentes) — sem isso, o dinheiro
-- de todo mundo ainda inscrito naquele torneio ficava congelado pra sempre,
-- sem nenhum caminho de resolução (mesma lacuna que já existia pros desafios
-- X1, que continuam fora do escopo deste arquivo por enquanto).
--
-- Decidido em conversa com o usuário:
--   * Acesso: sem tela de admin por ora — um endpoint novo protegido por
--     segredo compartilhado (mesmo padrão do X-Webhook-Secret do Pix em
--     pix.py), chamado manualmente (Postman/curl) depois de olhar as provas.
--   * Punição de quem mentiu: reduz o fair_play_rating em 1.5 (piso em 0) —
--     reaproveita a nota que já existe no perfil, só passa a ter consequência.
--   * Quem fala a verdade recebe o resultado normal (avança de rodada, ou
--     recebe o prêmio se era final/3º lugar) — mesma lógica de propagação e
--     pagamento de fn_submit_online_match_result, só que disparada por
--     decisão de moderação em vez de consenso dos dois jogadores.

-- ─────────────────────────────────────────────────────────────────────────
-- Notificações: dois tipos novos pro resultado da disputa (tom bem
-- diferente entre os dois, por isso tipos separados em vez de reaproveitar
-- 'match_disputed').
-- ─────────────────────────────────────────────────────────────────────────
alter table public.notifications drop constraint notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- Resolver disputa de partida de torneio online.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_resolve_online_match_dispute(
  p_match_id uuid,
  p_winner_participant_id uuid
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
  IF v_tournament.status != 'in_progress' THEN
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

  -- Dali em diante, é o MESMO caminho de fn_submit_online_match_result depois
  -- do consenso: paga se era 3º lugar/final, ou propaga o vencedor (e o
  -- perdedor pra disputa de 3º lugar, se era semifinal).
  v_total_rounds := CASE v_tournament.max_players WHEN 4 THEN 2 WHEN 8 THEN 3 WHEN 16 THEN 4 END;
  v_net_pool := v_tournament.prize_pool - v_tournament.rake_amount;

  IF v_match.is_third_place THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;

    UPDATE public.wallets SET balance = balance + round(v_net_pool * 0.2, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_net_pool * 0.2, 2), 'completed',
      '3º lugar no torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
      'Você ficou em 3º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_net_pool * 0.2, 2) || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    UPDATE public.tournaments SET third_place_participant_id = v_winner_id WHERE id = v_tournament.id;

    RETURN jsonb_build_object('status', 'resolved', 'match', to_jsonb(v_match), 'message', 'Disputa de 3º lugar resolvida.');
  END IF;

  IF v_match.round = v_total_rounds THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;
    UPDATE public.wallets SET balance = balance + round(v_net_pool * 0.5, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_net_pool * 0.5, 2), 'completed',
      'Campeão do torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Você é o campeão 🏆',
      'Você venceu o torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_net_pool * 0.5, 2) || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_winner_id;

    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_loser_id;
    UPDATE public.wallets SET balance = balance + round(v_net_pool * 0.3, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_net_pool * 0.3, 2), 'completed',
      'Vice-campeão do torneio "' || v_tournament.title || '" (resolvido por disputa)');

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'tournament_prize', 'Prêmio na conta 💰',
      'Você ficou em 2º lugar no torneio "' || v_tournament.title || '" e ganhou R$ ' || round(v_net_pool * 0.3, 2) || '.',
      v_tournament.id, p_match_id
    FROM public.tournament_participants tp WHERE tp.id = v_loser_id;

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
  END IF;

  RETURN jsonb_build_object('status', 'resolved', 'tournament_completed', false, 'match', to_jsonb(v_match), 'next_match', to_jsonb(v_next_match));
END;
$$;

REVOKE ALL ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid) TO service_role;
