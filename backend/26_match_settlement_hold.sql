-- Execute no SQL Editor do Supabase (depois de 24; o 25 é independente).
--
-- Camada de LIQUIDAÇÃO do desafio 1v1, com a decisão fechada com o usuário:
--
--   * Timeout de resultado (um lado reportou, o outro silenciou 24h) →
--     ACEITA AUTOMÁTICO o resultado de quem reportou, MAS RETÉM o prêmio por
--     3 dias (não-sacável). Nesse prazo o lesado pode CONTESTAR (disputa
--     reativa) → admin reverte, porque o dinheiro ainda está retido. Passou o
--     prazo sem contestação → libera pro saque. Isso tira a fila de admin do
--     caso comum (perdedor não liga) sem deixar ninguém lesado sem recurso.
--   * 0 reportes no timeout → não há o que aceitar: anula e devolve os dois.
--   * Punição de quem some/abandona é SÓ reputacional (contador no perfil),
--     NUNCA financeira — dinheiro só se move como resultado legítimo da aposta.
--
-- Também preenche um buraco antigo: disputa de desafio 1v1 não tinha função de
-- resolução (só torneio tinha, no 09). fn_resolve_challenge_dispute resolve
-- tanto a divergência quanto a contestação reativa, normalizando o dinheiro.
--
-- Rake mantido em 8% (igual 18). fn_report_challenge_result é redefinido aqui
-- na sua forma final (o 24 de propósito não mexe nela, pra não regredir o 18).

-- ─────────────────────────────────────────────────────────────────────────
-- 0) Colunas novas: retenção do prêmio + contador de abandono.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS settlement_release_at timestamptz;

COMMENT ON COLUMN public.challenges.settlement_release_at IS
  'Só em completed por aceite automático: quando o prêmio retido libera pro saque. Não-nulo = pote consolidado (2x aposta) travado no winner_id, ainda contestável. NULL = liquidação normal/imediata.';

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS abandoned_matches int not null default 0;

COMMENT ON COLUMN public.profiles.abandoned_matches IS
  'Contador de partidas abandonadas/no-show (punição reputacional, não-financeira). Alimenta o selo de alerta no perfil. NÃO mexe no fair_play_rating (que só cai por má conduta real).';

