-- Execute no SQL Editor do Supabase (depois de 20..23).
--
-- Objetivo: fechar o buraco que a exclusão de conta expôs — hoje um desafio
-- entra em 'in_progress' assim que o criador escolhe o oponente e NUNCA sai
-- dali sozinho: se um reporta e o outro swith some, ou se ninguém reporta, a
-- partida fica travada pra sempre (e o bloqueio ACTIVE_MATCH da exclusão trava
-- a conta junto, indefinidamente). Não existe timeout nem escalonamento.
--
-- Este script introduz o ciclo completo da partida, com prazos:
--
--   open --(criador escolhe)--> accepted --(ambos confirmam presença)--> in_progress
--        --(consenso)--> completed   |  --(divergência OU prazo)--> disputed
--   accepted --(ninguém confirma no prazo)--> cancelled (reembolsa os dois)
--
--   1) Checkpoint "Iniciar partida": aceitar não joga direto pra in_progress —
--      vai pra 'accepted', e os DOIS precisam confirmar presença (fn_mark_ready)
--      dentro de start_deadline. Só aí vira in_progress. Isso separa "nunca
--      jogaram" (reembolsa) de "jogaram e não bateram o placar" (disputa).
--   2) Notificação com prazo: quem confirma presença primeiro, e quem reporta
--      primeiro, dispara aviso pro outro com o prazo.
--   3) Escalonamento no timeout: in_progress que passa de report_deadline sem
--      consenso vira 'disputed' (admin resolve — normalmente W.O. pro presente).
--   4) accepted/locked_balance: se a presença não é confirmada no prazo, os
--      dois saldos travados voltam (bet_refund), status 'cancelled'.
--
-- Os prazos são constantes tunáveis, definidas no topo de cada função:
--   START_WINDOW  = 15 min (confirmar presença)
--   REPORT_WINDOW = 24 h   (jogar e reportar)

-- ─────────────────────────────────────────────────────────────────────────
-- 0) Colunas de ciclo de vida + tipo novo de notificação.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS creator_ready boolean not null default false,
  ADD COLUMN IF NOT EXISTS opponent_ready boolean not null default false,
  ADD COLUMN IF NOT EXISTS start_deadline timestamptz,
  ADD COLUMN IF NOT EXISTS report_deadline timestamptz;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss',
    'deposit_confirmed', 'withdraw_completed',
    'challenge_accepted', 'challenge_result_pending', 'challenge_win',
    'challenge_loss', 'challenge_disputed',
    'challenge_join_requested', 'challenge_request_accepted', 'challenge_request_rejected',
    'challenge_expired'
  ));

