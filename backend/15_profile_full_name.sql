-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Objetivo: separar "nome completo" de "apelido". Até aqui só existia
-- profiles.username, preenchido no cadastro com o nome completo digitado
-- e usado ao mesmo tempo como identidade pública (mostrado em todo card
-- de desafio, ranking etc.). full_name passa a guardar o nome completo;
-- username continua sendo o apelido público, único, exibido em todo canto
-- (nenhuma tela que já lê creator_profile.username precisa mudar).

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS full_name text;

COMMENT ON COLUMN public.profiles.full_name IS
  'Nome completo (privado-ish, mostrado no perfil próprio e no perfil público). Distinto de username, que é o apelido exibido em cards/ranking.';

-- O trigger de criação de conta (schema.sql) só gravava username. Redefinido
-- aqui (CREATE OR REPLACE mantém o mesmo trigger já existente, só troca o
-- corpo da função) pra também gravar full_name vindo do cadastro.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, created_at, updated_at)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'player_' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'full_name',
    now(),
    now()
  );

  INSERT INTO public.wallets (user_id, balance, locked_balance, updated_at)
  VALUES (new.id, 0.00, 0.00, now());

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