-- ─────────────────────────────────────────────────────────────────────────
-- 1) fn_settle_challenge — matemática de pagamento única, reusada por
--    consenso, aceite-automático e resolução de disputa. Assume que o desafio
--    tem os dois lados com a aposta travada (2x aposta no locked total) e que
--    o caller já validou permissão/estado.
--      p_hold = false → paga na hora (winner.balance += prêmio), rake retido.
--      p_hold = true  → consolida o pote no winner (locked) e agenda liberação
--                       em 3 dias; rake só é cobrado no release. Sem notificar
--                       aqui — quem chama manda a notificação do seu contexto.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_settle_challenge(
  p_challenge_id uuid,
  p_winner_id uuid,
  p_hold boolean
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ch public.challenges;
  v_loser_id uuid;
  v_bet numeric;
  v_rake numeric;
  v_prize numeric;
  v_wa public.wallets;
  v_wb public.wallets;
  v_winner_wallet public.wallets;
  v_loser_wallet public.wallets;
  c_rake_pct constant numeric := 0.08;
BEGIN
  SELECT * INTO v_ch FROM public.challenges WHERE id = p_challenge_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  v_loser_id := CASE WHEN p_winner_id = v_ch.creator_id THEN v_ch.opponent_id ELSE v_ch.creator_id END;
  v_bet := v_ch.bet_amount;
  v_rake := round(v_bet * 2 * c_rake_pct, 2);
  v_prize := v_bet * 2 - v_rake;

  SELECT * INTO v_wa FROM public.wallets WHERE user_id = LEAST(p_winner_id, v_loser_id) FOR UPDATE;
  SELECT * INTO v_wb FROM public.wallets WHERE user_id = GREATEST(p_winner_id, v_loser_id) FOR UPDATE;
  IF v_wa.user_id = p_winner_id THEN
    v_winner_wallet := v_wa; v_loser_wallet := v_wb;
  ELSE
    v_winner_wallet := v_wb; v_loser_wallet := v_wa;
  END IF;

  IF p_hold THEN
    -- Perdedor perde a aposta (sai do locked); vencedor fica com o pote inteiro
    -- retido no locked (a própria aposta + a do perdedor). Rake só no release.
    UPDATE public.wallets SET locked_balance = locked_balance + v_bet, updated_at = now()
      WHERE id = v_winner_wallet.id;
    UPDATE public.wallets SET locked_balance = locked_balance - v_bet, updated_at = now()
      WHERE id = v_loser_wallet.id;

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_loser_wallet.id, 'challenge_loss', -v_bet, 'completed',
      'Derrota no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')');

    UPDATE public.challenges
    SET status = 'completed', winner_id = p_winner_id,
        report_deadline = NULL, rake_amount = 0,
        settlement_release_at = now() + interval '3 days', updated_at = now()
    WHERE id = p_challenge_id
    RETURNING * INTO v_ch;
  ELSE
    -- Pagamento imediato: prêmio pro vencedor, aposta some do perdedor.
    UPDATE public.wallets
    SET balance = balance + v_prize, locked_balance = locked_balance - v_bet, updated_at = now()
    WHERE id = v_winner_wallet.id;
    UPDATE public.wallets SET locked_balance = locked_balance - v_bet, updated_at = now()
      WHERE id = v_loser_wallet.id;

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES
      (v_winner_wallet.id, 'challenge_win', v_prize, 'completed',
       'Vitória no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')'),
      (v_loser_wallet.id, 'challenge_loss', -v_bet, 'completed',
       'Derrota no desafio (Sala: ' || substr(p_challenge_id::text, 1, 8) || ')');

    UPDATE public.challenges
    SET status = 'completed', winner_id = p_winner_id,
        report_deadline = NULL, rake_amount = v_rake,
        settlement_release_at = NULL, updated_at = now()
    WHERE id = p_challenge_id
    RETURNING * INTO v_ch;
  END IF;

  RETURN v_ch;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) fn_report_challenge_result FINAL: base do 18 (rake 8% + notificações de
--    vitória/derrota), + reset do prazo no primeiro reporte (item 1), + o
--    consenso agora paga via fn_settle_challenge.
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
  v_prize numeric;
