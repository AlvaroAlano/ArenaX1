-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Objetivo: Torneio Local (Torneio de Sofá) — Fase 1 do roadmap de torneios
-- (ver TODO.md, seção "Torneio de Sofá"). Grátis, sem carteira envolvida:
-- só o anfitrião tem conta, os participantes são só nomes digitados por ele.
--
-- Mesma filosofia de fn_create_challenge/fn_report_challenge_result: toda
-- mutação de chave (criar torneio, avançar vencedor) passa por função
-- SECURITY DEFINER chamada pelo backend, nunca por INSERT/UPDATE direto do
-- client — mesmo sem dinheiro em jogo, determinar vencedor e propagar pra
-- próxima rodada é lógica que não pode ser confiada ao client (um client
-- malicioso ou com bug poderia submeter um winner_id que não bate com o
-- placar, ou corromper o slot de uma partida irmã).
--
-- Convenção de erro: RAISE EXCEPTION 'CODIGO_ERRO: mensagem para o usuário'
-- — o backend (tournaments.py) faz o parse do prefixo antes de ':' pra
-- decidir o status HTTP, mesmo padrão de 04_atomic_wallet_functions.sql.

-- ─────────────────────────────────────────────────────────────────────────
-- Tabelas
-- ─────────────────────────────────────────────────────────────────────────
create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  game text not null, -- 'EA Sports FC 25', 'eFootball'
  format text not null default 'mata_mata' check (format in ('mata_mata')),
  max_players int not null check (max_players in (4, 8, 16)),
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'cancelled')),
  champion_participant_id uuid, -- FK adicionada depois que tournament_participants existir
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  completed_at timestamp with time zone
);

create table public.tournament_participants (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  display_name text not null, -- participante é só um nome digitado pelo anfitrião, sem conta
  team_name text,
  bracket_seed int not null, -- posição sorteada 0..N-1, define o slot inicial na rodada 1
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (tournament_id, bracket_seed)
);

alter table public.tournaments
  add constraint tournaments_champion_participant_id_fkey
  foreign key (champion_participant_id) references public.tournament_participants(id) on delete set null;

create table public.tournament_matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  round int not null,          -- 1-indexado; a rodada mais alta é a final
  slot int not null,           -- posição da partida dentro da rodada, 0-indexado
  participant_a_id uuid references public.tournament_participants(id) on delete set null,
  participant_b_id uuid references public.tournament_participants(id) on delete set null,
  score_a int,
  score_b int,
  winner_participant_id uuid references public.tournament_participants(id) on delete set null,
  status text not null default 'waiting_players' check (status in ('waiting_players', 'ready', 'completed')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  completed_at timestamp with time zone,
  unique (tournament_id, round, slot),
  check (score_a is null or score_b is null or score_a <> score_b) -- sem empate no mata-mata
);

create index tournament_matches_tournament_id_idx on public.tournament_matches (tournament_id);
create index tournament_participants_tournament_id_idx on public.tournament_participants (tournament_id);
create index tournaments_host_id_idx on public.tournaments (host_id);

-- ─────────────────────────────────────────────────────────────────────────
-- RLS: somente leitura para o próprio anfitrião. Nenhuma policy de
-- INSERT/UPDATE/DELETE — toda escrita passa pelas funções abaixo
-- (service_role ignora RLS), mesmo modelo de confiança de wallets/transactions.
-- ─────────────────────────────────────────────────────────────────────────
alter table public.tournaments enable row level security;
alter table public.tournament_participants enable row level security;
alter table public.tournament_matches enable row level security;

create policy "Permitir que o anfitrião leia os próprios torneios"
  on public.tournaments for select
  to authenticated
  using (auth.uid() = host_id);

create policy "Permitir que o anfitrião leia os participantes dos próprios torneios"
  on public.tournament_participants for select
  to authenticated
  using (
    tournament_id in (select id from public.tournaments where host_id = auth.uid())
  );

