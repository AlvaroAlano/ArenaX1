-- Execute no SQL Editor do Supabase.
--
-- Dois ajustes de INFRA que estavam faltando (código do front já esperava por
-- eles):
--   A) REALTIME — as tabelas de mensagem/estado nunca foram adicionadas à
--      publicação `supabase_realtime`. Sem isso, os `postgres_changes` que os
--      chats (partida/disputa/suporte) e a tela da partida assinam NUNCA
--      disparam — daí só atualizar recarregando a página.
--   B) STORAGE — o bucket `disputes` (anexos/provas da disputa) não existia, o
--      que fazia o upload falhar com "Erro ao enviar anexo".

-- ─────────────────────────────────────────────────────────────────────────
-- A) Realtime: adiciona as tabelas à publicação (idempotente — só adiciona o
--    que ainda não está lá, então rodar de novo não quebra).
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'challenge_messages',        -- chat da partida (jogador vs jogador)
    'dispute_messages',          -- chat de mediação da disputa
    'support_ticket_messages',   -- thread de suporte (migração 29)
    'challenges',                -- estado da partida (confirmar presença, resultado…)
    'challenge_join_requests',   -- solicitações de entrada
    'disputes',                  -- abertura/fechamento de disputa
    'wallets',                   -- saldo em tempo real (Carteira)
    'transactions',              -- extrato em tempo real
    'notifications'              -- sino
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- REPLICA IDENTITY FULL nas tabelas que o front assina por UPDATE com filtro:
-- garante que o payload de UPDATE carregue a linha inteira (e o filtro por
-- coluna funcione de forma confiável). Em INSERT-only não muda nada.
ALTER TABLE public.challenges REPLICA IDENTITY FULL;
ALTER TABLE public.wallets REPLICA IDENTITY FULL;

-- ─────────────────────────────────────────────────────────────────────────
-- B) Storage: bucket público `disputes` para os anexos/provas da disputa.
--    Público porque o front exibe as imagens via getPublicUrl. Upload só por
--    usuário autenticado; leitura liberada (mesma lógica de um print de prova).
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('disputes', 'disputes', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "disputes_upload_authenticated" ON storage.objects;
CREATE POLICY "disputes_upload_authenticated"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'disputes');

DROP POLICY IF EXISTS "disputes_read_public" ON storage.objects;
CREATE POLICY "disputes_read_public"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'disputes');