BEGIN
  IF p_result NOT IN ('win', 'loss') THEN
    RAISE EXCEPTION 'INVALID_RESULT: Resultado inválido. Deve ser ''win'' ou ''loss''.';
  END IF;

  SELECT * INTO v_challenge FROM public.challenges WHERE id = p_challenge_id FOR UPDATE;
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
    UPDATE public.challenges SET creator_result = p_result WHERE id = p_challenge_id RETURNING * INTO v_challenge;
  ELSE
    IF v_challenge.opponent_result IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado.';
    END IF;
    UPDATE public.challenges SET opponent_result = p_result WHERE id = p_challenge_id RETURNING * INTO v_challenge;
  END IF;

  IF v_challenge.creator_result IS NULL OR v_challenge.opponent_result IS NULL THEN
    -- Primeiro a reportar: prazo de 24h conta a partir de AGORA (não do início
    -- da partida) — quem foi avisado sempre tem 24h cheias. O job de timeout
    -- usa esse mesmo campo pra aceitar automático se ninguém confirmar.
    UPDATE public.challenges SET report_deadline = now() + interval '24 hours', updated_at = now()
    WHERE id = p_challenge_id;

    v_pending_user_id := CASE WHEN v_challenge.creator_result IS NULL THEN v_challenge.creator_id ELSE v_challenge.opponent_id END;
    SELECT username INTO v_reporter_name FROM public.profiles WHERE id = p_user_id;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_pending_user_id, 'challenge_result_pending', 'Sua vez de reportar ⏳',
      coalesce(v_reporter_name, 'Seu adversário') || ' já reportou o resultado do desafio em ' || v_challenge.game ||
      '. Você tem 24h pra confirmar — passando o prazo sem resposta, o resultado dele é aceito (e você ainda pode contestar depois). Toque pra reportar.',
      p_challenge_id);

    RETURN jsonb_build_object('message', 'Resultado reportado. Aguardando oponente confirmar.', 'status', 'waiting');
  END IF;

  -- Consenso: um ganhou, o outro perdeu
  IF (v_challenge.creator_result = 'win' AND v_challenge.opponent_result = 'loss')
     OR (v_challenge.creator_result = 'loss' AND v_challenge.opponent_result = 'win') THEN

    IF v_challenge.creator_result = 'win' THEN
      v_winner_id := v_challenge.creator_id; v_loser_id := v_challenge.opponent_id;
    ELSE
      v_winner_id := v_challenge.opponent_id; v_loser_id := v_challenge.creator_id;
    END IF;

    v_challenge := public.fn_settle_challenge(p_challenge_id, v_winner_id, false);
    v_prize := v_challenge.bet_amount * 2 - v_challenge.rake_amount;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_winner_id, 'challenge_win', 'Você venceu 🏆',
      'Vitória confirmada pelos dois no desafio de ' || v_challenge.game || '! R$ ' || v_prize || ' já caíram na sua carteira.',
      p_challenge_id);
    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_loser_id, 'challenge_loss', 'Resultado confirmado',
      'Derrota confirmada no desafio de ' || v_challenge.game || '. R$ ' || v_challenge.bet_amount || ' saíram da sua carteira.',
      p_challenge_id);

    RETURN jsonb_build_object('message', 'Resultado confirmado com consenso.', 'status', 'completed', 'winner_id', v_winner_id);
  ELSE
    -- Divergência: ambos "win" ou ambos "loss" → mediação (dinheiro fica travado).
    UPDATE public.challenges SET status = 'disputed', report_deadline = NULL, updated_at = now() WHERE id = p_challenge_id;
    INSERT INTO public.disputes (challenge_id, status) VALUES (p_challenge_id, 'open') ON CONFLICT (challenge_id) DO NOTHING;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'challenge_disputed', 'Resultado em disputa ⚠️',
      'Os resultados do desafio de ' || v_challenge.game || ' bateram de frente e foram pra mediação da ArenaX1.',
      p_challenge_id
    FROM (VALUES (v_challenge.creator_id), (v_challenge.opponent_id)) AS t(uid);

    RETURN jsonb_build_object('message', 'Divergência de resultados. Partida em disputa.', 'status', 'disputed');
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Job de timeout FINAL (redefine o do 24). Dois casos de prazo estourado:
--    A) 'accepted' expirado (ninguém confirmou presença) → devolve os dois +
--       contador de abandono em quem não confirmou.
--    B) 'in_progress' expirado → 1 reporte: aceita-automático COM retenção;
--       0 reportes: anula e devolve os dois (não há resultado pra aceitar).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_process_match_timeouts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_ch public.challenges;
  v_winner_id uuid;
  v_loser_id uuid;
  v_winner_name text;
  v_loser_name text;
  v_release_label text;
  v_prize numeric;
  v_cancelled int := 0;
  v_auto int := 0;
  v_voided int := 0;
