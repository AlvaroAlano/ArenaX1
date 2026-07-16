-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 33_admin_challenge_disputes.sql). ⚠️ PRIORIDADE MÁXIMA — rode este ANTES
-- dos outros arquivos de correção (35, 36, 37).
--
-- Objetivo: fechar a falha CRÍTICA encontrada no teste geral (ACHADO-01) —
-- qualquer usuário logado conseguia se auto-promover a admin com uma chamada
-- REST direta ao Supabase, sem passar pelo backend:
--
--   PATCH /rest/v1/profiles?id=eq.<meu_id>  {"is_admin": true}  → 200 OK
--
-- A policy "Permitir atualização do próprio perfil" (policies.sql) libera
-- UPDATE na própria linha (auth.uid() = id) mas NÃO restringe COLUNA nenhuma
-- — então o mesmo caminho que o app usa pra editar apelido/EA ID também
-- deixava setar is_admin, fair_play_rating, abandoned_matches, etc. O mesmo
-- buraco já tinha sido fechado em `challenges` (05_rls_hardening.sql); o
-- `profiles` nunca recebeu o tratamento equivalente.
--
-- RLS do Postgres não faz restrição por coluna. A forma robusta é um trigger
-- BEFORE UPDATE que bloqueia a troca de colunas sensíveis QUANDO a escrita
-- vem de um usuário comum (role `authenticated`/`anon`). O backend
-- (`service_role`) e as funções SECURITY DEFINER (rodam como o dono, ex.:
-- `postgres`) passam livres — é por elas que fair_play_rating/abandoned_matches
-- legitimamente mudam. Assim o SettingsView.vue continua editando os campos
-- de perfil normais (full_name, username, ea_id, main_platform) sem quebrar.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Guardião das colunas sensíveis de profiles.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_guard_profile_sensitive_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- IMPORTANTE: esta função NÃO pode ser SECURITY DEFINER. Precisamos que
  -- current_user reflita QUEM está escrevendo. PostgREST faz SET ROLE a partir
  -- do JWT verificado: 'authenticated'/'anon' = escrita direta do client (o
  -- único vetor que não passa por regra de negócio); 'service_role' = backend;
  -- dentro de uma RPC SECURITY DEFINER vira o dono ('postgres'). Se esta função
  -- fosse SECURITY DEFINER, current_user viraria sempre 'postgres' e o guard
  -- NUNCA travaria o client — foi exatamente o bug do primeiro 34.
  IF current_user IN ('authenticated', 'anon') THEN
    IF NEW.is_admin              IS DISTINCT FROM OLD.is_admin
       OR NEW.fair_play_rating   IS DISTINCT FROM OLD.fair_play_rating
       OR NEW.abandoned_matches  IS DISTINCT FROM OLD.abandoned_matches
       OR NEW.abandonment_badge_public_at IS DISTINCT FROM OLD.abandonment_badge_public_at
       OR NEW.deletion_requested_at IS DISTINCT FROM OLD.deletion_requested_at
       OR NEW.anonymized_at      IS DISTINCT FROM OLD.anonymized_at
       OR NEW.deactivated_at     IS DISTINCT FROM OLD.deactivated_at
       OR NEW.id                 IS DISTINCT FROM OLD.id
       OR NEW.created_at         IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'FORBIDDEN_COLUMN: Você não pode alterar esse campo do perfil.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Amarra o trigger em profiles (idempotente).
-- ─────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_guard_profile_sensitive_columns ON public.profiles;
CREATE TRIGGER trg_guard_profile_sensitive_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_guard_profile_sensitive_columns();

-- ─────────────────────────────────────────────────────────────────────────
-- Nota: a policy de UPDATE em profiles continua existindo (o client PRECISA
-- poder editar apelido/EA ID/plataforma). O trigger é a camada que faltava —
-- restringe QUAIS colunas, algo que a policy sozinha não expressa.
-- ─────────────────────────────────────────────────────────────────────────
