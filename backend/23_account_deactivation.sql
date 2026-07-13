-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 22_account_deletion.sql).
--
-- Objetivo: "desativar" a conta — o irmão temporário e 100% reversível do
-- "excluir". Diferente da exclusão (22): NÃO tem carência de 30 dias, NÃO
-- anonimiza nada, NÃO bane o login. Só some da vitrine (desafios abertos
-- deixam de aparecer no lobby, perfil público mostra "conta desativada") e
-- volta ao normal assim que a pessoa loga de novo. É o "dar um tempo" —
-- guarda tudo intacto (saldo inclusive) pra quando quiser voltar.
--
-- Bloqueio: não desativa com partida 1v1 ou torneio pago em andamento
-- (termine antes). Saldo NÃO bloqueia — o dinheiro fica guardado, é reversível.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Estado de desativação. null = conta ativa; não-nulo = desativada (some
--    da vitrine, login reativa). Independente de deletion_requested_at (22).
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deactivated_at timestamptz;

COMMENT ON COLUMN public.profiles.deactivated_at IS
  'Quando o usuário desativou a conta temporariamente. Não-nulo = escondida da vitrine; login reativa (limpa o campo). Sem carência e sem anonimização — o irmão reversível de deletion_requested_at.';

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Desativar: valida os bloqueios e marca deactivated_at. Não move saldo,
--    não toca no auth.users (login reativa de propósito).
-- ─────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Reativar (logou de novo, ou clicou "reativar"). Idempotente.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_reactivate_account(
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
    RAISE EXCEPTION 'ALREADY_ANONYMIZED: Esta conta já foi excluída e não pode ser reativada.';
  END IF;

  UPDATE public.profiles
  SET deactivated_at = NULL, updated_at = now()
  WHERE id = p_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants — só o backend (service_role).
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_deactivate_account(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_reactivate_account(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_deactivate_account(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_reactivate_account(uuid) TO service_role;
