-- Execute este script no SQL Editor do seu painel Supabase (depois do 06_tournaments.sql).
--
-- Objetivo: Torneio Online Pago — segunda modalidade de torneio (ver
-- TODO.md / memória "Torneio de Sofá"). Reaproveita as MESMAS tabelas do
-- Torneio Local (`tournaments`/`tournament_participants`/`tournament_matches`),
-- diferenciadas pela nova coluna `type`, em vez de criar tabelas paralelas —
-- o mata-mata, a numeração de rodadas e o sorteio server-side já resolvidos
-- em 06_tournaments.sql continuam valendo para os dois tipos.
--
-- Diferenças do Torneio Local:
--   * Participantes são usuários REAIS (`tournament_participants.user_id`),
--     não só nomes digitados pelo anfitrião — cada um entra pagando a
--     inscrição da própria carteira (mesmo mecanismo de escrow de
--     fn_create_challenge: balance -> locked_balance).
--   * A chave só é sorteada/montada quando as vagas enchem (status
--     'registration_open' -> 'in_progress'), não na criação.
--   * Enquanto 'registration_open': cada inscrito pode desistir sozinho e
--     reaver o valor (fn_leave_online_tournament); se o prazo vencer sem
--     completar as vagas, reembolso automático de todo mundo
--     (fn_expire_stale_online_tournaments, chamada de forma preguiçosa —
--     sem cron — no início das rotas de listagem/leitura do backend).
--   * Placar não é digitado por um anfitrião confiável: cada jogador
--     reporta o próprio resultado (win/loss), MESMO padrão de consenso já
--     testado em fn_report_challenge_result — se divergir, vira registro em
--     `disputes` pra moderação.
--   * Pote (soma das inscrições - rake de 10%) é dividido 50/30/20 entre
--     1º/2º/3º lugar. O 3º lugar é decidido numa partida extra entre os
--     dois perdedores da semifinal, disputada em paralelo à final.
--
-- Convenção de erro igual ao resto do backend: RAISE EXCEPTION
-- 'CODIGO_ERRO: mensagem para o usuário'.

-- ─────────────────────────────────────────────────────────────────────────
-- Schema: estende as tabelas do Torneio Local em vez de duplicar.
-- ─────────────────────────────────────────────────────────────────────────
alter table public.tournaments
  add column type text not null default 'local' check (type in ('local', 'online_paid')),
  add column platform text, -- 'PS5'/'Xbox'/'PC'/'Crossplay' — só relevante pra online_paid
  add column entry_fee numeric(10,2) not null default 0 check (entry_fee >= 0),
  add column prize_pool numeric(10,2) not null default 0 check (prize_pool >= 0), -- soma bruta das inscrições pagas
  add column rake_amount numeric(10,2) not null default 0 check (rake_amount >= 0),
  add column registration_deadline timestamptz,
  add column runner_up_participant_id uuid,
  add column third_place_participant_id uuid;

alter table public.tournaments
  add constraint tournaments_runner_up_participant_id_fkey
  foreign key (runner_up_participant_id) references public.tournament_participants(id) on delete set null,
  add constraint tournaments_third_place_participant_id_fkey
  foreign key (third_place_participant_id) references public.tournament_participants(id) on delete set null;

-- 'registration_open': torneio online pago aguardando encher as vagas.
alter table public.tournaments drop constraint tournaments_status_check;
alter table public.tournaments
  add constraint tournaments_status_check
  check (status in ('registration_open', 'in_progress', 'completed', 'cancelled'));

create index tournaments_type_status_idx on public.tournaments (type, status);

-- Participante real (online_paid) tem user_id; participante do Torneio Local
-- continua só com display_name (user_id fica null). bracket_seed só é
-- atribuído quando a chave é sorteada (na criação, pro Local; ao encher as
-- vagas, pro Online) — por isso vira opcional.
alter table public.tournament_participants
  add column user_id uuid references public.profiles(id) on delete cascade,
  alter column bracket_seed drop not null;