-- Índice pro job de timeout varrer só o que interessa.
CREATE INDEX IF NOT EXISTS challenges_deadline_idx
  ON public.challenges (status, start_deadline, report_deadline)
  WHERE status IN ('accepted', 'in_progress');

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Escolher solicitante agora leva a 'accepted' (não mais direto a
--    'in_progress'). Mesmo corpo do 20, trocando o alvo do status, setando
--    start_deadline e ajustando o texto do aviso. Trava o saldo do oponente
--    e auto-rejeita os outros pedidos, igual antes.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_accept_join_request(
  p_request_id uuid,
  p_creator_id uuid
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request public.challenge_join_requests;
  v_challenge public.challenges;
  v_wallet public.wallets;
  c_start_window constant interval := interval '15 minutes';
BEGIN
  SELECT * INTO v_request FROM public.challenge_join_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND: Solicitação não encontrada.';
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING: Esta solicitação já foi respondida.';
  END IF;

  SELECT * INTO v_challenge FROM public.challenges WHERE id = v_request.challenge_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.creator_id != p_creator_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Só quem criou o desafio pode escolher quem entra.';
  END IF;

  IF v_challenge.status != 'open' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_OPEN: Este desafio não está mais aberto para aceitação.';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = v_request.requester_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do jogador não encontrada.';
  END IF;

  IF v_wallet.balance < v_challenge.bet_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Esse jogador não tem mais saldo suficiente pra esse valor — escolha outro solicitante.';
  END IF;

  UPDATE public.wallets
  SET balance = balance - v_challenge.bet_amount,
      locked_balance = locked_balance + v_challenge.bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  UPDATE public.challenges
  SET opponent_id = v_request.requester_id,
      status = 'accepted',
      creator_ready = false,
      opponent_ready = false,
      start_deadline = now() + c_start_window,
      report_deadline = NULL,
      updated_at = now()
  WHERE id = v_challenge.id
  RETURNING * INTO v_challenge;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_freeze',
    -v_challenge.bet_amount,
    'completed',
    'Saldo congelado para desafio X1 (Sala: ' || substr(v_challenge.id::text, 1, 8) || ')'
  );

  UPDATE public.challenge_join_requests
  SET status = 'accepted', updated_at = now()
  WHERE id = v_request.id;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (v_request.requester_id, 'challenge_request_accepted', 'Você entrou no desafio ⚔️',
    'Sua solicitação pro desafio de R$ ' || v_challenge.bet_amount || ' em ' || v_challenge.game || ' foi aceita. Confirmem presença pra começar — vocês têm 15 min.',
    v_challenge.id);

  -- Auto-rejeita os outros pedidos pendentes (só notifica quem perdeu a vaga agora).
  WITH auto_rejected AS (
    UPDATE public.challenge_join_requests
    SET status = 'rejected', updated_at = now()
    WHERE challenge_id = v_challenge.id AND status = 'pending' AND id != v_request.id
    RETURNING requester_id
  )
  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  SELECT requester_id, 'challenge_request_rejected', 'Vaga preenchida',
    'Outro jogador foi escolhido pro desafio de ' || v_challenge.game || '. Fica de olho em outras salas abertas.',
    v_challenge.id
  FROM auto_rejected;

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Confirmar presença ("Iniciar partida"). Quando os dois confirmam, a
--    partida vira in_progress e ganha report_deadline.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_mark_ready(
  p_challenge_id uuid,
  p_user_id uuid
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_is_creator boolean;
  v_both_ready boolean;
  c_report_window constant interval := interval '24 hours';
BEGIN
  SELECT * INTO v_challenge FROM public.challenges WHERE id = p_challenge_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.status != 'accepted' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_ACCEPTED: Esta partida não está na fase de confirmar presença.';
  END IF;

  v_is_creator := (v_challenge.creator_id = p_user_id);
  IF NOT v_is_creator AND v_challenge.opponent_id != p_user_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não faz parte deste desafio.';
  END IF;

  IF v_is_creator THEN
    UPDATE public.challenges SET creator_ready = true, updated_at = now()
    WHERE id = p_challenge_id RETURNING * INTO v_challenge;
  ELSE
    UPDATE public.challenges SET opponent_ready = true, updated_at = now()
    WHERE id = p_challenge_id RETURNING * INTO v_challenge;
  END IF;

  v_both_ready := v_challenge.creator_ready AND v_challenge.opponent_ready;

  IF v_both_ready THEN
    UPDATE public.challenges
    SET status = 'in_progress',
        start_deadline = NULL,
        report_deadline = now() + c_report_window,
        updated_at = now()
    WHERE id = p_challenge_id
    RETURNING * INTO v_challenge;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'match_ready', 'Partida começou! 🎮',
      'Os dois confirmaram presença no desafio de ' || v_challenge.game || '. Joguem e reportem o resultado em até 24h.',
      v_challenge.id
    FROM (VALUES (v_challenge.creator_id), (v_challenge.opponent_id)) AS t(uid);
  ELSE
    -- Só um confirmou: avisa o outro que está esperando.
    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (
      CASE WHEN v_is_creator THEN v_challenge.opponent_id ELSE v_challenge.creator_id END,
      'match_ready', 'Seu oponente está pronto ⏳',
      'O adversário confirmou presença no desafio de ' || v_challenge.game || '. Confirme a sua pra começar — antes do prazo, senão a partida é cancelada e o saldo devolvido.',
      v_challenge.id
    );
  END IF;

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Reportar resultado: NÃO é redefinido aqui de propósito. A versão correta
--    (rake 8% + notificações de vitória/derrota) vem do 18. O reset do prazo
--    a partir do primeiro reporte (item 1) e a liquidação com retenção entram
--    na versão final, em 26_match_settlement_hold.sql, que também refatora o
--    pagamento pra uma função compartilhada (fn_settle_challenge).
-- ─────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Job de timeout — varre os dois casos de prazo estourado e resolve.
--    Puro SQL (reembolso, disputa, notificação são tudo operação de banco),
--    então roda direto via pg_cron, sem precisar do backend. Trava a linha do
--    desafio antes de mexer (serializa com fn_mark_ready/fn_report), e
--    re-checa o status depois do lock pra não processar algo que já mudou.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_process_match_timeouts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_ch public.challenges;
  v_wallet_lo public.wallets;  -- só p/ travar as carteiras em ordem determinística
  v_wallet_hi public.wallets;
  v_cancelled int := 0;
  v_disputed int := 0;
BEGIN
  -- A) 'accepted' que estourou start_deadline sem os dois confirmarem →
  --    ninguém (ou só um) apareceu: cancela e devolve o saldo dos dois.
  FOR v_row IN
    SELECT id FROM public.challenges
    WHERE status = 'accepted' AND start_deadline IS NOT NULL AND start_deadline < now()
  LOOP
    SELECT * INTO v_ch FROM public.challenges WHERE id = v_row.id FOR UPDATE;
    CONTINUE WHEN v_ch.status != 'accepted' OR v_ch.start_deadline >= now();

    -- Trava as duas carteiras em ordem determinística (evita deadlock).
    SELECT * INTO v_wallet_lo FROM public.wallets
      WHERE user_id = LEAST(v_ch.creator_id, v_ch.opponent_id) FOR UPDATE;
    SELECT * INTO v_wallet_hi FROM public.wallets
      WHERE user_id = GREATEST(v_ch.creator_id, v_ch.opponent_id) FOR UPDATE;

    -- Devolve o valor travado pra cada participante.
    UPDATE public.wallets
    SET balance = balance + v_ch.bet_amount,
        locked_balance = locked_balance - v_ch.bet_amount,
        updated_at = now()
    WHERE user_id IN (v_ch.creator_id, v_ch.opponent_id);

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    SELECT w.id, 'bet_refund', v_ch.bet_amount, 'completed',
           'Partida cancelada por falta de confirmação, saldo devolvido (Sala: ' || substr(v_ch.id::text, 1, 8) || ')'
    FROM public.wallets w
    WHERE w.user_id IN (v_ch.creator_id, v_ch.opponent_id);

    UPDATE public.challenges
    SET status = 'cancelled', start_deadline = NULL, updated_at = now()
    WHERE id = v_ch.id;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'challenge_expired', 'Partida cancelada ⏱️',
      'Ninguém confirmou presença a tempo no desafio de ' || v_ch.game || '. A partida foi cancelada e seu saldo foi devolvido.',
      v_ch.id
    FROM (VALUES (v_ch.creator_id), (v_ch.opponent_id)) AS t(uid);

    v_cancelled := v_cancelled + 1;
  END LOOP;

  -- B) 'in_progress' que estourou report_deadline sem consenso → manda pra
  --    mediação (o admin normalmente dá o W.O. pro jogador presente).
  FOR v_row IN
    SELECT id FROM public.challenges
    WHERE status = 'in_progress' AND report_deadline IS NOT NULL AND report_deadline < now()
  LOOP
    SELECT * INTO v_ch FROM public.challenges WHERE id = v_row.id FOR UPDATE;
    CONTINUE WHEN v_ch.status != 'in_progress' OR v_ch.report_deadline >= now();

    UPDATE public.challenges
    SET status = 'disputed', report_deadline = NULL, updated_at = now()
    WHERE id = v_ch.id;

    INSERT INTO public.disputes (challenge_id, status) VALUES (v_ch.id, 'open')
      ON CONFLICT (challenge_id) DO NOTHING;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'challenge_disputed', 'Partida foi pra mediação ⚖️',
      'O prazo pra reportar o resultado do desafio de ' || v_ch.game || ' esgotou. A ArenaX1 vai analisar e decidir.',
      v_ch.id
    FROM (VALUES (v_ch.creator_id), (v_ch.opponent_id)) AS t(uid);

    v_disputed := v_disputed + 1;
  END LOOP;

  RETURN jsonb_build_object('cancelled', v_cancelled, 'disputed', v_disputed);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_mark_ready(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_process_match_timeouts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_mark_ready(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_process_match_timeouts() TO service_role;
-- fn_accept_join_request e fn_report_challenge_result mantêm os grants do 20/04
-- (CREATE OR REPLACE preserva privilégios), mas reforçamos por garantia:
GRANT EXECUTE ON FUNCTION public.fn_accept_join_request(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- Agendamento do job de timeout (a cada 5 min). Puro SQL, só precisa de
-- pg_cron (não usa pg_net). Confira Database → Extensions antes; se pg_cron
-- não existir no seu plano, chame fn_process_match_timeouts por um cron
-- externo batendo num endpoint admin, ou manualmente.
-- ─────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.unschedule('process-match-timeouts')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-match-timeouts');

SELECT cron.schedule(
  'process-match-timeouts',
  '*/5 * * * *',
  $$ SELECT public.fn_process_match_timeouts(); $$
);
