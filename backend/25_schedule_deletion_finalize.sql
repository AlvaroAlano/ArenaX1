-- Execute no SQL Editor do Supabase — MAS antes confira se as extensões
-- pg_cron e pg_net estão disponíveis no seu plano (painel: Database →
-- Extensions). Se não estiverem, este arquivo não roda — caia pro plano B
-- (cron externo: cron-job.org / GitHub Actions agendado batendo no mesmo
-- endpoint com o mesmo header X-Cron-Secret).
--
-- Objetivo: agendar a anonimização definitiva das contas cuja carência de 30
-- dias já venceu. Roda 1x/dia. Como banir o login no auth.users depende da
-- Admin Auth API (fora do alcance do Postgres puro), o job NÃO chama uma
-- função SQL — ele faz um HTTP POST pro backend (account.py), que faz o ban
-- e chama fn_anonymize_profile. Autentica com um segredo estático
-- (X-Cron-Secret), não com sessão de admin.
--
-- Antes de rodar, troque os dois placeholders abaixo:
--   <SEU_BACKEND_URL>  = URL pública do backend FastAPI (ex.: https://arenax1.onrender.com)
--   <SEU_CRON_SECRET>  = mesmo valor setado na env CRON_SECRET do backend

-- 1) Habilita as extensões (idempotente; falha aqui = plano não tem, use cron externo)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2) Remove um agendamento anterior de mesmo nome (deixa o script reexecutável)
SELECT cron.unschedule('finalize-account-deletions')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'finalize-account-deletions');

-- 3) Agenda: todo dia às 03:00 UTC, POST no endpoint com o segredo no header.
SELECT cron.schedule(
  'finalize-account-deletions',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url     := '<SEU_BACKEND_URL>/api/account/finalize-due-deletions',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Cron-Secret', '<SEU_CRON_SECRET>'
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- Conferir depois:  SELECT * FROM cron.job;
-- Ver execuções:    SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
