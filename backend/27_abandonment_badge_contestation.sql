-- Execute no SQL Editor do Supabase (depois de 26).
--
-- Fecha a decisão do contador de abandono (regra 1.4). A CONTAGEM continua
-- 100% automática — um no-show é fato verificável pelo próprio sistema, não
-- vale burocratizar cada ausência isolada (princípio 4). O que ganha janela é
-- o SELO PÚBLICO: nada reputacional aparece a terceiros sem o usuário ter a
-- chance de contestar, mesmo padrão da retenção de prêmio do 26.
--
-- Ao CRUZAR o limiar de 3 abandonos pela primeira vez:
--   * agenda a publicação do selo pra daqui 48h (abandonment_badge_public_at);
--   * notifica o usuário pra ele contestar se a ausência teve motivo justo.
-- Passadas as 48h sem contestação → o selo aparece. Diferente do dinheiro, NÃO
-- precisa de cron: nada "se move", a visibilidade é derivada na leitura
-- (public_at <= now). O ProfileView passa a ler esse campo em vez de comparar
-- abandoned_matches direto.
--
-- A CONTESTAÇÃO em si (usuário aciona → admin publica se negada / arquiva se
-- justificada) entra na Fila de revisão de padrões reputacionais (regra 4.4,
-- ainda a construir) — aqui só criamos o timestamp que ela vai manipular.

-- ─────────────────────────────────────────────────────────────────────────
-- 0) Coluna nova: quando o selo de abandono passa a ser público.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS abandonment_badge_public_at timestamptz;

COMMENT ON COLUMN public.profiles.abandonment_badge_public_at IS
  'Quando o selo de "Histórico de abandono" passa a ser público. NULL = abaixo do limiar / nunca acionado. Futuro (> now) = em janela de contestação de 48h. Passado (<= now) = selo visível. Sem cron: a visibilidade é derivada na leitura.';

-- Backfill: quem já está no/acima do limiar antes desta migração já fica com o
-- selo público (grandfather — sem janela nem notificação; não se retroage
-- punição sobre ausências que aconteceram antes da regra existir).
UPDATE public.profiles
SET abandonment_badge_public_at = now()
WHERE abandoned_matches >= 3 AND abandonment_badge_public_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Novo tipo de notificação: aviso de que o selo vai ficar visível.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss',
    'deposit_confirmed', 'withdraw_completed',
    'challenge_accepted', 'challenge_result_pending', 'challenge_win',
    'challenge_loss', 'challenge_disputed',
    'challenge_join_requested', 'challenge_request_accepted', 'challenge_request_rejected',
    'challenge_expired',
    'abandonment_warning'
  ));

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Helper: registra 1 abandono e, SE cruzar o limiar pela 1ª vez, abre a
--    janela de contestação de 48h + avisa o usuário. Idempotente quanto ao
--    selo: só agenda uma vez (guardado por abandonment_badge_public_at IS NULL).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_register_abandonment(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c_threshold constant int := 3;
  v_new_count int;
  v_public_at timestamptz;
BEGIN
  UPDATE public.profiles
  SET abandoned_matches = abandoned_matches + 1
  WHERE id = p_user_id
  RETURNING abandoned_matches, abandonment_badge_public_at INTO v_new_count, v_public_at;

  -- Cruzou o limiar agora e ainda não há selo agendado/publicado → abre a
  -- janela e avisa. (Se v_public_at já não é NULL, o selo já foi acionado
  -- antes — não reagenda nem re-notifica.)
  IF v_new_count >= c_threshold AND v_public_at IS NULL THEN
    UPDATE public.profiles
    SET abandonment_badge_public_at = now() + interval '48 hours'
    WHERE id = p_user_id;

    -- O texto aponta pra uma porta que FUNCIONA hoje: a tela de Suporte, que
    -- grava um ticket amarrado à conta e alerta o admin (migração 28). Sem isso
    -- a "janela de contestação" vira promessa vazia. A resposta é manual por ora
    -- (a triagem automática é a Fila 4.4, ainda a construir).
    INSERT INTO public.notifications (user_id, type, title, body)
    VALUES (p_user_id, 'abandonment_warning',
      'Seu histórico de ausências vai ficar visível ⚠️',
      'Você acumulou ' || v_new_count || ' partidas sem confirmar presença no prazo. Em 48h um selo de "Histórico de abandono" aparece no seu perfil público. Se alguma dessas ausências teve um motivo justo, conteste antes disso pelo Suporte (no menu), em "Contestar histórico de ausências".');
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) fn_process_match_timeouts redefinido: idêntico ao 26, exceto que o
--    incremento inline do contador de abandono agora passa por
--    fn_register_abandonment (que cuida da janela + aviso do selo).
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
    -- fn_register_abandonment abre a janela de contestação do selo se cruzar o limiar.
    IF NOT v_ch.creator_ready THEN
      PERFORM public.fn_register_abandonment(v_ch.creator_id);
    END IF;
    IF NOT v_ch.opponent_ready THEN
      PERFORM public.fn_register_abandonment(v_ch.opponent_id);
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
-- Grants.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_register_abandonment(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_register_abandonment(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_process_match_timeouts() TO service_role;