create unique index tournament_participants_user_unique
  on public.tournament_participants (tournament_id, user_id)
  where user_id is not null;

-- Consenso de resultado (mesmo padrão de challenges.creator_result/opponent_result),
-- só usado em partidas de torneio online_paid. is_third_place marca a
-- partida extra de disputa do 3º lugar (mesma rodada da final, slot fixo 1).
alter table public.tournament_matches
  add column result_a text check (result_a in ('win', 'loss')),
  add column result_b text check (result_b in ('win', 'loss')),
  add column is_third_place boolean not null default false;

alter table public.tournament_matches drop constraint tournament_matches_status_check;
alter table public.tournament_matches
  add constraint tournament_matches_status_check
  check (status in ('waiting_players', 'ready', 'completed', 'disputed'));

-- Disputa de partida de torneio online: reaproveita a mesma tabela de
-- disputas dos Desafios (moderação única pra tudo), em vez de criar outra.
alter table public.disputes alter column challenge_id drop not null;
alter table public.disputes
  add column tournament_match_id uuid references public.tournament_matches(id) on delete cascade,
  add constraint disputes_exactly_one_source check (
    (challenge_id is not null and tournament_match_id is null) or
    (challenge_id is null and tournament_match_id is not null)
  );

create unique index disputes_tournament_match_unique
  on public.disputes (tournament_match_id)
  where tournament_match_id is not null;

-- ─────────────────────────────────────────────────────────────────────────
-- RLS: torneios online_paid são vitrine pública (igual a /api/challenges/open),
-- diferente do Torneio Local (só o anfitrião lê). Aditivo às policies já
-- criadas em 06_tournaments.sql.
-- ─────────────────────────────────────────────────────────────────────────
create policy "Qualquer um pode ler torneios online pagos"
  on public.tournaments for select
  to anon, authenticated
  using (type = 'online_paid');

create policy "Qualquer um pode ler participantes de torneios online pagos"
  on public.tournament_participants for select
  to anon, authenticated
  using (
    tournament_id in (select id from public.tournaments where type = 'online_paid')
  );

create policy "Qualquer um pode ler partidas de torneios online pagos"
  on public.tournament_matches for select
  to anon, authenticated
  using (
    tournament_id in (select id from public.tournaments where type = 'online_paid')
  );

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

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Criar torneio online pago: já inscreve o próprio anfitrião como
--    primeiro participante (paga a inscrição igual a qualquer outro) — mesma
--    filosofia de fn_create_challenge, onde o criador também compromete
--    dinheiro na hora de abrir a sala, em vez de só organizar sem jogar.
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

  IF p_entry_fee IS NULL OR p_entry_fee <= 0 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: A taxa de inscrição precisa ser maior que zero.';
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

  RETURN v_tournament;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Entrar num torneio online pago: escrow da inscrição + monta a chave
--    inteira (sorteio server-side, igual a fn_create_tournament) assim que
--    a última vaga é preenchida.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_join_online_tournament(
  p_tournament_id uuid,
  p_user_id uuid
) RETURNS public.tournaments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_wallet public.wallets;
  v_username text;
  v_participant_count int;
  v_shuffled uuid[];
  v_total_rounds int;
  v_round int;
  v_matches_in_round int;
  v_slot int;
