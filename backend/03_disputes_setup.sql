-- Tabela de Disputas
CREATE TABLE IF NOT EXISTS public.disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID REFERENCES public.challenges(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'open', -- open, resolved, closed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Tabela de Mensagens da Disputa
CREATE TABLE IF NOT EXISTS public.dispute_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispute_id UUID REFERENCES public.disputes(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id),
    message TEXT,
    attachment_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Políticas RLS (caso não existam ou para garantir)
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispute_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir visualização da disputa pelos participantes"
  ON public.disputes FOR SELECT
  TO authenticated
  USING (
    challenge_id IN (
      SELECT id FROM public.challenges
      WHERE creator_id = auth.uid() OR opponent_id = auth.uid()
    )
  );

CREATE POLICY "Permitir visualização de mensagens pelos participantes"
  ON public.dispute_messages FOR SELECT
  TO authenticated
  USING (
    dispute_id IN (
      SELECT d.id FROM public.disputes d
      JOIN public.challenges c ON d.challenge_id = c.id
      WHERE c.creator_id = auth.uid() OR c.opponent_id = auth.uid()
    )
  );

CREATE POLICY "Permitir envio de mensagens pelos participantes"
  ON public.dispute_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    dispute_id IN (
      SELECT d.id FROM public.disputes d
      JOIN public.challenges c ON d.challenge_id = c.id
      WHERE c.creator_id = auth.uid() OR c.opponent_id = auth.uid()
    )
  );

-- INSTRUÇÕES DE STORAGE:
-- Vá ao painel do Supabase -> Storage
-- Crie um novo bucket chamado "disputes"
-- Deixe como "Public" para simplificar a visualização das imagens no chat
-- Vá em Policies -> New Policy (para o bucket disputes) -> FOR INSERT
-- Regra: Permitir envio para Authenticated Users.
