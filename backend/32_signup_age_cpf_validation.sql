-- Execute este script no SQL Editor do seu painel Supabase (depois do
-- 31_mercadopago_deposit_fee_and_withdrawal_flow.sql).
--
-- Objetivo: fechar a lacuna encontrada na revisão de segurança — o
-- RegisterView.vue passou a coletar CPF/telefone/data de nascimento e checar
-- +18 (Lei nº 15.211/2025), mas isso era só client-side: nada no backend
-- impedia um cadastro direto via API sem esses dados ou com um menor de
-- idade. Este arquivo move a validação pro trigger de criação de conta
-- (handle_new_user, SECURITY DEFINER, roda dentro da mesma transação do
-- signup — se ele levantar exceção, a conta inteira não é criada).
--
-- IMPORTANTE: só valida quando o cadastro TRAZ esses dados (o formulário de
-- e-mail/senha sempre traz). Login social (Google) ainda não coleta CPF/data
-- de nascimento — continua sendo uma lacuna conhecida, documentada aqui em
-- vez de escondida, até existir um fluxo de KYC pós-cadastro pra esse caso.

-- ─────────────────────────────────────────────────────────────────────────
-- 1) Validador de CPF (formato + dígitos verificadores). Rejeita também
--    sequências óbvias (111.111.111-11 etc.) que passam no checksum
--    matematicamente mas nunca são CPFs reais.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_is_valid_cpf(p_cpf text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_digits text;
  v_d int[];
  v_sum int;
  v_rem int;
  v_check1 int;
  v_check2 int;
  i int;
BEGIN
  v_digits := regexp_replace(coalesce(p_cpf, ''), '[^0-9]', '', 'g');

  IF length(v_digits) != 11 THEN
    RETURN false;
  END IF;

  IF v_digits ~ '^(\d)\1{10}$' THEN
    RETURN false;
  END IF;

  FOR i IN 1..11 LOOP
    v_d[i] := substr(v_digits, i, 1)::int;
  END LOOP;

  v_sum := 0;
  FOR i IN 1..9 LOOP
    v_sum := v_sum + v_d[i] * (11 - i);
  END LOOP;
  v_rem := v_sum % 11;
  v_check1 := CASE WHEN v_rem < 2 THEN 0 ELSE 11 - v_rem END;
  IF v_check1 != v_d[10] THEN
    RETURN false;
  END IF;

  v_sum := 0;
  FOR i IN 1..10 LOOP
    v_sum := v_sum + v_d[i] * (12 - i);
  END LOOP;
  v_rem := v_sum % 11;
  v_check2 := CASE WHEN v_rem < 2 THEN 0 ELSE 11 - v_rem END;
  IF v_check2 != v_d[11] THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Tabela separada pra dado sensível (CPF/telefone/nascimento) — NÃO fica
--    em profiles, que tem "select" liberado pra qualquer usuário autenticado
--    (policies.sql). Só o próprio dono lê a própria linha; só o trigger
--    (SECURITY DEFINER, ignora RLS) escreve — o usuário não pode alterar
--    CPF/data de nascimento depois de cadastrado por conta própria.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profile_kyc (
  id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  cpf text NOT NULL UNIQUE,
  phone text,
  birth_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profile_kyc IS
  'Dados sensíveis de verificação de idade/identidade (CPF, telefone, nascimento). Separado de profiles de propósito — profiles é legível por qualquer usuário autenticado, isto não.';

ALTER TABLE public.profile_kyc ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir leitura do próprio KYC" ON public.profile_kyc;
CREATE POLICY "Permitir leitura do próprio KYC"
  ON public.profile_kyc FOR SELECT
  USING (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────────────────
-- 3) handle_new_user: mesmo corpo do 15 (profiles + wallet), acrescentando
--    a validação de +18 e CPF antes de fechar a transação de cadastro.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_birth_date date;
  v_cpf_digits text;
  v_age int;
BEGIN
  INSERT INTO public.profiles (id, username, full_name, created_at, updated_at)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'player_' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'full_name',
    now(),
    now()
  );

  INSERT INTO public.wallets (user_id, balance, locked_balance, updated_at)
  VALUES (new.id, 0.00, 0.00, now());

  -- Verificação de idade — só roda se o cadastro trouxe birth_date (fluxo de
  -- e-mail/senha). Login social (Google) não coleta isso ainda — lacuna
  -- conhecida, ver comentário no topo do arquivo.
  IF nullif(trim(coalesce(new.raw_user_meta_data->>'birth_date', '')), '') IS NOT NULL THEN
    BEGIN
      v_birth_date := (new.raw_user_meta_data->>'birth_date')::date;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'INVALID_BIRTH_DATE: Data de nascimento inválida.';
    END;

    IF v_birth_date > current_date THEN
      RAISE EXCEPTION 'INVALID_BIRTH_DATE: Data de nascimento inválida.';
    END IF;

    v_age := extract(year FROM age(current_date, v_birth_date));
    IF v_age < 18 THEN
      RAISE EXCEPTION 'UNDERAGE: A ArenaX1 é restrita a maiores de 18 anos.';
    END IF;
  END IF;

  -- Verificação de CPF — mesma condição: só roda se veio no cadastro.
  IF nullif(trim(coalesce(new.raw_user_meta_data->>'cpf', '')), '') IS NOT NULL THEN
    v_cpf_digits := regexp_replace(new.raw_user_meta_data->>'cpf', '[^0-9]', '', 'g');

    IF NOT public.fn_is_valid_cpf(v_cpf_digits) THEN
      RAISE EXCEPTION 'INVALID_CPF: CPF inválido.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.profile_kyc WHERE cpf = v_cpf_digits) THEN
      RAISE EXCEPTION 'CPF_ALREADY_USED: Este CPF já está cadastrado em outra conta.';
    END IF;

    INSERT INTO public.profile_kyc (id, cpf, phone, birth_date)
    VALUES (
      new.id,
      v_cpf_digits,
      nullif(trim(coalesce(new.raw_user_meta_data->>'phone', '')), ''),
      v_birth_date
    );
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
