-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 32_signup_age_cpf_validation.sql).
--
-- Objetivo: fecha um buraco real do portal de admin — disputas de desafio
-- 1v1 (challenge_id, não tournament_match_id) nunca apareciam em lugar
-- nenhum pro admin ver e resolver, mesmo já existindo fn_resolve_challenge_
-- dispute pronta desde o 26. A rota de listagem (GET /api/admin/disputes,
-- backend/admin.py) só busca disputas com tournament_match_id — este
-- arquivo só adiciona o que faltava no banco: uma forma de ANULAR uma
-- disputa de desafio (devolver a aposta aos dois, sem vencedor, sem
-- penalidade de Fair Play) para o caso em que não dá pra saber quem tem
-- razão. fn_resolve_challenge_dispute (escolher vencedor) já existe e não
-- muda aqui.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Tipo de notificação novo.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type in (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss',
    'dispute_cancelled',
    'deposit_confirmed', 'withdraw_completed',
    'withdraw_pending', 'withdraw_confirmed', 'withdraw_rejected',
    'challenge_accepted', 'challenge_result_pending', 'challenge_win',
    'challenge_loss', 'challenge_disputed',
    'challenge_join_requested', 'challenge_request_accepted', 'challenge_request_rejected',
    'challenge_expired',
    'abandonment_warning',
    'support_ticket_opened', 'support_ticket_replied', 'support_ticket_message'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Anular disputa de desafio 1v1 (admin): sem provas suficientes de
--    nenhum lado pra decidir com segurança. Devolve a aposta de cada um
--    (sai do locked_balance, sem rake, sem prêmio) e fecha o desafio como
--    cancelado — mesmo espírito do timeout "zero reportes" (regras-do-
--    sistema.md §3.5) e da ressalva já escrita em termos-de-uso.md §7.4.
--    Sem penalidade de Fair Play pra ninguém: sem prova de má-fé
--    comprovada, o princípio 2 do regras-do-sistema.md (punição é sempre
--    reputacional-com-prova, nunca por presunção) se aplica aqui também.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cancel_challenge_dispute(
  p_challenge_id uuid,
  p_admin_id uuid,
  p_reason text
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ch public.challenges;
  v_prev_winner uuid;
  v_other uuid;
  v_wallet_a public.wallets;
  v_wallet_b public.wallets;
BEGIN
  SELECT * INTO v_ch FROM public.challenges WHERE id = p_challenge_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;
  IF v_ch.status != 'disputed' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_DISPUTED: Este desafio não está em disputa.';
  END IF;
  IF nullif(trim(coalesce(p_reason, '')), '') IS NULL THEN
    RAISE EXCEPTION 'REASON_REQUIRED: Descreva o motivo de anular a disputa.';
  END IF;

  -- Mesma normalização do fn_resolve_challenge_dispute: se o pote já estava
  -- consolidado num lado (veio de aceite-automático contestado), desfaz
  -- primeiro pra cada um voltar a ter só a própria aposta travada.
  IF v_ch.settlement_release_at IS NOT NULL AND v_ch.winner_id IS NOT NULL THEN
    v_prev_winner := v_ch.winner_id;
    v_other := CASE WHEN v_prev_winner = v_ch.creator_id THEN v_ch.opponent_id ELSE v_ch.creator_id END;
    UPDATE public.wallets SET locked_balance = locked_balance - v_ch.bet_amount, updated_at = now() WHERE user_id = v_prev_winner;
    UPDATE public.wallets SET locked_balance = locked_balance + v_ch.bet_amount, updated_at = now() WHERE user_id = v_other;
    UPDATE public.challenges SET winner_id = NULL, settlement_release_at = NULL WHERE id = p_challenge_id RETURNING * INTO v_ch;
  END IF;

  -- Trava as duas carteiras em ordem determinística (evita deadlock, mesmo
  -- padrão de fn_report_challenge_result).
  SELECT * INTO v_wallet_a FROM public.wallets WHERE user_id = LEAST(v_ch.creator_id, v_ch.opponent_id) FOR UPDATE;
  SELECT * INTO v_wallet_b FROM public.wallets WHERE user_id = GREATEST(v_ch.creator_id, v_ch.opponent_id) FOR UPDATE;
  IF v_wallet_a IS NULL OR v_wallet_b IS NULL THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira de um dos participantes não encontrada.';
  END IF;

  UPDATE public.wallets SET balance = balance + v_ch.bet_amount, locked_balance = locked_balance - v_ch.bet_amount, updated_at = now() WHERE id = v_wallet_a.id;
  UPDATE public.wallets SET balance = balance + v_ch.bet_amount, locked_balance = locked_balance - v_ch.bet_amount, updated_at = now() WHERE id = v_wallet_b.id;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES
    (v_wallet_a.id, 'bet_refund', v_ch.bet_amount, 'completed',
     'Disputa anulada pela moderação, saldo devolvido (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'),
    (v_wallet_b.id, 'bet_refund', v_ch.bet_amount, 'completed',
     'Disputa anulada pela moderação, saldo devolvido (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')');

  UPDATE public.challenges SET status = 'cancelled', updated_at = now() WHERE id = p_challenge_id RETURNING * INTO v_ch;

  UPDATE public.disputes
  SET status = 'cancelled', resolution = p_reason, updated_at = now()
  WHERE challenge_id = p_challenge_id;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  SELECT uid, 'dispute_cancelled', 'Disputa anulada',
    'A moderação da ArenaX1 analisou o desafio de ' || v_ch.game || ' e, sem provas suficientes de nenhum lado, anulou a disputa — o valor apostado voltou pra sua carteira. Motivo: ' || p_reason,
    p_challenge_id
  FROM (VALUES (v_ch.creator_id), (v_ch.opponent_id)) AS t(uid);

  RETURN v_ch;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_cancel_challenge_dispute(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_cancel_challenge_dispute(uuid, uuid, text) TO service_role;