BEGIN
  SELECT * INTO v_tournament FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Torneio não encontrado.';
  END IF;

  IF v_tournament.type != 'online_paid' THEN
    RAISE EXCEPTION 'INVALID_TOURNAMENT_TYPE: Este torneio não aceita inscrição paga.';
  END IF;

  IF v_tournament.status != 'registration_open' THEN
    RAISE EXCEPTION 'REGISTRATION_CLOSED: As inscrições para este torneio já foram encerradas.';
  END IF;

  IF v_tournament.registration_deadline IS NOT NULL AND now() > v_tournament.registration_deadline THEN
    RAISE EXCEPTION 'REGISTRATION_CLOSED: O prazo de inscrição deste torneio já venceu.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tournament_participants
    WHERE tournament_id = p_tournament_id AND user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'ALREADY_JOINED: Você já está inscrito neste torneio.';
  END IF;

  SELECT count(*) INTO v_participant_count FROM public.tournament_participants WHERE tournament_id = p_tournament_id;
  IF v_participant_count >= v_tournament.max_players THEN
    RAISE EXCEPTION 'TOURNAMENT_FULL: Este torneio já preencheu todas as vagas.';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira não encontrada.';
  END IF;
  IF v_wallet.balance < v_tournament.entry_fee THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Saldo insuficiente para pagar a inscrição.';
  END IF;

  SELECT username INTO v_username FROM public.profiles WHERE id = p_user_id;

  UPDATE public.wallets
  SET balance = balance - v_tournament.entry_fee,
      locked_balance = locked_balance + v_tournament.entry_fee,
      updated_at = now()
  WHERE id = v_wallet.id;

  INSERT INTO public.tournament_participants (tournament_id, user_id, display_name)
  VALUES (p_tournament_id, p_user_id, v_username);

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (v_wallet.id, 'bet_freeze', -v_tournament.entry_fee, 'completed',
    'Inscrição no torneio "' || v_tournament.title || '" (Sala: ' || substr(p_tournament_id::text, 1, 8) || ')');

  UPDATE public.tournaments
  SET prize_pool = prize_pool + v_tournament.entry_fee
  WHERE id = p_tournament_id
  RETURNING * INTO v_tournament;

  v_participant_count := v_participant_count + 1;

  -- Encheu todas as vagas: fecha inscrição e monta a chave (mesmo sorteio
  -- server-side de fn_create_tournament, incluindo a partida extra de 3º lugar).
  IF v_participant_count = v_tournament.max_players THEN
    SELECT array_agg(id ORDER BY random()) INTO v_shuffled
    FROM public.tournament_participants WHERE tournament_id = p_tournament_id;

    FOR v_slot IN 0..(v_tournament.max_players - 1) LOOP
      UPDATE public.tournament_participants SET bracket_seed = v_slot WHERE id = v_shuffled[v_slot + 1];
    END LOOP;

    v_total_rounds := CASE v_tournament.max_players WHEN 4 THEN 2 WHEN 8 THEN 3 WHEN 16 THEN 4 END;

    v_matches_in_round := v_tournament.max_players / 2;
    FOR v_slot IN 0..(v_matches_in_round - 1) LOOP
      INSERT INTO public.tournament_matches (
        tournament_id, round, slot, participant_a_id, participant_b_id, status
      ) VALUES (
        p_tournament_id, 1, v_slot,
        v_shuffled[v_slot * 2 + 1],
        v_shuffled[v_slot * 2 + 2],
        'ready'
      );
    END LOOP;

    FOR v_round IN 2..v_total_rounds LOOP
      v_matches_in_round := v_tournament.max_players >> v_round;
      FOR v_slot IN 0..(v_matches_in_round - 1) LOOP
        INSERT INTO public.tournament_matches (tournament_id, round, slot, status)
        VALUES (p_tournament_id, v_round, v_slot, 'waiting_players');
      END LOOP;
    END LOOP;

    -- Disputa de 3º lugar: mesma rodada da final, slot fixo 1 — alimentada
    -- pelos perdedores da semifinal (round = v_total_rounds - 1) em
    -- fn_submit_online_match_result.
    INSERT INTO public.tournament_matches (tournament_id, round, slot, status, is_third_place)
    VALUES (p_tournament_id, v_total_rounds, 1, 'waiting_players', true);

    UPDATE public.tournaments
    SET status = 'in_progress',
        rake_amount = round(v_tournament.prize_pool * 0.10, 2)
    WHERE id = p_tournament_id
    RETURNING * INTO v_tournament;
  END IF;

  RETURN v_tournament;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Sair de um torneio online pago (só antes da chave fechar): reembolso
