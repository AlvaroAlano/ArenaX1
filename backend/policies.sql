-- Ativação Geral do RLS
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.challenges enable row level security;
alter table public.transactions enable row level security;
alter table public.disputes enable row level security;
alter table public.dispute_messages enable row level security;

-- Políticas para profiles
create policy "Permitir leitura de perfis para usuários autenticados"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Permitir atualização do próprio perfil"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Políticas para wallets
create policy "Permitir que usuários leiam apenas a própria carteira"
  on public.wallets for select
  to authenticated
  using (auth.uid() = user_id);

-- Políticas para challenges
create policy "Permitir visualização de desafios por usuários autenticados"
  on public.challenges for select
  to authenticated
  using (true);

create policy "Permitir criação de desafios por usuários autenticados"
  on public.challenges for insert
  to authenticated
  with check (auth.uid() = creator_id);

create policy "Permitir atualização de desafios pelos participantes"
  on public.challenges for update
  to authenticated
  using (auth.uid() = creator_id or auth.uid() = opponent_id);

-- Políticas para transactions
create policy "Permitir visualização apenas das próprias transações"
  on public.transactions for select
  to authenticated
  using (
    wallet_id in (select id from public.wallets where user_id = auth.uid())
  );

-- Políticas para disputes
create policy "Permitir visualização da disputa pelos participantes"
  on public.disputes for select
  to authenticated
  using (
    challenge_id in (
      select id from public.challenges
      where creator_id = auth.uid() or opponent_id = auth.uid()
    )
  );

-- Políticas para dispute_messages
create policy "Permitir visualização de mensagens pelos participantes"
  on public.dispute_messages for select
  to authenticated
  using (
    dispute_id in (
      select d.id from public.disputes d
      join public.challenges c on d.challenge_id = c.id
      where c.creator_id = auth.uid() or c.opponent_id = auth.uid()
    )
  );

create policy "Permitir envio de mensagens pelos participantes"
  on public.dispute_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid() and
    dispute_id in (
      select d.id from public.disputes d
      join public.challenges c on d.challenge_id = c.id
      where c.creator_id = auth.uid() or c.opponent_id = auth.uid()
    )
  );
