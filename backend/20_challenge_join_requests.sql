-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 19_tiered_prize_distribution.sql).
--
-- Objetivo: hoje "aceitar" um desafio aberto é instantâneo — primeiro que
-- clica, leva, e o criador nunca escolhe contra quem vai jogar. Substitui
-- esse fluxo por solicitação: qualquer um pode pedir pra entrar (não trava
-- saldo, só confere se dá pra pagar), o criador vê todo mundo que pediu e
-- escolhe um — só nesse momento o saldo é travado, exatamente como
-- fn_accept_challenge fazia. Quando o criador escolhe alguém, todo o resto
-- das solicitações daquele desafio é rejeitado automaticamente (só dá pra
-- jogar com um adversário por vez).
--
-- fn_accept_challenge (04/17/18) é removido — sem mais aceite direto, único
-- caminho pra entrar num desafio aberto passa a ser solicitação.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Tabela de solicitações. Mesmo padrão de RLS de challenges/notifications:
--    só SELECT liberado pro client (solicitante vê a própria linha, criador
--    vê todas as do seu desafio); todo INSERT/UPDATE passa pelas funções
--    abaixo via service_role, nunca direto pelo client.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.challenge_join_requests (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending', -- 'pending', 'accepted', 'rejected', 'cancelled'
  created_at timestamptz default timezone('utc'::text, now()) not null,
  updated_at timestamptz default timezone('utc'::text, now()) not null
);

-- Trava por igual em banco (além da checagem amigável dentro da função):
-- nunca duas solicitações PENDENTES do mesmo usuário pro mesmo desafio. Não
-- bloqueia pedir de novo depois de um rejeitado — o desafio pode continuar
-- aberto se o criador recusou um sem ainda ter escolhido outro.
CREATE UNIQUE INDEX IF NOT EXISTS challenge_join_requests_one_pending_per_user
  ON public.challenge_join_requests (challenge_id, requester_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS challenge_join_requests_challenge_idx
  ON public.challenge_join_requests (challenge_id);

ALTER TABLE public.challenge_join_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Solicitante e criador podem ver as solicitações"
  ON public.challenge_join_requests FOR SELECT
  TO authenticated
  USING (
    requester_id = auth.uid()
    OR challenge_id IN (SELECT id FROM public.challenges WHERE creator_id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Tipo novo pra deep-link de notificação (challenge_id já existe desde o
--    17) + os 3 tipos novos na constraint.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss',
    'deposit_confirmed', 'withdraw_completed',
    'challenge_accepted', 'challenge_result_pending', 'challenge_win',
    'challenge_loss', 'challenge_disputed',
    'challenge_join_requested', 'challenge_request_accepted', 'challenge_request_rejected'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Solicitar entrada: não mexe em saldo, só valida e registra o pedido.
--    Mesma checagem de saldo do aceite antigo, mas sem travar nada ainda —
--    o saldo real do solicitante pode mudar até o criador decidir, por isso
--    fn_accept_join_request confere tudo de novo na hora H.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_request_join_challenge(
  p_challenge_id uuid,
  p_requester_id uuid
) RETURNS public.challenge_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_wallet public.wallets;
  v_request public.challenge_join_requests;
  v_requester_name text;
BEGIN
  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.status != 'open' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_OPEN: Este desafio não está mais aberto para solicitações.';
  END IF;

  IF v_challenge.creator_id = p_requester_id THEN
    RAISE EXCEPTION 'SELF_REQUEST: Você não pode solicitar entrada no seu próprio desafio.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.challenge_join_requests
    WHERE challenge_id = p_challenge_id AND requester_id = p_requester_id AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'ALREADY_REQUESTED: Você já solicitou entrada neste desafio.';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_requester_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira não encontrada.';
  END IF;

  IF v_wallet.balance < v_challenge.bet_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para solicitar este valor.';
  END IF;

  INSERT INTO public.challenge_join_requests (challenge_id, requester_id, status)
  VALUES (p_challenge_id, p_requester_id, 'pending')
  RETURNING * INTO v_request;

  SELECT username INTO v_requester_name FROM public.profiles WHERE id = p_requester_id;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (v_challenge.creator_id, 'challenge_join_requested', 'Pedido pra jogar 🙋',
    coalesce(v_requester_name, 'Alguém') || ' quer topar o valor da sua partida de R$ ' || v_challenge.bet_amount || ' em ' || v_challenge.game || '. Escolha quem entra.',
    p_challenge_id);

  RETURN v_request;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Escolher um solicitante: aqui sim trava o saldo — mesmo corpo do antigo
--    fn_accept_challenge (18), só que a partir de um request_id em vez de um
--    opponent_id direto. Rejeita automaticamente o resto das solicitações
--    pendentes do mesmo desafio (via CTE, pra notificar só quem acabou de
--    perder a vaga agora, não solicitações já respondidas antes).
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
      status = 'in_progress',
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
    'Sua solicitação pro desafio de R$ ' || v_challenge.bet_amount || ' em ' || v_challenge.game || ' foi aceita. Combinem sala e horário no chat.',
    v_challenge.id);

  -- Todo mundo que também pediu pra entrar nesse desafio perde a vaga —
  -- captura via RETURNING só quem acabou de ser rejeitado agora, pra não
  -- notificar de novo quem já tinha sido recusado antes (fn_reject_join_request).
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
-- 5) Recusar um solicitante específico, sem escolher outro ainda — desafio
--    continua 'open' pros demais pedidos ou pra alguém novo solicitar.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_reject_join_request(
  p_request_id uuid,
  p_creator_id uuid
) RETURNS public.challenge_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request public.challenge_join_requests;
  v_challenge public.challenges;
BEGIN
  SELECT * INTO v_request FROM public.challenge_join_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND: Solicitação não encontrada.';
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING: Esta solicitação já foi respondida.';
  END IF;

  SELECT * INTO v_challenge FROM public.challenges WHERE id = v_request.challenge_id;
  IF v_challenge.creator_id != p_creator_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Só quem criou o desafio pode recusar uma solicitação.';
  END IF;

  UPDATE public.challenge_join_requests
  SET status = 'rejected', updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (v_request.requester_id, 'challenge_request_rejected', 'Vaga preenchida',
    'Outro jogador foi escolhido pro desafio de ' || v_challenge.game || '. Fica de olho em outras salas abertas.',
    v_challenge.id);

  RETURN v_request;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6) Solicitante desiste do próprio pedido, antes de qualquer resposta.
