-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Objetivo: permitir que o criador de um desafio ainda ABERTO (sem
-- oponente) cancele e receba o valor de volta, seguindo o mesmo padrão
-- atômico de 04_atomic_wallet_functions.sql (linha travada com FOR UPDATE
-- durante toda a operação). Só existe cancelamento, não edição — editar um
-- desafio aberto criaria uma corrida real contra outro jogador aceitando
-- o valor antigo no mesmo instante.

-- ─────────────────────────────────────────────────────────────────────────
-- Cancelar desafio: só o criador, só enquanto 'open' (sem oponente ainda).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cancel_challenge(
  p_challenge_id uuid,
  p_user_id uuid
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.creator_id != p_user_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não pode cancelar um desafio que não é seu.';
  END IF;

  IF v_challenge.status != 'open' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_OPEN: Só é possível cancelar desafios ainda abertos, sem oponente.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do criador não encontrada.';
  END IF;

  UPDATE public.wallets
  SET balance = balance + v_challenge.bet_amount,
      locked_balance = locked_balance - v_challenge.bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  UPDATE public.challenges
  SET status = 'cancelled',
      updated_at = now()
  WHERE id = p_challenge_id
  RETURNING * INTO v_challenge;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_refund',
    v_challenge.bet_amount,
    'completed',
    'Desafio cancelado, saldo devolvido (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'
  );

  RETURN v_challenge;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_cancel_challenge(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_cancel_challenge(uuid, uuid) TO service_role;
