-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 17_challenge_and_wallet_notifications.sql).
--
-- Objetivo: decisões fechadas do modelo de receita.
--   1) Rake do desafio 1v1: 10% → 8% (torneio online mantém 10% — já estava
--      certo, overhead de organização/arbitragem justifica ficar mais alto
--      que a partida simples, não precisa mexer).
--   2) Valor mínimo de partida: R$ 1,00 (desafio 1v1 e torneio online) —
--      hoje não existia NENHUM mínimo real, só bloqueava valor negativo/zero.
--   3) Terminologia "aposta" → "valor da partida" nas mensagens de erro e
--      notificações que o usuário efetivamente vê (copy pura, não mexe em
--      nome de coluna/campo interno como bet_amount, que continua igual).
--
-- CREATE OR REPLACE é seguro de rodar em cima do 04/08/17 (mesmas
-- assinaturas de função, só corpo/valores mudam).

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Criar desafio: mesmo corpo do 04, com mínimo de R$ 1,00 e sem "aposta"
--    na mensagem de erro.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_create_challenge(
  p_creator_id uuid,
  p_bet_amount numeric,
  p_platform text,
  p_game text
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.wallets;
  v_challenge public.challenges;
BEGIN
  IF p_bet_amount < 1 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: O valor da partida precisa ser de pelo menos R$ 1,00.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_creator_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do criador não encontrada.';
  END IF;

  IF v_wallet.balance < p_bet_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para abrir este desafio.';
  END IF;

  UPDATE public.wallets
  SET balance = balance - p_bet_amount,
      locked_balance = locked_balance + p_bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  INSERT INTO public.challenges (creator_id, bet_amount, platform, game, status)
  VALUES (p_creator_id, p_bet_amount, p_platform, p_game, 'open')
  RETURNING * INTO v_challenge;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_freeze',
    -p_bet_amount,
    'completed',
    'Saldo congelado para desafio X1 (Sala: ' || substr(v_challenge.id::text, 1, 8) || ')'
  );

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Aceitar desafio: mesmo corpo do 17, sem "aposta" na mensagem de erro
--    nem na notificação.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_accept_challenge(
  p_challenge_id uuid,
  p_opponent_id uuid
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_wallet public.wallets;
  v_opponent_name text;
BEGIN
  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.status != 'open' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_OPEN: Este desafio não está mais aberto para aceitação.';
  END IF;

  IF v_challenge.creator_id = p_opponent_id THEN
    RAISE EXCEPTION 'SELF_ACCEPT: Você não pode aceitar seu próprio desafio.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_opponent_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do oponente não encontrada.';
  END IF;

  IF v_wallet.balance < v_challenge.bet_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para aceitar este valor.';
  END IF;

  UPDATE public.wallets
  SET balance = balance - v_challenge.bet_amount,
      locked_balance = locked_balance + v_challenge.bet_amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  UPDATE public.challenges
  SET opponent_id = p_opponent_id,
      status = 'in_progress',
      updated_at = now()
  WHERE id = p_challenge_id
  RETURNING * INTO v_challenge;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (
    v_wallet.id,
    'bet_freeze',
    -v_challenge.bet_amount,
    'completed',
    'Saldo congelado para desafio X1 (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'
  );

  SELECT username INTO v_opponent_name FROM public.profiles WHERE id = p_opponent_id;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (v_challenge.creator_id, 'challenge_accepted', 'Desafio aceito ⚔️',
    coalesce(v_opponent_name, 'Alguém') || ' topou o valor da sua partida de R$ ' || v_challenge.bet_amount || ' em ' || v_challenge.game || '. Combinem sala e horário no chat.',
    p_challenge_id);

  RETURN v_challenge;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Reportar resultado: mesmo corpo do 17, rake 10% → 8%.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_report_challenge_result(
  p_challenge_id uuid,
  p_user_id uuid,
  p_result text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge public.challenges;
  v_is_creator boolean;
  v_winner_id uuid;
  v_loser_id uuid;
  v_pending_user_id uuid;
  v_reporter_name text;
  v_bet_amount numeric;
  v_rake_percentage numeric := 0.08;
  v_prize_pool numeric;
  v_platform_fee numeric;
  v_winner_prize numeric;
  v_wallet_a public.wallets;
  v_wallet_b public.wallets;
  v_winner_wallet public.wallets;
  v_loser_wallet public.wallets;
BEGIN
  IF p_result NOT IN ('win', 'loss') THEN
    RAISE EXCEPTION 'INVALID_RESULT: Resultado inválido. Deve ser ''win'' ou ''loss''.';
  END IF;

  SELECT * INTO v_challenge
  FROM public.challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF v_challenge.status != 'in_progress' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_IN_PROGRESS: Este desafio não está em andamento.';
  END IF;

  v_is_creator := (v_challenge.creator_id = p_user_id);

  IF NOT v_is_creator AND v_challenge.opponent_id != p_user_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não faz parte deste desafio.';
  END IF;

  IF v_is_creator THEN
    IF v_challenge.creator_result IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado.';
    END IF;
    UPDATE public.challenges SET creator_result = p_result WHERE id = p_challenge_id
      RETURNING * INTO v_challenge;
  ELSE
    IF v_challenge.opponent_result IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado.';
    END IF;
    UPDATE public.challenges SET opponent_result = p_result WHERE id = p_challenge_id
      RETURNING * INTO v_challenge;
  END IF;

  IF v_challenge.creator_result IS NULL OR v_challenge.opponent_result IS NULL THEN
    -- Só um lado reportou até aqui: o outro lado é sempre quem ainda está
    -- NULL (o nosso já foi setado acima) — avisa ele que é a vez dele.
    v_pending_user_id := CASE WHEN v_challenge.creator_result IS NULL THEN v_challenge.creator_id ELSE v_challenge.opponent_id END;
    SELECT username INTO v_reporter_name FROM public.profiles WHERE id = p_user_id;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_pending_user_id, 'challenge_result_pending', 'Sua vez de reportar ⏳',
      coalesce(v_reporter_name, 'Seu adversário') || ' já reportou o resultado do desafio em ' || v_challenge.game || '. Confirma o que aconteceu pra liberar o pote.',
      p_challenge_id);

    RETURN jsonb_build_object('message', 'Resultado reportado. Aguardando oponente confirmar.', 'status', 'waiting');
  END IF;

  -- Consenso: um ganhou, o outro perdeu
  IF (v_challenge.creator_result = 'win' AND v_challenge.opponent_result = 'loss')
     OR (v_challenge.creator_result = 'loss' AND v_challenge.opponent_result = 'win') THEN

    IF v_challenge.creator_result = 'win' THEN
      v_winner_id := v_challenge.creator_id;
      v_loser_id := v_challenge.opponent_id;
    ELSE
      v_winner_id := v_challenge.opponent_id;
      v_loser_id := v_challenge.creator_id;
    END IF;

    v_bet_amount := v_challenge.bet_amount;
    v_prize_pool := v_bet_amount * 2;
    v_platform_fee := v_prize_pool * v_rake_percentage;
    v_winner_prize := v_prize_pool - v_platform_fee;

    -- Trava as duas carteiras em ordem determinística (evita deadlock)
    SELECT * INTO v_wallet_a FROM public.wallets
      WHERE user_id = LEAST(v_winner_id, v_loser_id) FOR UPDATE;
    SELECT * INTO v_wallet_b FROM public.wallets
      WHERE user_id = GREATEST(v_winner_id, v_loser_id) FOR UPDATE;

    IF v_wallet_a IS NULL OR v_wallet_b IS NULL THEN
      RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira de um dos participantes não encontrada.';
    END IF;

    IF v_wallet_a.user_id = v_winner_id THEN
      v_winner_wallet := v_wallet_a;
      v_loser_wallet := v_wallet_b;
    ELSE
      v_winner_wallet := v_wallet_b;
      v_loser_wallet := v_wallet_a;
    END IF;

    UPDATE public.wallets
    SET balance = balance + v_winner_prize,
        locked_balance = locked_balance - v_bet_amount,
        updated_at = now()
    WHERE id = v_winner_wallet.id;

    UPDATE public.wallets
    SET locked_balance = locked_balance - v_bet_amount,
        updated_at = now()
    WHERE id = v_loser_wallet.id;

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES
      (v_winner_wallet.id, 'challenge_win', v_winner_prize, 'completed',
       'Vitória no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'),
      (v_loser_wallet.id, 'challenge_loss', -v_bet_amount, 'completed',
       'Derrota no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')');

    UPDATE public.challenges
    SET status = 'completed',
        winner_id = v_winner_id,
        rake_amount = v_platform_fee,
        updated_at = now()
    WHERE id = p_challenge_id;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_winner_id, 'challenge_win', 'Você venceu 🏆',
      'Vitória confirmada no desafio de ' || v_challenge.game || '. R$ ' || v_winner_prize || ' caíram na sua carteira.',
      p_challenge_id);

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_loser_id, 'challenge_loss', 'Resultado confirmado',
      'Derrota confirmada no desafio de ' || v_challenge.game || '. R$ ' || v_bet_amount || ' saíram da sua carteira.',
      p_challenge_id);

    RETURN jsonb_build_object(
      'message', 'Resultado confirmado com consenso.',
      'status', 'completed',
      'winner_id', v_winner_id
    );
  ELSE
    -- Divergência: ambos "win" ou ambos "loss"
    UPDATE public.challenges SET status = 'disputed', updated_at = now() WHERE id = p_challenge_id;

    INSERT INTO public.disputes (challenge_id, status) VALUES (p_challenge_id, 'open');

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'challenge_disputed', 'Resultado em disputa ⚠️',
      'Os resultados do desafio de ' || v_challenge.game || ' bateram de frente e foram pra mediação da ArenaX1.',
      p_challenge_id
    FROM (VALUES (v_challenge.creator_id), (v_challenge.opponent_id)) AS t(uid);

    RETURN jsonb_build_object(
      'message', 'Divergência de resultados. Partida em disputa.',
      'status', 'disputed'
    );
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Criar torneio online: mesmo corpo do 08, com mínimo de R$ 1,00 na taxa
--    de inscrição (rake do torneio segue 10%, sem mudança — fica no cálculo
--    de fn_submit_online_match_result / fn_resolve_online_match_dispute).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_create_online_tournament(
  p_host_id uuid,
  p_title text,
  p_game text,
  p_platform text,
  p_max_players int,
  p_entry_fee numeric,
  p_registration_deadline timestamptz
) RETURNS public.tournaments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_wallet public.wallets;
  v_username text;
