-- Criar tabelas públicas
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  psn_id text,
  xbox_id text,
  steam_id text,
  ea_id text,
  fair_play_rating numeric default 5.0 check (fair_play_rating >= 0 and fair_play_rating <= 5),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references public.profiles(id) on delete cascade,
  balance numeric(10,2) not null default 0.00 check (balance >= 0),
  locked_balance numeric(10,2) not null default 0.00 check (locked_balance >= 0),
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id uuid references public.profiles(id) on delete set null,
  bet_amount numeric(10,2) not null check (bet_amount >= 0),
  platform text not null, -- 'PS5', 'Xbox', 'PC', 'Crossplay'
  game text not null, -- 'EA FC 25', 'eFootball'
  status text not null default 'open', -- 'open', 'accepted', 'in_progress', 'result_submitted', 'disputed', 'completed', 'cancelled'
  creator_result text check (creator_result in ('win', 'loss')),
  opponent_result text check (opponent_result in ('win', 'loss')),
  winner_id uuid references public.profiles(id) on delete set null,
  rake_amount numeric(10,2) not null default 0.00 check (rake_amount >= 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  type text not null, -- 'deposit', 'withdraw', 'bet_freeze', 'bet_refund', 'win_prize', 'rake'
  amount numeric(10,2) not null,
  status text not null default 'pending', -- 'pending', 'completed', 'failed'
  description text,
  external_id text, -- ID de transação do gateway Pix
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null unique references public.challenges(id) on delete cascade,
  mediator_id uuid references public.profiles(id) on delete set null,
  status text not null default 'open', -- 'open', 'resolved', 'cancelled'
  resolution text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.dispute_messages (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  attachment_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Triggers de criação automática de profile & wallet
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, created_at, updated_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'player_' || substr(new.id::text, 1, 8)),
    now(),
    now()
  );

  insert into public.wallets (user_id, balance, locked_balance, updated_at)
  values (new.id, 0.00, 0.00, now());

  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