create policy "Permitir que o anfitrião leia as partidas dos próprios torneios"
  on public.tournament_matches for select
  to authenticated
  using (
    tournament_id in (select id from public.tournaments where host_id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Criar torneio: valida, embaralha participantes (e times, se pedido) no
--    servidor — nunca confiar na ordem enviada pelo client, pra um
--    anfitrião não poder arrumar a chave a favor de um amigo — e já monta o
--    esqueleto da chave inteira (rodada 1 preenchida, rodadas seguintes com
--    slots vazios aguardando os classificados).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_create_tournament(
  p_host_id uuid,
  p_title text,
  p_game text,
  p_max_players int,
  p_participant_names text[],
  p_randomize_teams boolean,
  p_team_names text[]
) RETURNS public.tournaments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_shuffled_names text[];
  v_shuffled_teams text[];
  v_total_rounds int;
  v_round int;
  v_matches_in_round int;
  v_slot int;
  v_participant_ids uuid[];
  v_new_participant public.tournament_participants;
BEGIN
  IF p_max_players NOT IN (4, 8, 16) THEN
    RAISE EXCEPTION 'INVALID_PLAYER_COUNT: O torneio precisa ter 4, 8 ou 16 jogadores.';
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION 'INVALID_TITLE: Informe um nome para o torneio.';
  END IF;

  IF array_length(p_participant_names, 1) IS DISTINCT FROM p_max_players THEN
    RAISE EXCEPTION 'INVALID_PARTICIPANTS: A quantidade de nomes não bate com o número de jogadores escolhido.';
  END IF;

  IF EXISTS (SELECT 1 FROM unnest(p_participant_names) n WHERE trim(n) = '') THEN
    RAISE EXCEPTION 'INVALID_PARTICIPANTS: Nenhum nome de jogador pode ficar em branco.';
  END IF;

  IF p_randomize_teams THEN
    IF array_length(p_team_names, 1) IS DISTINCT FROM p_max_players THEN
      RAISE EXCEPTION 'INVALID_TEAMS: A quantidade de times não bate com o número de jogadores.';
    END IF;
    IF EXISTS (SELECT 1 FROM unnest(p_team_names) t WHERE trim(t) = '') THEN
      RAISE EXCEPTION 'INVALID_TEAMS: Nenhum nome de time pode ficar em branco.';
    END IF;
  END IF;

  INSERT INTO public.tournaments (host_id, title, game, max_players, status)
  VALUES (p_host_id, trim(p_title), p_game, p_max_players, 'in_progress')
  RETURNING * INTO v_tournament;

  -- Sorteio server-side: embaralha nomes; se houver times, embaralha
  -- independentemente e casa por posição (bijeção aleatória nome<->time).
  SELECT array_agg(x ORDER BY random()) INTO v_shuffled_names FROM unnest(p_participant_names) x;
  IF p_randomize_teams THEN
    SELECT array_agg(x ORDER BY random()) INTO v_shuffled_teams FROM unnest(p_team_names) x;
  END IF;

  v_participant_ids := ARRAY[]::uuid[];
  FOR v_slot IN 0..(p_max_players - 1) LOOP
    INSERT INTO public.tournament_participants (tournament_id, display_name, team_name, bracket_seed)
    VALUES (
      v_tournament.id,
      v_shuffled_names[v_slot + 1],
      CASE WHEN p_randomize_teams THEN v_shuffled_teams[v_slot + 1] ELSE NULL END,
      v_slot
    )
    RETURNING * INTO v_new_participant;
    v_participant_ids[v_slot] := v_new_participant.id;
  END LOOP;

  -- Monta o esqueleto da chave inteira. Número de rodadas é fixo pelos três
  -- tamanhos permitidos (4/8/16) — tabela direta em vez de log2/power, pra
  -- não depender de precisão de ponto flutuante numa conta que precisa ser
  -- exata.
  v_total_rounds := CASE p_max_players
    WHEN 4 THEN 2
    WHEN 8 THEN 3
    WHEN 16 THEN 4
  END;

  -- Rodada 1: pares já definidos pelo sorteio acima, prontas pra jogar.
  v_matches_in_round := p_max_players / 2;
  FOR v_slot IN 0..(v_matches_in_round - 1) LOOP
    INSERT INTO public.tournament_matches (
      tournament_id, round, slot, participant_a_id, participant_b_id, status
    ) VALUES (
      v_tournament.id, 1, v_slot,
      v_participant_ids[v_slot * 2],
      v_participant_ids[v_slot * 2 + 1],
      'ready'
    );
  END LOOP;

  -- Rodadas seguintes: slots vazios, aguardando os classificados da rodada
  -- anterior. Divisão inteira por deslocamento de bits (2^v_round), exata.
  FOR v_round IN 2..v_total_rounds LOOP
    v_matches_in_round := p_max_players >> v_round;
    FOR v_slot IN 0..(v_matches_in_round - 1) LOOP
      INSERT INTO public.tournament_matches (tournament_id, round, slot, status)
      VALUES (v_tournament.id, v_round, v_slot, 'waiting_players');
    END LOOP;
  END LOOP;

  RETURN v_tournament;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Registrar placar de uma partida: valida dono/status, grava o
--    resultado e propaga o vencedor pra próxima rodada (ou fecha o
--    torneio, se era a final) — tudo dentro da mesma transação.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_submit_tournament_match_result(
  p_host_id uuid,
  p_tournament_id uuid,
  p_match_id uuid,
  p_score_a int,
  p_score_b int
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_match public.tournament_matches;
  v_winner_id uuid;
  v_total_rounds int;
  v_next_round int;
  v_next_slot int;
  v_next_match public.tournament_matches;
BEGIN
  IF p_score_a IS NULL OR p_score_b IS NULL OR p_score_a < 0 OR p_score_b < 0 THEN
    RAISE EXCEPTION 'INVALID_SCORE: Informe um placar válido para os dois lados.';
  END IF;

  IF p_score_a = p_score_b THEN
    RAISE EXCEPTION 'INVALID_SCORE: Não pode haver empate no mata-mata.';
  END IF;

  -- Trava o torneio inteiro (não só a partida): o avanço de vencedor mexe
  -- numa segunda linha (a partida da próxima rodada), então travar só o
  -- match não impediria duas submissões concorrentes no mesmo torneio de
  -- colidirem no slot compartilhado da rodada seguinte.
  SELECT * INTO v_tournament FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Torneio não encontrado.';
  END IF;

  IF v_tournament.host_id != p_host_id THEN
    RAISE EXCEPTION 'FORBIDDEN: Você não tem acesso a este torneio.';
  END IF;

  IF v_tournament.status != 'in_progress' THEN
    RAISE EXCEPTION 'TOURNAMENT_NOT_IN_PROGRESS: Este torneio não está em andamento.';
  END IF;

  SELECT * INTO v_match FROM public.tournament_matches
    WHERE id = p_match_id AND tournament_id = p_tournament_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Partida não encontrada.';
  END IF;

  IF v_match.status != 'ready' THEN
    RAISE EXCEPTION 'MATCH_NOT_READY: Esta partida ainda não pode receber um placar.';
  END IF;

  v_winner_id := CASE WHEN p_score_a > p_score_b THEN v_match.participant_a_id ELSE v_match.participant_b_id END;

  UPDATE public.tournament_matches
  SET score_a = p_score_a,
      score_b = p_score_b,
      winner_participant_id = v_winner_id,
      status = 'completed',
      completed_at = now()
  WHERE id = p_match_id
  RETURNING * INTO v_match;

  v_total_rounds := CASE v_tournament.max_players
    WHEN 4 THEN 2
    WHEN 8 THEN 3
    WHEN 16 THEN 4
  END;

  IF v_match.round = v_total_rounds THEN
    -- Era a final: fecha o torneio e define o campeão.
    UPDATE public.tournaments
    SET status = 'completed', completed_at = now(), champion_participant_id = v_winner_id
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object(
      'match', to_jsonb(v_match),
      'tournament_completed', true,
      'champion_participant_id', v_winner_id,
      'next_match', null
    );
  END IF;

  -- Propaga o vencedor pro slot certo da próxima rodada: aritmética padrão
  -- de mata-mata 0-indexado — round+1, slot = slot_atual / 2 (divisão
  -- inteira), lado A se o slot atual era par, lado B se era ímpar.
  v_next_round := v_match.round + 1;
  v_next_slot := v_match.slot / 2;

  IF v_match.slot % 2 = 0 THEN
    UPDATE public.tournament_matches
    SET participant_a_id = v_winner_id
    WHERE tournament_id = p_tournament_id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  ELSE
    UPDATE public.tournament_matches
    SET participant_b_id = v_winner_id
    WHERE tournament_id = p_tournament_id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  END IF;

  -- Se os dois lados da próxima partida já estão definidos, libera pro jogo.
  IF v_next_match.participant_a_id IS NOT NULL AND v_next_match.participant_b_id IS NOT NULL THEN
    UPDATE public.tournament_matches
    SET status = 'ready'
    WHERE id = v_next_match.id
    RETURNING * INTO v_next_match;
  END IF;

  RETURN jsonb_build_object(
    'match', to_jsonb(v_match),
    'tournament_completed', false,
    'champion_participant_id', null,
    'next_match', to_jsonb(v_next_match)
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants: só o backend (service_role) deve poder chamar essas funções.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_create_tournament(uuid, text, text, int, text[], boolean, text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_submit_tournament_match_result(uuid, uuid, uuid, int, int) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_create_tournament(uuid, text, text, int, text[], boolean, text[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_submit_tournament_match_result(uuid, uuid, uuid, int, int) TO service_role;