BEGIN
  -- A) accepted expirado → devolve os dois + marca abandono
  FOR v_row IN
    SELECT id FROM public.challenges
    WHERE status = 'accepted' AND start_deadline IS NOT NULL AND start_deadline < now()
  LOOP
    SELECT * INTO v_ch FROM public.challenges WHERE id = v_row.id FOR UPDATE;
    CONTINUE WHEN v_ch.status != 'accepted' OR v_ch.start_deadline >= now();

    UPDATE public.wallets
    SET balance = balance + v_ch.bet_amount, locked_balance = locked_balance - v_ch.bet_amount, updated_at = now()
    WHERE user_id IN (v_ch.creator_id, v_ch.opponent_id);

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    SELECT w.id, 'bet_refund', v_ch.bet_amount, 'completed',
      'Partida cancelada por falta de confirmação, saldo devolvido (Sala: ' || substr(v_ch.id::text, 1, 8) || ')'
    FROM public.wallets w WHERE w.user_id IN (v_ch.creator_id, v_ch.opponent_id);

    UPDATE public.challenges SET status = 'cancelled', start_deadline = NULL, updated_at = now() WHERE id = v_ch.id;

    -- Punição reputacional (não-financeira) em quem não confirmou presença.
    IF NOT v_ch.creator_ready THEN
      UPDATE public.profiles SET abandoned_matches = abandoned_matches + 1 WHERE id = v_ch.creator_id;
    END IF;
    IF NOT v_ch.opponent_ready THEN
      UPDATE public.profiles SET abandoned_matches = abandoned_matches + 1 WHERE id = v_ch.opponent_id;
    END IF;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    SELECT uid, 'challenge_expired', 'Partida cancelada ⏱️',
      'Ninguém confirmou presença a tempo no desafio de ' || v_ch.game || '. A partida foi cancelada e seu saldo devolvido.',
      v_ch.id
    FROM (VALUES (v_ch.creator_id), (v_ch.opponent_id)) AS t(uid);

    v_cancelled := v_cancelled + 1;
  END LOOP;

  -- B) in_progress expirado
  FOR v_row IN
    SELECT id FROM public.challenges
    WHERE status = 'in_progress' AND report_deadline IS NOT NULL AND report_deadline < now()
  LOOP
    SELECT * INTO v_ch FROM public.challenges WHERE id = v_row.id FOR UPDATE;
    CONTINUE WHEN v_ch.status != 'in_progress' OR v_ch.report_deadline >= now();

    IF v_ch.creator_result IS NOT NULL AND v_ch.opponent_result IS NULL THEN
      v_winner_id := CASE WHEN v_ch.creator_result = 'win' THEN v_ch.creator_id ELSE v_ch.opponent_id END;
    ELSIF v_ch.opponent_result IS NOT NULL AND v_ch.creator_result IS NULL THEN
      v_winner_id := CASE WHEN v_ch.opponent_result = 'win' THEN v_ch.opponent_id ELSE v_ch.creator_id END;
    ELSE
      v_winner_id := NULL; -- 0 reportes
    END IF;

    IF v_winner_id IS NOT NULL THEN
      -- Aceita-automático COM retenção de 3 dias.
      v_loser_id := CASE WHEN v_winner_id = v_ch.creator_id THEN v_ch.opponent_id ELSE v_ch.creator_id END;
      SELECT username INTO v_winner_name FROM public.profiles WHERE id = v_winner_id;
      SELECT username INTO v_loser_name FROM public.profiles WHERE id = v_loser_id;
      v_release_label := to_char(now() + interval '3 days', 'DD/MM');

      v_ch := public.fn_settle_challenge(v_ch.id, v_winner_id, true);
      v_prize := v_ch.bet_amount * 2 - round(v_ch.bet_amount * 2 * 0.08, 2);

      -- Pro vencedor: a mensagem NOMEIA a causa (o outro não confirmou) e deixa
      -- explícito que a retenção é a exceção, não a regra — senão o jogador
      -- generaliza "toda vitória demora 3 dias".
      INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
      VALUES (v_winner_id, 'challenge_win', 'Você venceu 🏆',
        'Como ' || coalesce(v_loser_name, 'o adversário') || ' não confirmou o resultado no prazo, o prêmio de R$ ' || v_prize ||
        ' fica reservado por 3 dias antes de liberar pra saque — isso só acontece quando falta a confirmação do oponente, não quando os dois confirmam na hora. Libera em ' || v_release_label || '.',
        v_ch.id);

      -- Pro lado silencioso: precisa saber que TEM prazo pra contestar, senão o
      -- recurso existe só na teoria (o "furo do ponto 6").
      INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
      VALUES (v_loser_id, 'challenge_loss', 'Resultado registrado como derrota',
        coalesce(v_winner_name, 'Seu adversário') || ' reportou vitória no desafio de ' || v_ch.game ||
        ' e o prazo pra você confirmar venceu, então o resultado foi aceito. Discorda? Você pode contestar até ' || v_release_label || '.',
        v_ch.id);

      v_auto := v_auto + 1;
    ELSE
      -- 0 reportes: anula e devolve os dois.
      UPDATE public.wallets
      SET balance = balance + v_ch.bet_amount, locked_balance = locked_balance - v_ch.bet_amount, updated_at = now()
      WHERE user_id IN (v_ch.creator_id, v_ch.opponent_id);

      INSERT INTO public.transactions (wallet_id, type, amount, status, description)
      SELECT w.id, 'bet_refund', v_ch.bet_amount, 'completed',
        'Partida sem resultado reportado, saldo devolvido (Sala: ' || substr(v_ch.id::text, 1, 8) || ')'
      FROM public.wallets w WHERE w.user_id IN (v_ch.creator_id, v_ch.opponent_id);

      UPDATE public.challenges SET status = 'cancelled', report_deadline = NULL, updated_at = now() WHERE id = v_ch.id;

      INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
      SELECT uid, 'challenge_expired', 'Partida sem resultado ⏱️',
        'Ninguém reportou o resultado do desafio de ' || v_ch.game || ' no prazo. A partida foi anulada e seu saldo devolvido.',
        v_ch.id
      FROM (VALUES (v_ch.creator_id), (v_ch.opponent_id)) AS t(uid);

      v_voided := v_voided + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('cancelled', v_cancelled, 'auto_settled', v_auto, 'voided', v_voided);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Liberar prêmios retidos cuja janela de contestação já passou (puro SQL,
--    agendável por pg_cron). Só toca em completed ainda retido (disputa
--    reativa muda pra 'disputed' e some daqui).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_release_due_settlements()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_ch public.challenges;
  v_rake numeric;
  v_prize numeric;
  v_released int := 0;
