-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 21_profile_main_platform.sql).
--
-- Objetivo: exclusão de conta por ANONIMIZAÇÃO, nunca hard-delete. A linha em
-- profiles/wallets precisa sobreviver pra sempre como âncora de FK — desafios,
-- disputas e torneios que envolveram OUTRAS pessoas referenciam esse id, e uma
-- disputa em análise ainda pode creditar saldo nessa carteira depois. Por isso:
--
--   * Excluir = trocar os dados pessoais (apelido, nome, IDs de jogo) por um
--     identificador anônimo e desativar o login no auth.users (isso é feito no
--     backend, account.py — SQL não alcança auth.users; e um DELETE lá cascatearia
--     e apagaria o profile, quebrando tudo acima).
--   * Janela de carência de 30 dias: o pedido só marca deletion_requested_at.
--     A anonimização definitiva roda depois, num job (ver account.py
--     /finalize-due-deletions). Logar de novo dentro da janela cancela o pedido.
--   * O apelido original fica reservado pra sempre (a linha nunca some, então o
--     UNIQUE de username segue valendo — ninguém reusa o nome de um jogador antigo).
--
-- Decisão de escopo deste passo (revisável): pedir exclusão é BLOQUEADO enquanto
-- houver saldo livre > 0 (saque antes) ou partida/torneio pago em andamento
-- (termine antes). Assim nenhum dinheiro se move no pedido e a carência de 30
-- dias é 100% reversível. O W.O. automático de partida ativa (que moveria saldo
-- pro adversário na hora) foi deixado de fora de propósito: ele conflita com a
-- reversibilidade da carência e depende do mecanismo compartilhado de "jogador
-- ausente" (ghosting/desconexão), que é uma feature própria.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Estado de exclusão no profile. Duas datas, nenhuma trigger:
--    deletion_requested_at  = pedido feito, contando a carência (null = conta ativa)
--    anonymized_at          = anonimização definitiva já aplicada (null = ainda não)
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deletion_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS anonymized_at timestamptz;

COMMENT ON COLUMN public.profiles.deletion_requested_at IS
  'Quando o usuário pediu exclusão. Enquanto não-nulo e anonymized_at nulo, a conta está na carência de 30 dias (login cancela). Ver backend/account.py.';
COMMENT ON COLUMN public.profiles.anonymized_at IS
  'Quando os dados pessoais foram efetivamente anonimizados. Não-nulo = conta excluída em definitivo (login já bloqueado no auth.users).';

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Pedir exclusão: valida os bloqueios e marca a carência. Não move saldo,
--    não toca no auth.users (login segue funcionando de propósito — é o que
--    permite cancelar logando de novo).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_request_account_deletion(
  p_user_id uuid
) RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles;
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND: Perfil não encontrado.';
  END IF;

  IF v_profile.anonymized_at IS NOT NULL THEN
    RAISE EXCEPTION 'ALREADY_ANONYMIZED: Esta conta já foi excluída.';
  END IF;

  -- Saldo livre precisa estar zerado — nunca há confisco, o usuário saca antes.
  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF FOUND AND v_wallet.balance > 0 THEN
    RAISE EXCEPTION 'BALANCE_NOT_EMPTY: Você ainda tem R$ % em saldo livre. Saque tudo antes de excluir a conta.', to_char(v_wallet.balance, 'FM999999990.00');
  END IF;

  -- Partida 1v1 viva (aceita, aguardando presença, ou em andamento) trava o
  -- pedido — tem saldo travado dos dois lados. Não fica presa pra sempre: o
  -- job de timeout (24_match_absent_player.sql) resolve toda partida parada
  -- (reembolsa ou manda pra disputa), então o bloqueio sempre destrava.
  IF EXISTS (
    SELECT 1 FROM public.challenges
    WHERE status IN ('accepted', 'in_progress') AND (creator_id = p_user_id OR opponent_id = p_user_id)
  ) THEN
    RAISE EXCEPTION 'ACTIVE_MATCH: Você tem desafios em andamento. Finalize-os antes de excluir a conta.';
  END IF;

  -- Inscrição viva em torneio pago (saldo travado na inscrição) trava o pedido.
  IF EXISTS (
    SELECT 1 FROM public.tournament_participants tp
    JOIN public.tournaments t ON t.id = tp.tournament_id
    WHERE tp.user_id = p_user_id
      AND t.type = 'online_paid'
      AND t.status IN ('registration_open', 'in_progress')
  ) THEN
    RAISE EXCEPTION 'ACTIVE_TOURNAMENT: Você está inscrito num torneio pago que ainda não terminou. Aguarde ele encerrar antes de excluir a conta.';
  END IF;

  UPDATE public.profiles
  SET deletion_requested_at = now(), updated_at = now()
  WHERE id = p_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Cancelar o pedido (logou de novo dentro da carência). Idempotente: se a
--    conta não estava com pedido aberto, só devolve a linha sem erro.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cancel_account_deletion(
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
    RAISE EXCEPTION 'ALREADY_ANONYMIZED: Esta conta já foi excluída e não pode ser restaurada.';
  END IF;

  UPDATE public.profiles
  SET deletion_requested_at = NULL, updated_at = now()
  WHERE id = p_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Anonimização definitiva de UMA conta. Chamada pelo job de finalização
--    (account.py), depois de já ter banido o login no auth.users. Idempotente.
--    Reconfere saldo zerado como defesa em profundidade — o profile só é
--    anonimizado se a carteira estiver realmente sem saldo livre, mesmo que o
--    deletion_requested_at tenha sido setado por outro caminho.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_anonymize_profile(
  p_user_id uuid
) RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles;
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND: Perfil não encontrado.';
  END IF;

  -- Já anonimizado: não faz nada, devolve como está (job pode reprocessar sem dano).
  IF v_profile.anonymized_at IS NOT NULL THEN
    RETURN v_profile;
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF FOUND AND v_wallet.balance > 0 THEN
    RAISE EXCEPTION 'BALANCE_NOT_EMPTY: Conta com saldo livre não pode ser anonimizada — saldo precisa ser sacado/resolvido antes.';
  END IF;

  -- Substitui todo dado pessoal por um identificador anônimo derivado do próprio
  -- id (estável, e único o bastante pra não colidir no UNIQUE de username em
  -- qualquer escala realista). fair_play_rating e created_at ficam — o histórico
  -- de partidas continua coerente, só sem nome. is_admin zerado por segurança.
  UPDATE public.profiles
  SET username = 'Usuário Excluído #' || substr(replace(id::text, '-', ''), 1, 8),
      full_name = NULL,
      ea_id = NULL,
      psn_id = NULL,
      xbox_id = NULL,
      steam_id = NULL,
      main_platform = NULL,
      is_admin = false,
      anonymized_at = now(),
      deletion_requested_at = COALESCE(deletion_requested_at, now()),
      updated_at = now()
  WHERE id = p_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants — só o backend (service_role) chama estas funções.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_request_account_deletion(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_cancel_account_deletion(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_anonymize_profile(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_request_account_deletion(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_cancel_account_deletion(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_anonymize_profile(uuid) TO service_role;
