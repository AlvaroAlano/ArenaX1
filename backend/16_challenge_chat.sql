-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Objetivo: chat direto entre os dois participantes de um desafio (criador
-- e oponente) depois que a aposta foi aceita — pra combinar sala, horário,
-- etc. Separado de public.dispute_messages de propósito: aquele é o canal
-- de mediação com a equipe da ArenaX1 quando o resultado diverge; este é
-- só uma conversa livre entre os dois jogadores, sem terceiros.

CREATE TABLE IF NOT EXISTS public.challenge_messages (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

CREATE INDEX IF NOT EXISTS challenge_messages_challenge_id_idx
  ON public.challenge_messages (challenge_id, created_at);

ALTER TABLE public.challenge_messages ENABLE ROW LEVEL SECURITY;

-- Mesmo padrão de dispute_messages: só quem é criador ou oponente do
-- desafio em questão lê/escreve nessa conversa.
CREATE POLICY "Permitir leitura pelos participantes do desafio"
  ON public.challenge_messages FOR SELECT
  TO authenticated
  USING (
    challenge_id IN (
      SELECT id FROM public.challenges
      WHERE creator_id = auth.uid() OR opponent_id = auth.uid()
    )
  );

CREATE POLICY "Permitir envio pelos participantes do desafio"
  ON public.challenge_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    challenge_id IN (
      SELECT id FROM public.challenges
      WHERE creator_id = auth.uid() OR opponent_id = auth.uid()
    )
  );