BEGIN
  FOR v_row IN
    SELECT id FROM public.challenges
    WHERE status = 'completed' AND settlement_release_at IS NOT NULL AND settlement_release_at <= now()
  LOOP
    SELECT * INTO v_ch FROM public.challenges WHERE id = v_row.id FOR UPDATE;
    CONTINUE WHEN v_ch.status != 'completed' OR v_ch.settlement_release_at IS NULL OR v_ch.settlement_release_at > now();

    v_rake := round(v_ch.bet_amount * 2 * 0.08, 2);
    v_prize := v_ch.bet_amount * 2 - v_rake;

    -- O vencedor tinha o pote inteiro (2x aposta) retido no locked; agora vira
    -- saldo livre menos o rake (cobrado só aqui).
    UPDATE public.wallets
    SET locked_balance = locked_balance - v_ch.bet_amount * 2,
        balance = balance + v_prize, updated_at = now()
    WHERE user_id = v_ch.winner_id;

    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    SELECT w.id, 'challenge_win', v_prize, 'completed',
      'Prêmio liberado após a janela de contestação (Sala: ' || substr(v_ch.id::text, 1, 8) || ')'
    FROM public.wallets w WHERE w.user_id = v_ch.winner_id;

    UPDATE public.challenges SET settlement_release_at = NULL, rake_amount = v_rake, updated_at = now() WHERE id = v_ch.id;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_ch.winner_id, 'challenge_win', 'Prêmio liberado 💰',
      'O prêmio de R$ ' || v_prize || ' do desafio de ' || v_ch.game || ' foi liberado na sua carteira.',
      v_ch.id);

    v_released := v_released + 1;
  END LOOP;

  RETURN jsonb_build_object('released', v_released);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 5) Abrir disputa de desafio 1v1 — usada por: (a) contestação reativa de um
