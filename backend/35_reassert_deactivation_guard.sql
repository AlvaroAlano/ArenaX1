-- Execute este script no SQL Editor do seu painel Supabase (depois do 34).
--
-- Objetivo: fechar o ACHADO-03 do teste geral — desativar a conta NÃO estava
-- bloqueando com desafio em andamento, apesar de fn_deactivate_account (arquivo
-- 23) ter a checagem. No teste, uma conta com desafio em status 'accepted'
-- (saldo travado dos dois lados) conseguiu desativar com 200, sem erro — sinal
-- de que a versão rodando no banco é anterior à do arquivo 23 (padrão
-- "migração fantasma": o arquivo existe no repo, mas o banco roda outra versão).
--
-- Aqui só re-afirmamos a definição correta e atual de fn_deactivate_account
-- (idêntica à do 23). CREATE OR REPLACE é idempotente — rodar de novo não causa
-- efeito colateral se a versão já estiver certa.

CREATE OR REPLACE FUNCTION public.fn_deactivate_account(
  p_user_id uuid
) RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND: Perfil não encontrado.';
  END IF;

  IF v_profile.anonymized_at IS NOT NULL THEN
    RAISE EXCEPTION 'ALREADY_ANONYMIZED: Esta conta já foi excluída.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.challenges
    WHERE status IN ('accepted', 'in_progress') AND (creator_id = p_user_id OR opponent_id = p_user_id)
  ) THEN
    RAISE EXCEPTION 'ACTIVE_MATCH: Você tem desafios em andamento. Finalize-os antes de desativar a conta.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tournament_participants tp
    JOIN public.tournaments t ON t.id = tp.tournament_id
    WHERE tp.user_id = p_user_id
      AND t.type = 'online_paid'
      AND t.status IN ('registration_open', 'in_progress')
  ) THEN
    RAISE EXCEPTION 'ACTIVE_TOURNAMENT: Você está inscrito num torneio pago que ainda não terminou. Aguarde ele encerrar antes de desativar a conta.';
  END IF;

  UPDATE public.profiles
  SET deactivated_at = now(), updated_at = now()
  WHERE id = p_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_deactivate_account(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_deactivate_account(uuid) TO service_role;
