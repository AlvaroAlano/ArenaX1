-- Execute este script no SQL Editor do seu painel Supabase (depois do 09_dispute_resolution.sql).
--
-- Objetivo: portal de admin de verdade — decidido em conversa com o usuário
-- que o acesso seria por CONTA REAL (login normal + flag is_admin no
-- perfil), substituindo o segredo compartilhado X-Admin-Secret criado no
-- 09 pra resolução de disputa. Isso também permite registrar QUAL admin
-- resolveu cada disputa (mediator_id, coluna que já existia em `disputes`
-- mas nunca tinha sido usada).
--
-- Depois de rodar este arquivo, ATUALIZE O EMAIL abaixo pra sua conta real
-- antes de confiar no acesso — a linha já vem apontando pra conta de teste
-- documentada do projeto (admin@arenax1.com).

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Flag de administrador no perfil.
-- ─────────────────────────────────────────────────────────────────────────
alter table public.profiles add column is_admin boolean not null default false;

-- Ajuste este e-mail pra conta que deve ter acesso ao portal antes de
-- rodar (ou rode de novo com outro e-mail depois, quantas vezes precisar).
update public.profiles
set is_admin = true
where id = (select id from auth.users where email = 'admin@arenax1.com');

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Resolução de disputa: mesma lógica do 09, mas agora recebe quem é o
--    admin que resolveu (guardado em disputes.mediator_id, coluna que já
--    existia e nunca era preenchida). Assinatura mudou (ganhou
--    p_admin_user_id), então a versão antiga (2 argumentos) precisa ser
--    removida primeiro.
-- ─────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.fn_resolve_online_match_dispute(uuid, uuid);

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

REVOKE ALL ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_resolve_online_match_dispute(uuid, uuid, uuid) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Métricas do portal de admin — tudo calculado em uma função só (leitura
--    pura, sem locks, então não compete com o tráfego normal do app).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_dashboard_metrics() RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT jsonb_build_object(
    'financeiro', jsonb_build_object(
      'saldo_disponivel_total', (SELECT coalesce(sum(balance), 0) FROM wallets),
      'saldo_travado_total', (SELECT coalesce(sum(locked_balance), 0) FROM wallets),
      'total_depositado', (SELECT coalesce(sum(amount), 0) FROM transactions WHERE type = 'deposit' AND status = 'completed'),
      'total_sacado', (SELECT coalesce(sum(abs(amount)), 0) FROM transactions WHERE type = 'withdraw' AND status = 'completed'),
      'total_premios_pagos', (SELECT coalesce(sum(amount), 0) FROM transactions WHERE type IN ('challenge_win', 'tournament_prize') AND status = 'completed'),
      'total_rake_desafios', (SELECT coalesce(sum(rake_amount), 0) FROM challenges WHERE status = 'completed'),
      'total_rake_torneios', (SELECT coalesce(sum(rake_amount), 0) FROM tournaments WHERE type = 'online_paid' AND status = 'completed'),
      'travado_em_desafios', (
        SELECT coalesce(sum(CASE WHEN status = 'open' THEN bet_amount ELSE bet_amount * 2 END), 0)
        FROM challenges WHERE status IN ('open', 'in_progress', 'disputed')
      ),
      'travado_em_torneios_online', (
        SELECT coalesce(sum(t.entry_fee * pc.cnt), 0)
        FROM tournaments t
        JOIN (SELECT tournament_id, count(*) AS cnt FROM tournament_participants GROUP BY tournament_id) pc
          ON pc.tournament_id = t.id
        WHERE t.type = 'online_paid' AND t.status IN ('registration_open', 'in_progress')
      )
    ),
    'desafios', jsonb_build_object(
      'total', (SELECT count(*) FROM challenges),
      'abertos', (SELECT count(*) FROM challenges WHERE status = 'open'),
      'em_andamento', (SELECT count(*) FROM challenges WHERE status = 'in_progress'),
      'concluidos', (SELECT count(*) FROM challenges WHERE status = 'completed'),
      'em_disputa', (SELECT count(*) FROM challenges WHERE status = 'disputed'),
      'aposta_media', (SELECT coalesce(round(avg(bet_amount), 2), 0) FROM challenges)
    ),
    'torneios_locais', jsonb_build_object(
      'total', (SELECT count(*) FROM tournaments WHERE type = 'local'),
      'em_andamento', (SELECT count(*) FROM tournaments WHERE type = 'local' AND status = 'in_progress'),
      'concluidos', (SELECT count(*) FROM tournaments WHERE type = 'local' AND status = 'completed')
    ),
    'torneios_online', jsonb_build_object(
      'total', (SELECT count(*) FROM tournaments WHERE type = 'online_paid'),
      'inscricoes_abertas', (SELECT count(*) FROM tournaments WHERE type = 'online_paid' AND status = 'registration_open'),
      'em_andamento', (SELECT count(*) FROM tournaments WHERE type = 'online_paid' AND status = 'in_progress'),
      'concluidos', (SELECT count(*) FROM tournaments WHERE type = 'online_paid' AND status = 'completed'),
      'cancelados', (SELECT count(*) FROM tournaments WHERE type = 'online_paid' AND status = 'cancelled'),
      'taxa_inscricao_media', (SELECT coalesce(round(avg(entry_fee), 2), 0) FROM tournaments WHERE type = 'online_paid'),
      'distribuicao_tamanho', (
        SELECT coalesce(jsonb_object_agg(max_players::text, cnt), '{}'::jsonb)
        FROM (SELECT max_players, count(*) AS cnt FROM tournaments WHERE type = 'online_paid' GROUP BY max_players) x
      )
    ),
    'usuarios', jsonb_build_object(
      'total', (SELECT count(*) FROM profiles),
      'jogadores_ativos', (
        SELECT count(DISTINCT uid) FROM (
          SELECT creator_id AS uid FROM challenges
          UNION
          SELECT opponent_id FROM challenges WHERE opponent_id IS NOT NULL
          UNION
          SELECT user_id FROM tournament_participants WHERE user_id IS NOT NULL
        ) all_players
      ),
      'fair_play_medio', (SELECT coalesce(round(avg(fair_play_rating), 2), 0) FROM profiles)
    ),
    'disputas', jsonb_build_object(
      'desafios_em_disputa', (SELECT count(*) FROM disputes WHERE challenge_id IS NOT NULL AND status = 'open'),
      'torneios_em_disputa', (SELECT count(*) FROM disputes WHERE tournament_match_id IS NOT NULL AND status = 'open'),
      'resolvidas_total', (SELECT count(*) FROM disputes WHERE status = 'resolved')
    ),
    'preferencias', jsonb_build_object(
      'jogos_populares', (
        SELECT coalesce(jsonb_agg(jsonb_build_object('label', game, 'total', cnt) ORDER BY cnt DESC), '[]'::jsonb)
        FROM (
          SELECT game, count(*) AS cnt FROM (
            SELECT game FROM challenges
            UNION ALL
            SELECT game FROM tournaments
          ) all_games
          GROUP BY game
        ) g
      ),
      'plataformas_populares', (
        SELECT coalesce(jsonb_agg(jsonb_build_object('label', platform, 'total', cnt) ORDER BY cnt DESC), '[]'::jsonb)
        FROM (
          SELECT platform, count(*) AS cnt FROM (
            SELECT platform FROM challenges
            UNION ALL
            SELECT platform FROM tournaments WHERE platform IS NOT NULL
          ) all_platforms
          GROUP BY platform
        ) p
      )
    )
  );
$$;

REVOKE ALL ON FUNCTION public.fn_admin_dashboard_metrics() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_dashboard_metrics() TO service_role;
