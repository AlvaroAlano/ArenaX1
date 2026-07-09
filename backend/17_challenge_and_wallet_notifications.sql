-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 16_challenge_chat.sql).
--
-- Objetivo: fechar as lacunas de notificação levantadas em conversa com o
-- usuário. Hoje só o Torneio Online Pago gera notificações (08) — depósito
-- confirmado, saque realizado e todo o ciclo de um desafio 1v1 (aceito,
-- "sua vez de reportar" com ação direta pro botão, vitória/derrota e
-- disputa) ficavam mudos. Cancelamento de torneio pra quem tá inscrito JÁ
-- existe (tipo 'tournament_cancelled', ver 08) — nada a fazer ali.
--
-- CREATE OR REPLACE é seguro de rodar em cima do 04 (mesmas assinaturas de
-- função, só o corpo ganha os INSERTs em notifications no final).

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Coluna nova pra linkar notificação a um desafio (deep-link direto pra
--    /match/:id no frontend, mesma ideia de tournament_id/match_id do 08)
--    + tipos novos na constraint.
-- ─────────────────────────────────────────────────────────────────────────
alter table public.notifications
  add column if not exists challenge_id uuid references public.challenges(id) on delete cascade;

create index if not exists notifications_challenge_idx on public.notifications (challenge_id);

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss',
    'deposit_confirmed', 'withdraw_completed',
    'challenge_accepted', 'challenge_result_pending', 'challenge_win',
    'challenge_loss', 'challenge_disputed'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Depósito Pix confirmado: mesmo corpo do 04, com notificação no final.
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

  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (v_wallet.user_id, 'deposit_confirmed', 'Depósito confirmado 💰',
    'Seu depósito de R$ ' || v_transaction.amount || ' caiu na carteira. Saldo atual: R$ ' || v_new_balance || '.');

  RETURN jsonb_build_object('status', 'success', 'message', 'Saldo atualizado com sucesso.', 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Saque: mesmo corpo do 04, com notificação no final.
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

  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (p_user_id, 'withdraw_completed', 'Saque realizado ✅',
    'Seu saque de R$ ' || p_amount || ' via Pix foi processado e enviado para a chave informada.');

  RETURN jsonb_build_object('status', 'success', 'message', 'Saque via Pix realizado e enviado para processamento bancário.', 'amount', p_amount, 'new_balance', v_new_balance);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Aceitar desafio: mesmo corpo do 04, avisando o criador que alguém topou
--    (hoje o criador só descobre se ficar checando a lista manualmente).
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
  v_opponent_name text;
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

  SELECT username INTO v_opponent_name FROM public.profiles WHERE id = p_opponent_id;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (v_challenge.creator_id, 'challenge_accepted', 'Desafio aceito ⚔️',
    coalesce(v_opponent_name, 'Alguém') || ' topou sua aposta de R$ ' || v_challenge.bet_amount || ' em ' || v_challenge.game || '. Combinem sala e horário no chat.',
    p_challenge_id);

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 5) Reportar resultado: mesmo corpo do 04, com notificação em cada saída —
--    "sua vez de reportar" (pro lado que ainda não falou nada, com deep-link
--    direto pro botão de reportar em /match/:id), resultado final
--    (ganhou/perdeu) pros dois lados, e disputa pros dois lados.
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
  v_pending_user_id uuid;
  v_reporter_name text;
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
    -- Só um lado reportou até aqui: o outro lado é sempre quem ainda está
    -- NULL (o nosso já foi setado acima) — avisa ele que é a vez dele.
    v_pending_user_id := CASE WHEN v_challenge.creator_result IS NULL THEN v_challenge.creator_id ELSE v_challenge.opponent_id END;
    SELECT username INTO v_reporter_name FROM public.profiles WHERE id = p_user_id;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_pending_user_id, 'challenge_result_pending', 'Sua vez de reportar ⏳',
      coalesce(v_reporter_name, 'Seu adversário') || ' já reportou o resultado do desafio em ' || v_challenge.game || '. Confirma o que aconteceu pra liberar o pote.',
      p_challenge_id);

    RETURN jsonb_build_object('message', 'Resultado reportado. Aguardando oponente confirmar.', 'status', 'waiting');
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

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_winner_id, 'challenge_win', 'Você venceu 🏆',
      'Vitória confirmada no desafio de ' || v_challenge.game || '. R$ ' || v_winner_prize || ' caíram na sua carteira.',
      p_challenge_id);

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_loser_id, 'challenge_loss', 'Resultado confirmado',
      'Derrota confirmada no desafio de ' || v_challenge.game || '. R$ ' || v_bet_amount || ' saíram da sua carteira.',
      p_challenge_id);

    RETURN jsonb_build_object(
      'message', 'Resultado confirmado com consenso.',
      'status', 'completed',
      'winner_id', v_winner_id
    );
  ELSE
    -- Divergência: ambos "win" ou ambos "loss"
    UPDATE public.challenges SET status = 'disputed', updated_at = now() WHERE id = p_challenge_id;

    INSERT INTO public.disputes (challenge_id, status) VALUES (p_challenge_id, 'open');

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'challenge_disputed', 'Resultado em disputa ⚠️',
      'Os resultados do desafio de ' || v_challenge.game || ' bateram de frente e foram pra mediação da ArenaX1.',
      p_challenge_id
    FROM (VALUES (v_challenge.creator_id), (v_challenge.opponent_id)) AS t(uid);

    RETURN jsonb_build_object(
      'message', 'Divergência de resultados. Partida em disputa.',
      'status', 'disputed'
    );
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants (defensivo — mesmas assinaturas do 04, já concedidas, mas
-- reafirmando pra rodar este arquivo isoladamente sem depender de ordem).
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_process_pix_deposit_webhook(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_withdraw(uuid, numeric, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_accept_challenge(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_process_pix_deposit_webhook(text, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_withdraw(uuid, numeric, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_accept_challenge(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) TO service_role;
