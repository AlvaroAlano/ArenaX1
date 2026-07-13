-- Execute no SQL Editor do Supabase (depois de 28).
--
-- Regra 4.4 — THREAD DE SUPORTE: dá à support_tickets (migração 28) a ida-e-volta
-- de mensagens e o gancho de notificação que a 28 deixou de propósito pra depois.
--   • Admin responde  → o DONO do ticket é notificado e cai direto na conversa.
--   • Usuário responde → os ADMINS são alertados de que há mensagem nova.
-- A tela de fila do admin e a de conversa do usuário são só UI por cima disto.
-- Mesmo padrão das outras funções: INSERT só via fn (service_role); o
-- p_sender_id vem SEMPRE do JWT verificado no backend, nunca do corpo.

-- ─────────────────────────────────────────────────────────────────────────
-- 0) Thread de mensagens de um ticket.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.support_ticket_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- true = fala do time de suporte; false = fala do usuário dono do ticket.
  from_support boolean NOT NULL DEFAULT false,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_ticket_messages_ticket_idx
  ON public.support_ticket_messages (ticket_id, created_at);

COMMENT ON TABLE public.support_ticket_messages IS
  'Thread de ida-e-volta de um support_ticket (regra 4.4). from_support separa a fala do suporte da fala do usuário.';

-- ─────────────────────────────────────────────────────────────────────────
-- 1) RLS: o dono do ticket lê as mensagens dele; admin lê todas. INSERT nunca
--    é direto do client — só via fn (service_role), igual challenges/disputes.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Dono ou admin lê as mensagens do ticket" ON public.support_ticket_messages;
CREATE POLICY "Dono ou admin lê as mensagens do ticket"
  ON public.support_ticket_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.support_tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = true)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2) notifications.ticket_id (pra notificação levar direto à conversa) e os
--    dois novos tipos de resposta.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE SET NULL;

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
    'challenge_expired',
    'abandonment_warning',
    'support_ticket_opened', 'support_ticket_replied', 'support_ticket_message'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Responder um ticket. Quem pode escrever: o dono OU um admin. A mensagem é
--    "do suporte" quando quem escreve é admin E não é o dono (um admin pode
--    abrir o próprio ticket — nesse caso ele fala como usuário).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_reply_support_ticket(
  p_ticket_id uuid,
  p_sender_id uuid,
  p_body text
) RETURNS public.support_ticket_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.support_tickets;
  v_msg public.support_ticket_messages;
  v_sender_is_admin boolean;
  v_from_support boolean;
  v_sender_name text;
