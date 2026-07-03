-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Objetivo: eliminar as condições de corrida do backend (read-modify-write em
-- Python, sem transação nem lock). Toda mutação de saldo passa a acontecer
-- dentro de uma única função Postgres, com a linha da carteira travada
-- (SELECT ... FOR UPDATE) durante a operação inteira. Isso é atômico e
-- resistente a chamadas concorrentes, o que o FastAPI + PostgREST sozinhos
-- não garantiam.
--
-- Convenção de erro: RAISE EXCEPTION 'CODIGO_ERRO: mensagem para o usuário'.
-- O backend (challenges.py / pix.py) faz o parse do prefixo antes de ':' para
-- decidir o status HTTP e usa o restante como detail.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Criar desafio: congela o saldo do criador e cria a sala, atomicamente.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_create_challenge(
  p_creator_id uuid,
  p_bet_amount numeric,
  p_platform text,
  p_game text
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.wallets;
  v_challenge public.challenges;
BEGIN
  IF p_bet_amount < 0 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: O valor da aposta não pode ser negativo.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_creator_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do criador não encontrada.';
  END IF;

  IF v_wallet.balance < p_bet_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para abrir este desafio.';
  END IF;

  UPDATE public.wallets
  SET balance = balance - p_bet_amount,
      locked_balance = locked_balance + p_bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  INSERT INTO public.challenges (creator_id, bet_amount, platform, game, status)
  VALUES (p_creator_id, p_bet_amount, p_platform, p_game, 'open')
  RETURNING * INTO v_challenge;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_freeze',
    -p_bet_amount,
    'completed',
    'Saldo congelado para desafio X1 (Sala: ' || substr(v_challenge.id::text, 1, 8) || ')'
  );

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Aceitar desafio: trava a sala + a carteira do oponente na mesma transação.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_accept_challenge(
  p_challenge_id uuid,
  p_opponent_id uuid
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.status != 'open' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_OPEN: Este desafio não está mais aberto para aceitação.';
  END IF;

  IF v_challenge.creator_id = p_opponent_id THEN
    RAISE EXCEPTION 'SELF_ACCEPT: Você não pode aceitar seu próprio desafio.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_opponent_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do oponente não encontrada.';
  END IF;

  IF v_wallet.balance < v_challenge.bet_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para aceitar esta aposta.';
  END IF;

  UPDATE public.wallets
  SET balance = balance - v_challenge.bet_amount,
      locked_balance = locked_balance + v_challenge.bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  UPDATE public.challenges
  SET opponent_id = p_opponent_id,
      status = 'in_progress',
      updated_at = now()
  WHERE id = p_challenge_id
  RETURNING * INTO v_challenge;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_freeze',
    -v_challenge.bet_amount,
    'completed',
    'Saldo congelado para desafio X1 (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'
  );

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Reportar resultado: apura consenso/disputa e paga o prêmio, atomicamente.
--    Quando as duas carteiras precisam ser travadas, a ordem é sempre a
--    mesma (menor user_id primeiro) para nunca gerar deadlock entre duas
--    chamadas concorrentes.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_report_challenge_result(
  p_challenge_id uuid,
  p_user_id uuid,
  p_result text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_is_creator boolean;
  v_winner_id uuid;
  v_loser_id uuid;
  v_bet_amount numeric;
  v_rake_percentage numeric := 0.10;
  v_prize_pool numeric;
  v_platform_fee numeric;
  v_winner_prize numeric;
  v_wallet_a public.wallets;
  v_wallet_b public.wallets;
  v_winner_wallet public.wallets;
  v_loser_wallet public.wallets;
BEGIN
  IF p_result NOT IN ('win', 'loss') THEN
    RAISE EXCEPTION 'INVALID_RESULT: Resultado inválido. Deve ser ''win'' ou ''loss''.';
  END IF;

  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.status != 'in_progress' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_IN_PROGRESS: Este desafio não está em andamento.';
  END IF;

  v_is_creator := (v_challenge.creator_id = p_user_id);

  IF NOT v_is_creator AND v_challenge.opponent_id != p_user_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não faz parte deste desafio.';
  END IF;

  IF v_is_creator THEN
    IF v_challenge.creator_result IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado.';
    END IF;
    UPDATE public.challenges SET creator_result = p_result WHERE id = p_challenge_id
      RETURNING * INTO v_challenge;
  ELSE
    IF v_challenge.opponent_result IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado.';
    END IF;
    UPDATE public.challenges SET opponent_result = p_result WHERE id = p_challenge_id
      RETURNING * INTO v_challenge;
  END IF;

  IF v_challenge.creator_result IS NULL OR v_challenge.opponent_result IS NULL THEN
    RETURN jsonb_build_object('message', 'Resultado reportado. Aguardando oponente.', 'status', 'waiting');
  END IF;

  -- Consenso: um ganhou, o outro perdeu
  IF (v_challenge.creator_result = 'win' AND v_challenge.opponent_result = 'loss')
     OR (v_challenge.creator_result = 'loss' AND v_challenge.opponent_result = 'win') THEN

    IF v_challenge.creator_result = 'win' THEN
      v_winner_id := v_challenge.creator_id;
      v_loser_id := v_challenge.opponent_id;
    ELSE
      v_winner_id := v_challenge.opponent_id;
      v_loser_id := v_challenge.creator_id;
    END IF;

    v_bet_amount := v_challenge.bet_amount;
    v_prize_pool := v_bet_amount * 2;
    v_platform_fee := v_prize_pool * v_rake_percentage;
    v_winner_prize := v_prize_pool - v_platform_fee;

    -- Trava as duas carteiras em ordem determinística (evita deadlock)
    SELECT * INTO v_wallet_a FROM public.wallets
      WHERE user_id = LEAST(v_winner_id, v_loser_id) FOR UPDATE;
    SELECT * INTO v_wallet_b FROM public.wallets
      WHERE user_id = GREATEST(v_winner_id, v_loser_id) FOR UPDATE;

    IF v_wallet_a IS NULL OR v_wallet_b IS NULL THEN
      RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira de um dos participantes não encontrada.';
    END IF;

    IF v_wallet_a.user_id = v_winner_id THEN
      v_winner_wallet := v_wallet_a;
      v_loser_wallet := v_wallet_b;
    ELSE
      v_winner_wallet := v_wallet_b;
      v_loser_wallet := v_wallet_a;
    END IF;

    UPDATE public.wallets
    SET balance = balance + v_winner_prize,
        locked_balance = locked_balance - v_bet_amount,
        updated_at = now()
    WHERE id = v_winner_wallet.id;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_bet_amount,
        updated_at = now()
    WHERE id = v_loser_wallet.id;

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES
      (v_winner_wallet.id, 'challenge_win', v_winner_prize, 'completed',
       'Vitória no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'),
      (v_loser_wallet.id, 'challenge_loss', -v_bet_amount, 'completed',
       'Derrota no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')');

    UPDATE public.challenges
    SET status = 'completed',
        winner_id = v_winner_id,
        rake_amount = v_platform_fee,
        updated_at = now()
    WHERE id = p_challenge_id;

    RETURN jsonb_build_object(
      'message', 'Resultado confirmado com consenso.',
      'status', 'completed',
      'winner_id', v_winner_id
    );
  ELSE
    -- Divergência: ambos "win" ou ambos "loss"
    UPDATE public.challenges SET status = 'disputed', updated_at = now() WHERE id = p_challenge_id;

    INSERT INTO public.disputes (challenge_id, status) VALUES (p_challenge_id, 'open');

    RETURN jsonb_build_object(
      'message', 'Divergência de resultados. Partida em disputa.',
      'status', 'disputed'
    );
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Webhook do Pix: crédito idempotente do depósito, com trava na
--    transação e na carteira (dois webhooks quase simultâneos do gateway
--    não conseguem creditar em duplicidade).
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

  v_new_balance := v_wallet.balance + v_transaction.amount;

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet.id;
  UPDATE public.transactions SET status = 'completed' WHERE id = v_transaction.id;

  RETURN jsonb_build_object('status', 'success', 'message', 'Saldo atualizado com sucesso.', 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 5) Saque: debita a carteira e registra a transação atomicamente.
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

  INSERT INTO public.transactions (wallet_id, type, amount, status, description, external_id)
  VALUES (
    v_wallet.id, 'withdraw', -p_amount, 'completed',
    'Saque via Pix enviado para chave: ' || p_pix_key,
    p_external_id
  );

  RETURN jsonb_build_object('status', 'success', 'message', 'Saque via Pix realizado e enviado para processamento bancário.', 'amount', p_amount, 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants: só o backend (service_role) deve poder chamar essas funções.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_create_challenge(uuid, numeric, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_accept_challenge(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_process_pix_deposit_webhook(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_withdraw(uuid, numeric, text, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_create_challenge(uuid, numeric, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_accept_challenge(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_process_pix_deposit_webhook(text, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_withdraw(uuid, numeric, text, text) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- Idempotência: garante no banco que dois depósitos/saques nunca colidam
-- no mesmo external_id (segunda camada de defesa, além do RPC acima).
-- ─────────────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS transactions_external_id_unique
  ON public.transactions (external_id)
  WHERE external_id IS NOT NULL;