--    resultado aceito automático (dentro da janela de 3 dias), e (b) reporte
--    de problema durante a partida (má conduta/trapaça, item 5). Guarda o
--    motivo como primeira mensagem da disputa.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_open_challenge_dispute(
  p_challenge_id uuid,
  p_user_id uuid,
  p_reason text,
  p_details text
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ch public.challenges;
  v_dispute_id uuid;
  v_other_id uuid;
BEGIN
  SELECT * INTO v_ch FROM public.challenges WHERE id = p_challenge_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;

  IF p_user_id NOT IN (v_ch.creator_id, v_ch.opponent_id) THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não faz parte deste desafio.';
  END IF;

  -- Permitido: partida em andamento (reporte de problema) OU resultado aceito
  -- automático ainda dentro da janela de retenção (contestação reativa).
  IF NOT (
    v_ch.status = 'in_progress'
    OR (v_ch.status = 'completed' AND v_ch.settlement_release_at IS NOT NULL AND v_ch.settlement_release_at > now())
  ) THEN
    RAISE EXCEPTION 'CANNOT_DISPUTE: Este desafio não pode ser contestado agora.';
  END IF;

  v_other_id := CASE WHEN p_user_id = v_ch.creator_id THEN v_ch.opponent_id ELSE v_ch.creator_id END;

  -- Mantém settlement_release_at/winner_id se veio de aceite-automático — é o
  -- sinal pra fn_resolve saber que o pote está consolidado no winner. O release
  -- não toca mais aqui porque o status deixa de ser 'completed'.
  UPDATE public.challenges SET status = 'disputed', updated_at = now() WHERE id = p_challenge_id RETURNING * INTO v_ch;

  INSERT INTO public.disputes (challenge_id, status)
  VALUES (p_challenge_id, 'open')
  ON CONFLICT (challenge_id) DO UPDATE SET status = 'open', updated_at = now()
  RETURNING id INTO v_dispute_id;

  INSERT INTO public.dispute_messages (dispute_id, sender_id, message)
  VALUES (v_dispute_id, p_user_id, '[' || coalesce(p_reason, 'Outro') || '] ' || coalesce(p_details, ''));

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (v_other_id, 'challenge_disputed', 'Desafio contestado ⚠️',
    'O outro jogador abriu uma contestação no desafio de ' || v_ch.game || '. A ArenaX1 vai analisar. Anexe suas provas no chat da disputa.',
    p_challenge_id);

  RETURN v_ch;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6) Resolver disputa de desafio 1v1 (admin) — preenche o buraco que só o
--    torneio tinha (09). Normaliza o dinheiro (se veio de aceite-automático, o
--    pote está todo no winner antigo; devolve a metade pro outro pra ficar
--    igual a uma divergência) e então liquida pro vencedor decidido. Penaliza
--    o fair_play SÓ de quem mentiu (reportou vitória e perdeu na decisão).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_resolve_challenge_dispute(
  p_challenge_id uuid,
  p_winner_id uuid
) RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ch public.challenges;
  v_loser_id uuid;
  v_loser_result text;
  v_prev_winner uuid;
  v_other uuid;
  v_new_rating numeric;
