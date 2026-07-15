-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 30_realtime_and_storage.sql).
--
-- Objetivo: integração real com o Mercado Pago para depósito via Pix (a
-- API deles cobre bem o RECEBIMENTO de Pix, mas não tem endpoint para
-- enviar Pix a chave de terceiro) e um fluxo de saque manual com painel de
-- admin, já que o saque não pode ser automatizado pelo mesmo gateway.
--
-- Este arquivo faz CREATE OR REPLACE em cima do corpo do 17 (não do 04 —
-- aquele já está desatualizado: o 17 acrescentou os INSERTs em
-- notifications, e é essa a versão viva das duas funções hoje).

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Colunas novas em transactions.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS fee_amount numeric(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS gateway text;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS pix_key text;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS admin_id uuid REFERENCES public.profiles(id);
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS processed_at timestamptz;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS failure_reason text;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Tipos novos de notificação: o saque deixa de ser instantâneo, então
--    "withdraw_completed" (17) dá lugar a um ciclo pending → confirmed/rejected.
--    Mantido "withdraw_completed" na lista só por compatibilidade com linhas
--    antigas — nada novo usa esse tipo daqui pra frente. Lista base copiada
--    de 29_support_ticket_thread.sql (última a redefinir essa constraint).
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type in (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss',
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
-- 3) Depósito Pix confirmado: mesmo corpo do 17, mas credita o valor
--    LÍQUIDO (bruto cobrado - taxa), não o bruto. A validação de
--    AMOUNT_MISMATCH continua contra o bruto (é o que o Mercado Pago
--    reporta de volta via GET /v1/payments/{id}).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_process_pix_deposit_webhook(
  p_external_id text,
  p_amount numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_transaction public.transactions;
  v_wallet public.wallets;
  v_new_balance numeric;
  v_net_amount numeric;
BEGIN
  SELECT * INTO v_transaction
  FROM public.transactions
  WHERE external_id = p_external_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRANSACTION_NOT_FOUND: Transação correspondente não encontrada.';
  END IF;

  IF v_transaction.status = 'completed' THEN
    RETURN jsonb_build_object('status', 'success', 'message', 'Transação já processada anteriormente (idempotente).');
  END IF;

  IF v_transaction.amount != p_amount THEN
    RAISE EXCEPTION 'AMOUNT_MISMATCH: O valor informado pelo gateway não confere com a transação registrada.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = v_transaction.wallet_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira associada não encontrada.';
  END IF;

  v_net_amount := v_transaction.amount - v_transaction.fee_amount;
  v_new_balance := v_wallet.balance + v_net_amount;

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet.id;
  UPDATE public.transactions SET status = 'completed' WHERE id = v_transaction.id;

  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (v_wallet.user_id, 'deposit_confirmed', 'Depósito confirmado 💰',
    CASE WHEN v_transaction.fee_amount > 0
      THEN 'Seu depósito caiu na carteira: R$ ' || v_net_amount || ' creditados (taxa de R$ ' || v_transaction.fee_amount || ' já descontada). Saldo atual: R$ ' || v_new_balance || '.'
      ELSE 'Seu depósito de R$ ' || v_net_amount || ' caiu na carteira. Saldo atual: R$ ' || v_new_balance || '.'
    END);

  RETURN jsonb_build_object('status', 'success', 'message', 'Saldo atualizado com sucesso.', 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Saque: mesmo corpo do 17, mas fica PENDING em vez de COMPLETED — não
--    existe envio automático de Pix a terceiro pelo Mercado Pago, então o
--    dinheiro sai da carteira na hora (evita saque duplicado) e um admin
--    confirma manualmente depois de mandar de verdade (fn_confirm_withdraw)
--    ou rejeita e estorna (fn_reject_withdraw).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_withdraw(
  p_user_id uuid,
  p_amount numeric,
  p_pix_key text,
  p_external_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.wallets;
  v_new_balance numeric;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: O valor de saque deve ser maior que zero.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do usuário não encontrada.';
  END IF;

  IF v_wallet.balance < p_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para realizar o saque.';
  END IF;

  v_new_balance := v_wallet.balance - p_amount;

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet.id;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description, external_id, pix_key)
  VALUES (
    v_wallet.id, 'withdraw', -p_amount, 'pending',
    'Saque via Pix solicitado para chave: ' || p_pix_key,
    p_external_id, p_pix_key
  );

  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (p_user_id, 'withdraw_pending', 'Saque solicitado ⏳',
    'Seu saque de R$ ' || p_amount || ' via Pix está em análise e será processado manualmente em breve.');

  RETURN jsonb_build_object('status', 'pending', 'message', 'Saque solicitado! Nossa equipe processa manualmente e você recebe uma notificação assim que o Pix for enviado.', 'amount', p_amount, 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 5) Admin confirma um saque pendente: já mandou o Pix de verdade pelo
--    próprio banco/Mercado Pago, só marca como concluído no sistema.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_confirm_withdraw(
  p_transaction_id uuid,
  p_admin_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx public.transactions;
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRANSACTION_NOT_FOUND: Transação não encontrada.';
  END IF;

  IF v_tx.type != 'withdraw' OR v_tx.status != 'pending' THEN
    RAISE EXCEPTION 'INVALID_STATUS: Esta transação não está pendente de confirmação.';
  END IF;

  UPDATE public.transactions
  SET status = 'completed', admin_id = p_admin_id, processed_at = now()
  WHERE id = p_transaction_id;

  SELECT * INTO v_wallet FROM public.wallets WHERE id = v_tx.wallet_id;

  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (v_wallet.user_id, 'withdraw_confirmed', 'Saque confirmado ✅',
    'Seu saque de R$ ' || ABS(v_tx.amount) || ' via Pix foi enviado para a chave cadastrada.');

  RETURN jsonb_build_object('status', 'success', 'message', 'Saque confirmado.');
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6) Admin rejeita um saque pendente: estorna o valor pro saldo do usuário
--    (nunca fica dinheiro "perdido" — princípio 1 do regras-do-sistema.md).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_reject_withdraw(
  p_transaction_id uuid,
  p_admin_id uuid,
  p_reason text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx public.transactions;
  v_wallet public.wallets;
  v_new_balance numeric;
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRANSACTION_NOT_FOUND: Transação não encontrada.';
  END IF;

  IF v_tx.type != 'withdraw' OR v_tx.status != 'pending' THEN
    RAISE EXCEPTION 'INVALID_STATUS: Esta transação não está pendente de confirmação.';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE id = v_tx.wallet_id FOR UPDATE;

  v_new_balance := v_wallet.balance + ABS(v_tx.amount);
  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet.id;

  UPDATE public.transactions
  SET status = 'failed', admin_id = p_admin_id, processed_at = now(), failure_reason = p_reason
  WHERE id = p_transaction_id;

  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (v_wallet.user_id, 'withdraw_rejected', 'Saque rejeitado ❌',
    'Seu saque de R$ ' || ABS(v_tx.amount) || ' foi rejeitado e o valor voltou para seu saldo. Motivo: ' || p_reason);

  RETURN jsonb_build_object('status', 'success', 'message', 'Saque rejeitado e valor estornado.', 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants: só o backend (service_role) pode chamar essas funções.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_process_pix_deposit_webhook(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_withdraw(uuid, numeric, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_confirm_withdraw(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_reject_withdraw(uuid, uuid, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_process_pix_deposit_webhook(text, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_withdraw(uuid, numeric, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_confirm_withdraw(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_reject_withdraw(uuid, uuid, text) TO service_role;