BEGIN
  IF p_body IS NULL OR length(btrim(p_body)) < 1 THEN
    RAISE EXCEPTION 'MESSAGE_TOO_SHORT: Escreva uma mensagem.';
  END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id = p_ticket_id;
  IF v_ticket.id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Ticket não encontrado.';
  END IF;

  SELECT coalesce(is_admin, false) INTO v_sender_is_admin FROM public.profiles WHERE id = p_sender_id;

  IF p_sender_id <> v_ticket.user_id AND NOT v_sender_is_admin THEN
    RAISE EXCEPTION 'NOT_ALLOWED: Você não tem acesso a este ticket.';
  END IF;

  v_from_support := v_sender_is_admin AND p_sender_id <> v_ticket.user_id;

  INSERT INTO public.support_ticket_messages (ticket_id, sender_id, from_support, body)
  VALUES (p_ticket_id, p_sender_id, v_from_support, btrim(p_body))
  RETURNING * INTO v_msg;

  -- Toca updated_at (ordena a fila do admin por atividade); se o usuário voltou
  -- a escrever num ticket resolvido/fechado, reabre.
  UPDATE public.support_tickets
  SET updated_at = now(),
      status = CASE WHEN v_from_support THEN status
                    WHEN status <> 'open' THEN 'open'
                    ELSE status END
  WHERE id = p_ticket_id;

  SELECT username INTO v_sender_name FROM public.profiles WHERE id = p_sender_id;

  IF v_from_support THEN
    INSERT INTO public.notifications (user_id, type, title, body, ticket_id, challenge_id)
    VALUES (v_ticket.user_id, 'support_ticket_replied', 'Suporte respondeu 💬',
      'A equipe respondeu seu ticket. Toque para abrir a conversa.',
      p_ticket_id, v_ticket.challenge_id);
  ELSE
    INSERT INTO public.notifications (user_id, type, title, body, ticket_id, challenge_id)
    SELECT pr.id, 'support_ticket_message', 'Nova mensagem no ticket 📨',
      coalesce(v_sender_name, 'Um usuário') || ' respondeu um ticket de suporte.',
      p_ticket_id, v_ticket.challenge_id
    FROM public.profiles pr
    WHERE pr.is_admin = true AND pr.id <> p_sender_id;
  END IF;

  RETURN v_msg;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_reply_support_ticket(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_reply_support_ticket(uuid, uuid, text) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Admin muda o status do ticket (resolver/fechar/reabrir).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_set_support_ticket_status(
  p_ticket_id uuid,
  p_admin_id uuid,
  p_status text
) RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.support_tickets;
  v_is_admin boolean;
BEGIN
  IF p_status NOT IN ('open', 'resolved', 'closed') THEN
    RAISE EXCEPTION 'INVALID_STATUS: Status inválido.';
  END IF;

  SELECT coalesce(is_admin, false) INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'NOT_ALLOWED: Ação restrita a administradores.';
  END IF;

  UPDATE public.support_tickets
  SET status = p_status, updated_at = now()
  WHERE id = p_ticket_id
  RETURNING * INTO v_ticket;

  IF v_ticket.id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Ticket não encontrado.';
  END IF;

  RETURN v_ticket;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_set_support_ticket_status(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_set_support_ticket_status(uuid, uuid, text) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- 5) Redefine fn_open_support_ticket (base da 28) só pra CARIMBAR o ticket_id
--    na notificação do admin — assim o clique no sino já cai direto na conversa
--    daquele ticket, em vez de na fila. Corpo idêntico ao da 28 fora isso.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_open_support_ticket(
  p_user_id uuid,
  p_category text,
  p_message text,
  p_challenge_id uuid DEFAULT NULL
) RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.support_tickets;
  v_username text;
  v_cat_label text;
BEGIN
  IF p_message IS NULL OR length(btrim(p_message)) < 5 THEN
    RAISE EXCEPTION 'MESSAGE_TOO_SHORT: Descreva um pouco melhor o que aconteceu (mín. 5 caracteres).';
  END IF;

  INSERT INTO public.support_tickets (user_id, category, message, challenge_id)
  VALUES (
    p_user_id,
    coalesce(nullif(btrim(p_category), ''), 'other'),
    btrim(p_message),
    p_challenge_id
  )
  RETURNING * INTO v_ticket;

  SELECT username INTO v_username FROM public.profiles WHERE id = p_user_id;
  v_cat_label := CASE v_ticket.category
    WHEN 'badge_contest' THEN 'contestação de selo de abandono'
    WHEN 'match' THEN 'problema em partida'
    WHEN 'wallet' THEN 'carteira/saldo'
    WHEN 'account' THEN 'conta'
    ELSE 'assunto geral'
  END;

  INSERT INTO public.notifications (user_id, type, title, body, ticket_id, challenge_id)
  SELECT pr.id, 'support_ticket_opened', 'Novo ticket de suporte 📬',
    coalesce(v_username, 'Um usuário') || ' abriu um ticket (' || v_cat_label || '). Toque para abrir a conversa.',
    v_ticket.id, p_challenge_id
  FROM public.profiles pr
  WHERE pr.is_admin = true;

  RETURN v_ticket;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_open_support_ticket(uuid, text, text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_open_support_ticket(uuid, text, text, uuid) TO service_role;