BEGIN
  SELECT * INTO v_ch FROM public.challenges WHERE id = p_challenge_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_FOUND: Desafio não encontrado.';
  END IF;
  IF v_ch.status != 'disputed' THEN
    RAISE EXCEPTION 'CHALLENGE_NOT_DISPUTED: Este desafio não está em disputa.';
  END IF;
  IF p_winner_id NOT IN (v_ch.creator_id, v_ch.opponent_id) THEN
    RAISE EXCEPTION 'INVALID_WINNER: O vencedor precisa ser um dos dois participantes.';
  END IF;

  -- Normaliza: se o pote está consolidado (veio de aceite-automático), devolve
  -- metade pro outro lado, restaurando o estado "cada um com sua aposta travada".
  IF v_ch.settlement_release_at IS NOT NULL AND v_ch.winner_id IS NOT NULL THEN
    v_prev_winner := v_ch.winner_id;
    v_other := CASE WHEN v_prev_winner = v_ch.creator_id THEN v_ch.opponent_id ELSE v_ch.creator_id END;
    UPDATE public.wallets SET locked_balance = locked_balance - v_ch.bet_amount, updated_at = now() WHERE user_id = v_prev_winner;
    UPDATE public.wallets SET locked_balance = locked_balance + v_ch.bet_amount, updated_at = now() WHERE user_id = v_other;
    UPDATE public.challenges SET winner_id = NULL, settlement_release_at = NULL WHERE id = p_challenge_id RETURNING * INTO v_ch;
  END IF;

  v_loser_id := CASE WHEN p_winner_id = v_ch.creator_id THEN v_ch.opponent_id ELSE v_ch.creator_id END;
  v_loser_result := CASE WHEN v_loser_id = v_ch.creator_id THEN v_ch.creator_result ELSE v_ch.opponent_result END;

  -- Agora ambos têm a aposta travada: liquida imediato pro vencedor decidido.
  v_ch := public.fn_settle_challenge(p_challenge_id, p_winner_id, false);

  UPDATE public.disputes
  SET status = 'resolved',
      resolution = 'Moderação da ArenaX1 analisou as provas e definiu o vencedor.',
      updated_at = now()
  WHERE challenge_id = p_challenge_id;

  -- Penalidade só pra quem MENTIU (reportou vitória e perdeu na decisão).
  -- Silêncio não penaliza (não é má conduta).
  IF v_loser_result = 'win' THEN
    UPDATE public.profiles SET fair_play_rating = GREATEST(fair_play_rating - 1.5, 0)
    WHERE id = v_loser_id RETURNING fair_play_rating INTO v_new_rating;

    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_loser_id, 'dispute_resolved_loss', 'Resultado falso identificado 🚩',
      'A moderação analisou o desafio de ' || v_ch.game || ' e confirmou que o resultado que você reportou era falso. Seu Fair Play caiu para ' || v_new_rating || '. Reincidência leva a banimento.',
      p_challenge_id);
  ELSE
    INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
    VALUES (v_loser_id, 'dispute_resolved_loss', 'Disputa resolvida',
      'A moderação analisou o desafio de ' || v_ch.game || ' e definiu o resultado. Dessa vez não foi pro seu lado.',
      p_challenge_id);
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id)
  VALUES (p_winner_id, 'dispute_resolved_win', 'Disputa resolvida a seu favor ✅',
    'A moderação da ArenaX1 confirmou sua vitória no desafio de ' || v_ch.game || '. O prêmio caiu na sua carteira.',
    p_challenge_id);

  RETURN v_ch;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_settle_challenge(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_release_due_settlements() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_open_challenge_dispute(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_resolve_challenge_dispute(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_settle_challenge(uuid, uuid, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_report_challenge_result(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_process_match_timeouts() TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_release_due_settlements() TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_open_challenge_dispute(uuid, uuid, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_resolve_challenge_dispute(uuid, uuid) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- Agendamento da liberação de prêmios retidos (puro SQL, de hora em hora).
-- Requer pg_cron (confira Database → Extensions; senão, cron externo/manual).
-- ─────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.unschedule('release-due-settlements')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'release-due-settlements');

SELECT cron.schedule(
  'release-due-settlements',
  '0 * * * *',
  $$ SELECT public.fn_release_due_settlements(); $$
);