BEGIN
  IF p_max_players NOT IN (4, 8, 16) THEN
    RAISE EXCEPTION 'INVALID_PLAYER_COUNT: O torneio precisa ter 4, 8 ou 16 jogadores.';
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION 'INVALID_TITLE: Informe um nome para o torneio.';
  END IF;

  IF p_entry_fee IS NULL OR p_entry_fee < 1 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: A taxa de inscrição precisa ser de pelo menos R$ 1,00.';
  END IF;

  IF p_registration_deadline IS NULL OR p_registration_deadline <= now() THEN
    RAISE EXCEPTION 'INVALID_DEADLINE: O prazo de inscrição precisa ser no futuro.';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_host_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira do anfitrião não encontrada.';
  END IF;
  IF v_wallet.balance < p_entry_fee THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para pagar a própria inscrição.';
  END IF;

  SELECT username INTO v_username FROM public.profiles WHERE id = p_host_id;

  INSERT INTO public.tournaments (
    host_id, title, game, platform, type, max_players, entry_fee, prize_pool,
    registration_deadline, status
  ) VALUES (
    p_host_id, trim(p_title), p_game, p_platform, 'online_paid', p_max_players, p_entry_fee, p_entry_fee,
    p_registration_deadline, 'registration_open'
  ) RETURNING * INTO v_tournament;

  UPDATE public.wallets
  SET balance = balance - p_entry_fee,
      locked_balance = locked_balance + p_entry_fee,
      updated_at = now()
  WHERE id = v_wallet.id;

  INSERT INTO public.tournament_participants (tournament_id, user_id, display_name)
  VALUES (v_tournament.id, p_host_id, v_username);

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (v_wallet.id, 'bet_freeze', -p_entry_fee, 'completed',
    'Inscrição no torneio "' || v_tournament.title || '" (anfitrião)');

  -- Avisa todo mundo (menos o próprio anfitrião) que uma arena nova abriu.
  INSERT INTO public.notifications (user_id, type, title, body, tournament_id)
  SELECT p.id, 'tournament_open',
    'Torneio aberto na área 🔥',
    coalesce(v_username, 'Alguém') || ' abriu "' || v_tournament.title || '" — R$ ' || p_entry_fee ||
      ' pra entrar, ' || p_max_players || ' vagas em ' || p_game || '. Quem não se inscrever fica só assistindo.',
    v_tournament.id
  FROM public.profiles p
  WHERE p.id != p_host_id;

  RETURN v_tournament;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants (defensivo — mesmas assinaturas, já concedidas, reafirmando pra
-- rodar este arquivo isoladamente sem depender de ordem).
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_create_challenge(uuid, numeric, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_accept_challenge(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_create_online_tournament(uuid, text, text, text, int, numeric, timestamptz) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_create_challenge(uuid, numeric, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_accept_challenge(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_create_online_tournament(uuid, text, text, text, int, numeric, timestamptz) TO service_role;
