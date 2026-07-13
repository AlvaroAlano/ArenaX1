-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Objetivo: profiles ainda não guarda "em que plataforma eu jogo" — a tela
-- de Configurações já tinha um seletor "Plataforma Principal" no HTML, mas
-- solto (sem v-model, sem load, sem save; ver frontend/src/views/SettingsView.vue).
-- Sem essa coluna, toda tela que cria desafio/torneio pago sempre abre com
-- 'PS5' fixo, obrigando o jogador a trocar manualmente toda vez mesmo tendo
-- configurado o próprio jogo no perfil.
--
-- Mesmos 4 valores usados em challenges.platform (schema.sql) e
-- online_tournaments.platform (07_online_tournaments.sql), pra reusar o
-- mesmo vocabulário em vez de inventar um novo.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS main_platform text
  CHECK (main_platform IN ('PS5', 'Xbox', 'PC', 'Crossplay'));

COMMENT ON COLUMN public.profiles.main_platform IS
  'Plataforma principal do jogador (PS5/Xbox/PC/Crossplay), configurada em Ajustes > Perfil. Usada só como valor pré-selecionado ao criar desafio/torneio — não impede escolher outra na hora.';
