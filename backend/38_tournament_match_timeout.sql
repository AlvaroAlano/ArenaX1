-- Execute este script no SQL Editor do seu painel Supabase (depois do 37).
--
-- Objetivo: fechar o gap "torneio pago não tem timeout de partida". Hoje só o
-- desafio 1v1 tem fn_process_match_timeouts — uma partida de torneio pago em
-- que um jogador some (ou ninguém reporta) fica 'ready' pra sempre, travando a
-- chave inteira (e o dinheiro dos participantes que ainda dependem dela).
--
-- Decisão de produto (definida com o usuário): partida de torneio que estoura o
-- prazo SEM consenso vai SEMPRE pra MEDIAÇÃO DO ADMIN (vira 'disputed'), que
-- decide quem avança com fn_resolve_online_match_dispute (já existe). Sem
-- W.O. automático — diferente do 1v1 — porque numa chave o efeito de um erro
-- se propaga pras rodadas seguintes, então um humano confirma.
--
-- Como a partida não guarda "quando ficou pronta", adicionamos ready_at,
-- preenchido por TRIGGER (BEFORE INSERT/UPDATE quando status vira 'ready').
-- Assim não é preciso mexer nas funções grandes (fn_submit/fn_resolve/
-- fn_create_online_tournament) — o trigger cobre todos os caminhos.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Coluna ready_at + trigger que a preenche.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.tournament_matches
  ADD COLUMN IF NOT EXISTS ready_at timestamptz;

COMMENT ON COLUMN public.tournament_matches.ready_at IS
  'Quando a partida entrou em ''ready'' (os dois participantes definidos). Base do prazo de reporte do job de timeout. Preenchido pelo trigger trg_set_tournament_match_ready_at.';

CREATE OR REPLACE FUNCTION public.fn_set_tournament_match_ready_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Marca o instante em que a partida virou 'ready' (na criação da chave para
  -- a rodada 1, ou quando fn_submit/fn_resolve promove a próxima partida).
  IF NEW.status = 'ready' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'ready') THEN
    NEW.ready_at := now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_tournament_match_ready_at ON public.tournament_matches;
CREATE TRIGGER trg_set_tournament_match_ready_at
  BEFORE INSERT OR UPDATE ON public.tournament_matches
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_set_tournament_match_ready_at();

-- Backfill: partidas que já estão 'ready' passam a ter o cronômetro contando a
-- partir de AGORA (não retroativo — evita disputar em massa o que já existe).
UPDATE public.tournament_matches
SET ready_at = now()
WHERE status = 'ready' AND ready_at IS NULL;

-- Índice pro job varrer só o que interessa.
CREATE INDEX IF NOT EXISTS tournament_matches_ready_deadline_idx
  ON public.tournament_matches (status, ready_at)
  WHERE status = 'ready';

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Job de timeout: partida 'ready' de torneio pago EM ANDAMENTO que passou
--    do prazo sem virar 'completed' (sem consenso) → vira 'disputed' e cai na
--    fila do admin (GET /api/admin/disputes). Notifica os dois jogadores.
--    Prazo tunável (REPORT_WINDOW). Trava a linha e re-checa depois do lock,
--    mesmo padrão do fn_process_match_timeouts do 1v1.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_process_tournament_match_timeouts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_match public.tournament_matches;
  v_tournament public.tournaments;
  v_disputed int := 0;
  c_report_window constant interval := interval '24 hours';
BEGIN
  FOR v_row IN
    SELECT m.id
    FROM public.tournament_matches m
    JOIN public.tournaments t ON t.id = m.tournament_id
    WHERE t.type = 'online_paid'
      AND t.status = 'in_progress'
      AND m.status = 'ready'
      AND m.ready_at IS NOT NULL
      AND m.ready_at < now() - c_report_window
  LOOP
    SELECT * INTO v_match FROM public.tournament_matches WHERE id = v_row.id FOR UPDATE;
    CONTINUE WHEN v_match.status != 'ready'
              OR v_match.ready_at IS NULL
              OR v_match.ready_at >= now() - c_report_window;

    SELECT * INTO v_tournament FROM public.tournaments WHERE id = v_match.tournament_id;

    UPDATE public.tournament_matches SET status = 'disputed' WHERE id = v_match.id;

    IF NOT EXISTS (SELECT 1 FROM public.disputes WHERE tournament_match_id = v_match.id) THEN
      INSERT INTO public.disputes (tournament_match_id, status) VALUES (v_match.id, 'open');
    ELSE
      UPDATE public.disputes SET status = 'open', updated_at = now() WHERE tournament_match_id = v_match.id;
    END IF;

    INSERT INTO public.notifications (user_id, type, title, body, tournament_id, match_id)
    SELECT tp.user_id, 'match_disputed', 'Partida foi pra mediação ⚖️',
      'O prazo pra reportar o resultado da sua partida no torneio "' || v_tournament.title ||
      '" esgotou. A ArenaX1 vai analisar e decidir quem avança.',
      v_tournament.id, v_match.id
    FROM public.tournament_participants tp
    WHERE tp.id IN (v_match.participant_a_id, v_match.participant_b_id)
      AND tp.user_id IS NOT NULL;

    v_disputed := v_disputed + 1;
  END LOOP;

  RETURN jsonb_build_object('disputed', v_disputed);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_process_tournament_match_timeouts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_process_tournament_match_timeouts() TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Agendamento (pg_cron, a cada 5 min — mesmo ritmo do timeout do 1v1).
--    Se pg_cron não existir no plano, chame fn_process_tournament_match_timeouts
--    por um cron externo batendo no endpoint admin (adicionado no backend) ou
--    manualmente.
-- ─────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.unschedule('process-tournament-match-timeouts')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-tournament-match-timeouts');

SELECT cron.schedule(
  'process-tournament-match-timeouts',
  '*/5 * * * *',
  $$ SELECT public.fn_process_tournament_match_timeouts(); $$
);