--    Silencioso — não gera notificação, é uma ação da própria pessoa.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cancel_join_request(
  p_request_id uuid,
  p_requester_id uuid
) RETURNS public.challenge_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request public.challenge_join_requests;
BEGIN
  SELECT * INTO v_request FROM public.challenge_join_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND: Solicitação não encontrada.';
  END IF;

  IF v_request.requester_id != p_requester_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Essa solicitação não é sua.';
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING: Esta solicitação já foi respondida.';
  END IF;

  UPDATE public.challenge_join_requests
  SET status = 'cancelled', updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 7) Cancelar desafio: mesmo corpo do 14, só some com o aceite direto (não
--    existe mais) e ganha um passo a mais — solicitações pendentes daquele
--    desafio ficam órfãs se não forem encerradas junto (sem notificação,
--    mesma lógica silenciosa do cancelamento pelo próprio solicitante).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cancel_challenge(
  p_challenge_id uuid,
  p_user_id uuid
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

  IF v_challenge.creator_id != p_user_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não pode cancelar um desafio que não é seu.';
  END IF;

  IF v_challenge.status != 'open' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_OPEN: Só é possível cancelar desafios ainda abertos, sem oponente.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do criador não encontrada.';
  END IF;

  UPDATE public.wallets
  SET balance = balance + v_challenge.bet_amount,
      locked_balance = locked_balance - v_challenge.bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  UPDATE public.challenges
  SET status = 'cancelled',
      updated_at = now()
  WHERE id = p_challenge_id
  RETURNING * INTO v_challenge;

  UPDATE public.challenge_join_requests
  SET status = 'cancelled', updated_at = now()
  WHERE challenge_id = p_challenge_id AND status = 'pending';

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_refund',
    v_challenge.bet_amount,
    'completed',
    'Desafio cancelado, saldo devolvido (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'
  );

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 8) fn_accept_challenge sai de cena — substituída por fn_accept_join_request.
-- ─────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.fn_accept_challenge(uuid, uuid);

-- ─────────────────────────────────────────────────────────────────────────
-- Grants — não-negociável pra toda função SECURITY DEFINER nova.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_request_join_challenge(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_accept_join_request(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_reject_join_request(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_cancel_join_request(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_cancel_challenge(uuid, uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_request_join_challenge(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_accept_join_request(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_reject_join_request(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_cancel_join_request(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_cancel_challenge(uuid, uuid) TO service_role;
