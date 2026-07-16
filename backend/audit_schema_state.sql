-- DIAGNÓSTICO (somente leitura — não altera nada). Rode no SQL Editor do
-- Supabase e me mande a tabela de resultado. Cada linha confere uma "impressão
-- digital" que SÓ existe na versão MAIS RECENTE de cada função/objeto crítico.
-- Se aparecer 'ATENCAO', aquela função está rodando uma versão antiga (padrão
-- "migração fantasma") e precisa ser reaplicada.

WITH fns AS (
  SELECT p.proname,
         string_agg(p.prosrc, E'\n---\n') AS src,   -- junta overloads, se houver
         bool_or(p.prosecdef) AS any_secdef
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
  GROUP BY p.proname
),
checks(ordem, item, ok) AS (
  VALUES
    -- ── Dinheiro: desafio 1v1 ──────────────────────────────────────────────
    (1,  'fn_settle_challenge existe (rake 8%, migr.26)',
         (SELECT coalesce(bool_or(src ILIKE '%c_rake_pct%0.08%' OR src ILIKE '%0.08%'), false) FROM fns WHERE proname='fn_settle_challenge')),
    (2,  'fn_report_challenge_result usa fn_settle_challenge (migr.26, NAO o rake 10pct antigo)',
         (SELECT coalesce(bool_or(src ILIKE '%fn_settle_challenge%'), false) FROM fns WHERE proname='fn_report_challenge_result')),
    (3,  'fn_process_match_timeouts tem aceite-automático c/ retenção (migr.26)',
         (SELECT coalesce(bool_or(src ILIKE '%auto_settled%'), false) FROM fns WHERE proname='fn_process_match_timeouts')),
    (4,  'fn_release_due_settlements existe (migr.26)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_release_due_settlements')),
    (5,  'fn_open_challenge_dispute existe (migr.26)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_open_challenge_dispute')),
    (6,  'fn_resolve_challenge_dispute existe (migr.26)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_resolve_challenge_dispute')),
    (7,  'fn_cancel_challenge_dispute existe (migr.33)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_cancel_challenge_dispute')),
    -- ── Ciclo de vida do desafio ───────────────────────────────────────────
    (8,  'fn_accept_join_request leva a status accepted + prazo (migr.24)',
         (SELECT coalesce(bool_or(src ILIKE '%accepted%' AND src ILIKE '%start_deadline%'), false) FROM fns WHERE proname='fn_accept_join_request')),
    (9,  'fn_mark_ready existe (migr.24)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_mark_ready')),
    -- ── Torneio online pago ────────────────────────────────────────────────
    (10, 'fn_submit_online_match_result: esquema escalonado (migr.19: 0.55 p/ 8 jog)',
         (SELECT coalesce(bool_or(src ILIKE '%0.55%'), false) FROM fns WHERE proname='fn_submit_online_match_result')),
    (11, 'fn_submit_online_match_result: correção da trava de 3º lugar (migr.37: v_third_pct > 0)',
         (SELECT coalesce(bool_or(src ILIKE '%v_third_pct > 0%'), false) FROM fns WHERE proname='fn_submit_online_match_result')),
    (12, 'fn_resolve_online_match_dispute: correção da trava de 3º lugar (migr.37)',
         (SELECT coalesce(bool_or(src ILIKE '%v_third_pct > 0%'), false) FROM fns WHERE proname='fn_resolve_online_match_dispute')),
    (13, 'fn_create_online_tournament existe (migr.07)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_create_online_tournament')),
    (14, 'fn_expire_stale_online_tournaments existe (migr.07)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_expire_stale_online_tournaments')),
    -- ── Carteira / Pix ─────────────────────────────────────────────────────
    (15, 'fn_withdraw fica PENDING p/ admin (migr.31, NÃO completed antigo)',
         (SELECT coalesce(bool_or(src ILIKE '%''pending''%'), false) FROM fns WHERE proname='fn_withdraw')),
    (16, 'fn_process_pix_deposit_webhook credita líquido (taxa, migr.31)',
         (SELECT coalesce(bool_or(src ILIKE '%fee_amount%'), false) FROM fns WHERE proname='fn_process_pix_deposit_webhook')),
    (17, 'fn_confirm_withdraw existe (migr.31)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_confirm_withdraw')),
    (18, 'fn_reject_withdraw existe (migr.31)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_reject_withdraw')),
    -- ── Conta ──────────────────────────────────────────────────────────────
    (19, 'fn_deactivate_account bloqueia partida ativa (migr.35/23: ACTIVE_MATCH)',
         (SELECT coalesce(bool_or(src ILIKE '%ACTIVE_MATCH%'), false) FROM fns WHERE proname='fn_deactivate_account')),
    (20, 'fn_request_account_deletion existe (migr.22)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_request_account_deletion')),
    (21, 'fn_anonymize_profile existe (migr.22)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_anonymize_profile')),
    -- ── Cadastro / KYC ─────────────────────────────────────────────────────
    (22, 'handle_new_user exige CPF/idade no e-mail (migr.36: BIRTH_DATE_REQUIRED)',
         (SELECT coalesce(bool_or(src ILIKE '%BIRTH_DATE_REQUIRED%'), false) FROM fns WHERE proname='handle_new_user')),
    (23, 'fn_is_valid_cpf existe (migr.32)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_is_valid_cpf')),
    -- ── Segurança: trava de coluna (migr.34) ───────────────────────────────
    (24, 'fn_guard_profile_sensitive_columns existe (migr.34)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_guard_profile_sensitive_columns')),
    (25, 'fn_guard_profile_sensitive_columns é SECURITY INVOKER (NÃO definer!)',
         (SELECT coalesce(bool_or(NOT any_secdef), false) FROM fns WHERE proname='fn_guard_profile_sensitive_columns')),
    -- ── Suporte ────────────────────────────────────────────────────────────
    (26, 'fn_open_support_ticket existe (migr.28)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_open_support_ticket')),
    (27, 'fn_reply_support_ticket existe (migr.29)',
         (SELECT count(*)>0 FROM fns WHERE proname='fn_reply_support_ticket'))
),
-- ── Triggers ─────────────────────────────────────────────────────────────
trig(ordem, item, ok) AS (
  VALUES
    (28, 'trigger trg_guard_profile_sensitive_columns em profiles (migr.34)',
         (SELECT count(*)>0 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname='public' AND c.relname='profiles' AND t.tgname='trg_guard_profile_sensitive_columns' AND NOT t.tgisinternal)),
    (29, 'trigger on_auth_user_created (handle_new_user) em auth.users',
         (SELECT count(*)>0 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname='auth' AND c.relname='users' AND NOT t.tgisinternal))
),
-- ── Colunas novas que migrações recentes adicionaram ─────────────────────
cols(ordem, item, ok) AS (
  VALUES
    (30, 'challenges.settlement_release_at (migr.26)',
         (SELECT count(*)>0 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='settlement_release_at')),
    (31, 'challenges.creator_ready/start_deadline (migr.24)',
         (SELECT count(*)>0 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='start_deadline')),
    (32, 'profiles.abandoned_matches (migr.26)',
         (SELECT count(*)>0 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='abandoned_matches')),
    (33, 'profiles.deactivated_at (migr.23)',
         (SELECT count(*)>0 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivated_at')),
    (34, 'tournaments.fourth_place_participant_id (migr.19/37)',
         (SELECT count(*)>0 FROM information_schema.columns WHERE table_schema='public' AND table_name='tournaments' AND column_name='fourth_place_participant_id')),
    (35, 'transactions.fee_amount/pix_key (migr.31)',
         (SELECT count(*)>0 FROM information_schema.columns WHERE table_schema='public' AND table_name='transactions' AND column_name='fee_amount')),
    (36, 'profile_kyc existe (migr.32)',
         (SELECT count(*)>0 FROM information_schema.tables WHERE table_schema='public' AND table_name='profile_kyc'))
)
SELECT ordem,
       CASE WHEN ok THEN 'OK' ELSE '❌ ATENCAO — REAPLICAR' END AS status,
       item
FROM (SELECT * FROM checks UNION ALL SELECT * FROM trig UNION ALL SELECT * FROM cols) x
ORDER BY (NOT ok) DESC, ordem;   -- falhas no topo