--    total automático, igual à política documentada.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_leave_online_tournament(
  p_tournament_id uuid,
  p_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_participant public.tournament_participants;
  v_wallet public.wallets;
BEGIN
  SELECT * INTO v_tournament FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Torneio não encontrado.';
  END IF;

  IF v_tournament.status != 'registration_open' THEN
    RAISE EXCEPTION 'REGISTRATION_CLOSED: A chave já foi fechada — não é mais possível desistir com reembolso.';
  END IF;

  SELECT * INTO v_participant FROM public.tournament_participants
    WHERE tournament_id = p_tournament_id AND user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_PARTICIPANT: Você não está inscrito neste torneio.';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: Carteira não encontrada.';
  END IF;

  UPDATE public.wallets
  SET balance = balance + v_tournament.entry_fee,
      locked_balance = locked_balance - v_tournament.entry_fee,
      updated_at = now()
  WHERE id = v_wallet.id;

  INSERT INTO public.transactions (wallet_id, type, amount, status, description)
  VALUES (v_wallet.id, 'bet_refund', v_tournament.entry_fee, 'completed',
    'Reembolso de inscrição no torneio "' || v_tournament.title || '"');

  DELETE FROM public.tournament_participants WHERE id = v_participant.id;

  UPDATE public.tournaments SET prize_pool = prize_pool - v_tournament.entry_fee WHERE id = p_tournament_id;

  RETURN jsonb_build_object('status', 'success', 'message', 'Inscrição cancelada e valor estornado para sua carteira.');
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Varredura preguiçosa de expiração: sem cron no projeto, então o
--    backend chama esta função no início das rotas de listagem/leitura de
--    torneios online. Reembolsa todo mundo e cancela quem passou do prazo
--    sem completar as vagas.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_expire_stale_online_tournaments() RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament record;
  v_participant record;
  v_wallet_id uuid;
BEGIN
  FOR v_tournament IN
    SELECT * FROM public.tournaments
    WHERE type = 'online_paid' AND status = 'registration_open'
      AND registration_deadline IS NOT NULL AND registration_deadline < now()
    FOR UPDATE
  LOOP
    FOR v_participant IN
      SELECT * FROM public.tournament_participants WHERE tournament_id = v_tournament.id
    LOOP
      SELECT id INTO v_wallet_id FROM public.wallets WHERE user_id = v_participant.user_id FOR UPDATE;
      IF FOUND THEN
        UPDATE public.wallets
        SET balance = balance + v_tournament.entry_fee,
            locked_balance = locked_balance - v_tournament.entry_fee,
            updated_at = now()
        WHERE id = v_wallet_id;

        INSERT INTO public.transactions (wallet_id, type, amount, status, description)
        VALUES (v_wallet_id, 'bet_refund', v_tournament.entry_fee, 'completed',
          'Reembolso automático: torneio "' || v_tournament.title || '" não completou as vagas no prazo.');
      END IF;
    END LOOP;

    DELETE FROM public.tournament_participants WHERE tournament_id = v_tournament.id;

    UPDATE public.tournaments
    SET status = 'cancelled', completed_at = now(), prize_pool = 0
    WHERE id = v_tournament.id;
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 5) Reportar resultado de partida (consenso win/loss dos dois jogadores,
--    mesmo padrão de fn_report_challenge_result) — propaga vencedor,
--    alimenta a disputa de 3º lugar com o perdedor da semifinal, e paga o
--    pote (50/30/20) assim que a final e a disputa de 3º lugar terminam.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_submit_online_match_result(
  p_tournament_id uuid,
  p_match_id uuid,
  p_user_id uuid,
  p_result text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournament public.tournaments;
  v_match public.tournament_matches;
  v_side text;
  v_winner_id uuid;
  v_loser_id uuid;
  v_total_rounds int;
  v_next_round int;
  v_next_slot int;
  v_next_match public.tournament_matches;
  v_third_match public.tournament_matches;
  v_net_pool numeric;
  v_wallet_id uuid;
BEGIN
  IF p_result NOT IN ('win', 'loss') THEN
    RAISE EXCEPTION 'INVALID_RESULT: Resultado inválido. Deve ser ''win'' ou ''loss''.';
  END IF;

  SELECT * INTO v_tournament FROM public.tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Torneio não encontrado.';
  END IF;
  IF v_tournament.type != 'online_paid' THEN
    RAISE EXCEPTION 'INVALID_TOURNAMENT_TYPE: Este torneio não usa reporte por consenso.';
  END IF;
  IF v_tournament.status != 'in_progress' THEN
    RAISE EXCEPTION 'TOURNAMENT_NOT_IN_PROGRESS: Este torneio não está com a chave em andamento.';
  END IF;

  SELECT * INTO v_match FROM public.tournament_matches
    WHERE id = p_match_id AND tournament_id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Partida não encontrada.';
  END IF;
  IF v_match.status != 'ready' THEN
    RAISE EXCEPTION 'MATCH_NOT_READY: Esta partida ainda não pode receber um resultado.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.tournament_participants WHERE id = v_match.participant_a_id AND user_id = p_user_id) THEN
    v_side := 'a';
  ELSIF EXISTS (SELECT 1 FROM public.tournament_participants WHERE id = v_match.participant_b_id AND user_id = p_user_id) THEN
    v_side := 'b';
  ELSE
    RAISE EXCEPTION 'FORBIDDEN: Você não faz parte desta partida.';
  END IF;

  IF v_side = 'a' THEN
    IF v_match.result_a IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado desta partida.';
    END IF;
    UPDATE public.tournament_matches SET result_a = p_result WHERE id = p_match_id RETURNING * INTO v_match;
  ELSE
    IF v_match.result_b IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_REPORTED: Você já reportou o resultado desta partida.';
    END IF;
    UPDATE public.tournament_matches SET result_b = p_result WHERE id = p_match_id RETURNING * INTO v_match;
  END IF;

  IF v_match.result_a IS NULL OR v_match.result_b IS NULL THEN
    RETURN jsonb_build_object('status', 'waiting', 'message', 'Resultado reportado. Aguardando o oponente confirmar.');
  END IF;

  -- Divergência: os dois reportaram o mesmo lado (dois "win" ou dois "loss").
  IF NOT ((v_match.result_a = 'win' AND v_match.result_b = 'loss') OR (v_match.result_a = 'loss' AND v_match.result_b = 'win')) THEN
    UPDATE public.tournament_matches SET status = 'disputed' WHERE id = p_match_id;
    INSERT INTO public.disputes (tournament_match_id, status) VALUES (p_match_id, 'open');
    RETURN jsonb_build_object('status', 'disputed', 'message', 'Resultados divergentes. Partida em disputa — a moderação da ArenaX1 vai analisar.');
  END IF;

  v_winner_id := CASE WHEN v_match.result_a = 'win' THEN v_match.participant_a_id ELSE v_match.participant_b_id END;
  v_loser_id := CASE WHEN v_match.result_a = 'win' THEN v_match.participant_b_id ELSE v_match.participant_a_id END;

  UPDATE public.tournament_matches
  SET winner_participant_id = v_winner_id, status = 'completed', completed_at = now()
  WHERE id = p_match_id
  RETURNING * INTO v_match;

  v_total_rounds := CASE v_tournament.max_players WHEN 4 THEN 2 WHEN 8 THEN 3 WHEN 16 THEN 4 END;
  v_net_pool := v_tournament.prize_pool - v_tournament.rake_amount;

  -- Disputa de 3º lugar: só paga o vencedor, sem propagação de chave.
  IF v_match.is_third_place THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;

    UPDATE public.wallets SET balance = balance + round(v_net_pool * 0.2, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_net_pool * 0.2, 2), 'completed',
      '3º lugar no torneio "' || v_tournament.title || '"');

    UPDATE public.tournaments SET third_place_participant_id = v_winner_id WHERE id = p_tournament_id;

    RETURN jsonb_build_object('status', 'completed', 'match', to_jsonb(v_match), 'message', 'Disputa de 3º lugar encerrada.');
  END IF;

  -- Final: paga campeão (50%) e vice (30%), fecha o torneio.
  IF v_match.round = v_total_rounds THEN
    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_winner_id;
    UPDATE public.wallets SET balance = balance + round(v_net_pool * 0.5, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_net_pool * 0.5, 2), 'completed',
      'Campeão do torneio "' || v_tournament.title || '"');

    SELECT w.id INTO v_wallet_id
    FROM public.wallets w JOIN public.tournament_participants tp ON tp.user_id = w.user_id
    WHERE tp.id = v_loser_id;
    UPDATE public.wallets SET balance = balance + round(v_net_pool * 0.3, 2), updated_at = now() WHERE id = v_wallet_id;
    INSERT INTO public.transactions (wallet_id, type, amount, status, description)
    VALUES (v_wallet_id, 'tournament_prize', round(v_net_pool * 0.3, 2), 'completed',
      'Vice-campeão do torneio "' || v_tournament.title || '"');

    UPDATE public.tournaments
    SET status = 'completed', completed_at = now(),
        champion_participant_id = v_winner_id,
        runner_up_participant_id = v_loser_id
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('status', 'completed', 'tournament_completed', true, 'champion_participant_id', v_winner_id, 'match', to_jsonb(v_match));
  END IF;

  -- Rodadas anteriores à final: propaga o vencedor pro slot certo da
  -- próxima rodada (mesma aritmética de fn_submit_tournament_match_result).
  v_next_round := v_match.round + 1;
  v_next_slot := v_match.slot / 2;

  IF v_match.slot % 2 = 0 THEN
    UPDATE public.tournament_matches SET participant_a_id = v_winner_id
    WHERE tournament_id = p_tournament_id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  ELSE
    UPDATE public.tournament_matches SET participant_b_id = v_winner_id
    WHERE tournament_id = p_tournament_id AND round = v_next_round AND slot = v_next_slot
    RETURNING * INTO v_next_match;
  END IF;

  IF v_next_match.participant_a_id IS NOT NULL AND v_next_match.participant_b_id IS NOT NULL THEN
    UPDATE public.tournament_matches SET status = 'ready' WHERE id = v_next_match.id RETURNING * INTO v_next_match;
  END IF;

  -- Se essa era a semifinal (round = v_total_rounds - 1, sempre com
  -- exatamente 2 partidas), o perdedor vai pra disputa de 3º lugar —
  -- mesma rodada da final, slot fixo 1 (ver fn_join_online_tournament).
  IF v_match.round = v_total_rounds - 1 THEN
    IF v_match.slot % 2 = 0 THEN
      UPDATE public.tournament_matches SET participant_a_id = v_loser_id
      WHERE tournament_id = p_tournament_id AND round = v_total_rounds AND slot = 1
      RETURNING * INTO v_third_match;
    ELSE
      UPDATE public.tournament_matches SET participant_b_id = v_loser_id
      WHERE tournament_id = p_tournament_id AND round = v_total_rounds AND slot = 1
      RETURNING * INTO v_third_match;
    END IF;

    IF v_third_match.participant_a_id IS NOT NULL AND v_third_match.participant_b_id IS NOT NULL THEN
      UPDATE public.tournament_matches SET status = 'ready' WHERE id = v_third_match.id;
    END IF;
  END IF;

  RETURN jsonb_build_object('status', 'completed', 'tournament_completed', false, 'match', to_jsonb(v_match), 'next_match', to_jsonb(v_next_match));
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Grants: só o backend (service_role) deve poder chamar essas funções.
-- ─────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_create_online_tournament(uuid, text, text, text, int, numeric, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_join_online_tournament(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_leave_online_tournament(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_expire_stale_online_tournaments() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_submit_online_match_result(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_create_online_tournament(uuid, text, text, text, int, numeric, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_join_online_tournament(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_leave_online_tournament(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_expire_stale_online_tournaments() TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_submit_online_match_result(uuid, uuid, uuid, text) TO service_role;
