-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Corrige uma lacuna real encontrada testando o fluxo do admin ponta a ponta:
-- o arquivo 09_dispute_resolution.sql nunca chegou a ser executado (só o 07,
-- 08 e 10 foram) — então a constraint de `notifications.type` ainda não
-- aceitava 'dispute_resolved_win'/'dispute_resolved_loss', e resolver
-- qualquer disputa de torneio pelo /admin quebrava com "new row for relation
-- notifications violates check constraint notifications_type_check" assim
-- que tentava avisar os dois jogadores do resultado.
--
-- A função fn_resolve_online_match_dispute em si já está correta (veio do
-- 10_admin_portal.sql, com p_admin_user_id) — o 09 antigo (versão de 2
-- argumentos, sem isso) está obsoleto e NÃO precisa mais ser rodado; só esta
-- correção pontual da constraint é necessária.

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'tournament_open', 'match_ready', 'match_disputed', 'tournament_prize',
    'tournament_cancelled', 'dispute_resolved_win', 'dispute_resolved_loss'
  ));

-- Policy de leitura de disputa de torneio pelos próprios participantes (também
-- ficou faltando por conta do 09 nunca ter rodado) — só leitura, não afeta a
-- resolução em si (que é sempre via service_role), mas fecha a lacuna de
-- defesa em profundidade.
drop policy if exists "Participantes da disputa de torneio podem ler o registro" on public.disputes;
create policy "Participantes da disputa de torneio podem ler o registro"
  on public.disputes for select
  to authenticated
  using (
    tournament_match_id in (
      select m.id from public.tournament_matches m
      join public.tournament_participants pa on pa.id = m.participant_a_id
      join public.tournament_participants pb on pb.id = m.participant_b_id
      where pa.user_id = auth.uid() or pb.user_id = auth.uid()
    )
  );
