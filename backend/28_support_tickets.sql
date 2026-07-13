-- Execute no SQL Editor do Supabase (depois de 27).
--
-- "E-mail interno": captura ESTRUTURADA de contato/suporte. Resolve o problema
-- de matching do mailto (o ticket já sai amarrado ao user_id logado, sem
-- adivinhar de qual conta veio) e é a SEMENTE da Fila de revisão reputacional
-- (regra 4.4): quando a 4.4 for construída, esta tabela ganha uma thread de
-- mensagens e uma tela de lista no admin por cima — não duplica esforço.
--
-- Escopo desta migração (opção C, fechada com o usuário): só a CAPTURA + o
-- ALERTA DE ADMIN (obrigatório — um inbox que ninguém olha é a mesma promessa
-- vazia do mailto). A RESPOSTA do admin é MANUAL por enquanto (via SQL/portal),
-- mesmo padrão do finalize-due-deletions antes do cron existir. A thread de ida
-- e volta e a tela de lista no admin são trabalho da 4.4.

-- ─────────────────────────────────────────────────────────────────────────
-- 0) Tabela de tickets.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL DEFAULT 'other'
    CHECK (category IN ('badge_contest', 'match', 'wallet', 'account', 'other')),
  message text NOT NULL,
  challenge_id uuid REFERENCES public.challenges(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.support_tickets IS
  'Tickets de suporte/contato ("e-mail interno"). Captura estruturada amarrada ao user_id. Semente da Fila de revisão reputacional (regra 4.4): a thread de mensagens e a tela de admin vêm por cima desta tabela depois.';

CREATE INDEX IF NOT EXISTS support_tickets_open_idx
  ON public.support_tickets (status, created_at DESC) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS support_tickets_user_idx
  ON public.support_tickets (user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────
-- 1) RLS: o dono lê os próprios tickets. INSERT é só via fn (service_role); o
--    client nunca insere direto — mesmo padrão de challenges/disputes.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Dono lê os próprios tickets" ON public.support_tickets;
CREATE POLICY "Dono lê os próprios tickets"
  ON public.support_tickets FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Novo tipo de notificação: alerta de ticket novo pro admin.
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
    'challenge_join_requested', 'challenge_request_accepted', 'challenge_request_rejected',
    'challenge_expired',
    'abandonment_warning',
    'support_ticket_opened'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Abrir ticket + ALERTAR OS ADMINS (obrigatório). SECURITY DEFINER; o
--    p_user_id vem SEMPRE do JWT verificado no backend, nunca do corpo.
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

  -- ALERTA obrigatório: um aviso pra cada admin. Como o admin também joga, o
  -- sino (polling 30s, presente em toda tela) acende assim que ele abrir o app.
  -- NÃO há infra de e-mail/push hoje: pra um alerta que chegue no celular
  -- offline, o passo seguinte é plugar um webhook (Discord/Telegram) ou e-mail
  -- aqui dentro — não faz parte desta migração.
  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  SELECT pr.id, 'support_ticket_opened', 'Novo ticket de suporte 📬',
    coalesce(v_username, 'Um usuário') || ' abriu um ticket (' || v_cat_label || '). Confira em support_tickets.',
    p_challenge_id
  FROM public.profiles pr
  WHERE pr.is_admin = true;

  RETURN v_ticket;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_open_support_ticket(uuid, text, text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_open_support_ticket(uuid, text, text, uuid) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- RESOLUÇÃO MANUAL (até a Fila 4.4). Sem tela de admin ainda, um ticket é
-- resolvido na mão pelo SQL Editor. Exemplos:
--
--   -- 1) ver os tickets abertos, com quem abriu:
--   SELECT t.created_at, p.username, t.category, t.message, t.id, t.user_id
--   FROM public.support_tickets t JOIN public.profiles p ON p.id = t.user_id
--   WHERE t.status = 'open' ORDER BY t.created_at;
--
--   -- 2a) contestação de selo NEGADA → publica o selo agora:
--   UPDATE public.profiles SET abandonment_badge_public_at = now() WHERE id = '<user_id>';
--
--   -- 2b) contestação de selo ACEITA → arquiva o selo (volta a NULL; um novo
--   --     abandono futuro reabre a janela de 48h e re-notifica, de propósito):
--   UPDATE public.profiles SET abandonment_badge_public_at = NULL WHERE id = '<user_id>';
--
--   -- 3) fecha o ticket:
--   UPDATE public.support_tickets SET status = 'resolved', updated_at = now() WHERE id = '<ticket_id>';
--
--   -- 4) (opcional) responder o usuário por uma notificação manual:
--   INSERT INTO public.notifications (user_id, type, title, body)
--   VALUES ('<user_id>', 'support_ticket_opened', 'Sobre o seu contato', 'Recebemos e ...');
-- ─────────────────────────────────────────────────────────────────────────
