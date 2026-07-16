-- Execute este script no SQL Editor do seu painel Supabase (depois do 35).
--
-- Objetivo: fechar o ACHADO-05 do teste geral — a verificação de idade/CPF do
-- cadastro (32) só rodava SE os campos viessem preenchidos no metadata. Uma
-- chamada crua ao /auth/v1/signup que simplesmente OMITISSE birth_date/cpf
-- criava a conta sem nenhuma checagem de maioridade (Lei 15.211/2025) nem CPF.
--
-- Correção: no cadastro por E-MAIL/SENHA (provider 'email'), birth_date e cpf
-- passam a ser OBRIGATÓRIOS — se faltarem, a conta inteira não é criada
-- (o trigger roda na mesma transação do signup). O RegisterView.vue já coleta
-- e envia os dois, então o fluxo real não muda; só a porta dos fundos fecha.
--
-- Login social (Google, provider 'google') continua isento — não há como
-- coletar CPF/nascimento no signup do OAuth. Essa é a MESMA lacuna já
-- documentada no 32, mantida de propósito até existir um fluxo de KYC
-- pós-cadastro (ver visao-do-sistema.md §6). A diferença é que agora ela é a
-- ÚNICA porta sem verificação, em vez de qualquer requisição que omita campos.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_provider text;
  v_is_email_signup boolean;
  v_birth_raw text;
  v_cpf_raw text;
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

  -- Cadastro por e-mail/senha exige KYC; OAuth (Google) fica isento (lacuna
  -- conhecida, ver cabeçalho). provider null é tratado como e-mail (mais
  -- restritivo por padrão — nunca deixa passar por ambiguidade).
  v_provider := new.raw_app_meta_data->>'provider';
  v_is_email_signup := (v_provider IS NULL OR v_provider = 'email');

  v_birth_raw := nullif(trim(coalesce(new.raw_user_meta_data->>'birth_date', '')), '');
  v_cpf_raw   := nullif(trim(coalesce(new.raw_user_meta_data->>'cpf', '')), '');

  IF v_is_email_signup AND v_birth_raw IS NULL THEN
    RAISE EXCEPTION 'BIRTH_DATE_REQUIRED: Informe sua data de nascimento para se cadastrar.';
  END IF;
  IF v_is_email_signup AND v_cpf_raw IS NULL THEN
    RAISE EXCEPTION 'CPF_REQUIRED: Informe seu CPF para se cadastrar.';
  END IF;

  -- Verificação de idade (roda sempre que houver birth_date — obrigatório no
  -- e-mail, opcional no OAuth).
  IF v_birth_raw IS NOT NULL THEN
    BEGIN
      v_birth_date := v_birth_raw::date;
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

  -- Verificação de CPF (mesma condição).
  IF v_cpf_raw IS NOT NULL THEN
    v_cpf_digits := regexp_replace(v_cpf_raw, '[^0-9]', '', 'g');

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
