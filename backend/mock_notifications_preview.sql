-- QA VISUAL — NÃO é migração de schema, não faz parte da sequência numerada
-- (01, 02, 03...). Só insere notificações de mentirinha pra você ver como
-- cada tipo novo fica no sino do app de verdade antes de aprovar. Rode no
-- SQL Editor do Supabase depois do 17_challenge_and_wallet_notifications.sql.
--
-- Por padrão mira na sua própria conta (a que está com is_admin = true,
-- configurada no 10_admin_portal.sql). Se não for a conta certa, troque a
-- linha do v_user_id abaixo por:
--   SELECT id INTO v_user_id FROM auth.users WHERE email = 'seu@email.com';
--
-- Os valores em R$ nas mensagens são só texto — não mexem no saldo real da
-- carteira, é puramente visual. Depois de aprovar, apague com o DELETE no
-- final do arquivo (comentado).

DO $$
DECLARE
  v_user_id uuid;
  v_challenge_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM public.profiles WHERE is_admin = true LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Nenhum perfil com is_admin = true encontrado — ajuste v_user_id manualmente no topo deste bloco.';
  END IF;

  -- Reaproveita um desafio real seu (se existir) pra testar o deep-link
  -- pra /match/:id igualzinho ao que acontece em produção.
  SELECT id INTO v_challenge_id
  FROM public.challenges
  WHERE creator_id = v_user_id OR opponent_id = v_user_id
  ORDER BY created_at DESC LIMIT 1;

  INSERT INTO public.notifications (user_id, type, title, body, challenge_id, created_at) VALUES
    (v_user_id, 'deposit_confirmed', 'Depósito confirmado 💰',
      'Seu depósito de R$ 50.00 caiu na carteira. Saldo atual: R$ 150.00.',
      null, now() - interval '2 minutes'),

    (v_user_id, 'withdraw_completed', 'Saque realizado ✅',
      'Seu saque de R$ 80.00 via Pix foi processado e enviado para a chave informada.',
      null, now() - interval '20 minutes'),

    (v_user_id, 'challenge_accepted', 'Desafio aceito ⚔️',
      'joaozinho topou sua aposta de R$ 20.00 em EA FC 26. Combinem sala e horário no chat.',
      v_challenge_id, now() - interval '40 minutes'),

    (v_user_id, 'challenge_result_pending', 'Sua vez de reportar ⏳',
      'mariasilva já reportou o resultado do desafio em EA FC 26. Confirma o que aconteceu pra liberar o pote.',
      v_challenge_id, now() - interval '3 hours'),

    (v_user_id, 'challenge_win', 'Você venceu 🏆',
      'Vitória confirmada no desafio de eFootball. R$ 36.00 caíram na sua carteira.',
      v_challenge_id, now() - interval '1 day'),

    (v_user_id, 'challenge_loss', 'Resultado confirmado',
      'Derrota confirmada no desafio de EA FC 25. R$ 20.00 saíram da sua carteira.',
      v_challenge_id, now() - interval '1 day 6 hours'),

    (v_user_id, 'challenge_disputed', 'Resultado em disputa ⚠️',
      'Os resultados do desafio de EA FC 26 bateram de frente e foram pra mediação da ArenaX1.',
      v_challenge_id, now() - interval '5 minutes');

  RAISE NOTICE 'Notificações de teste inseridas para user_id = %', v_user_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Limpeza: depois de olhar e aprovar, apague só as notificações de teste —
-- identificadas pelos nomes fictícios que não existem na sua base real.
-- Rode logo em seguida ao QA, antes que notificações de verdade desses
-- mesmos tipos comecem a chegar (senão o filtro por nome fica menos preciso).
-- ─────────────────────────────────────────────────────────────────────────
-- DELETE FROM public.notifications
-- WHERE type IN (
--   'deposit_confirmed', 'withdraw_completed', 'challenge_accepted',
--   'challenge_result_pending', 'challenge_win', 'challenge_loss', 'challenge_disputed'
-- )
-- AND (body LIKE '%R$ 50.00%' OR body LIKE '%joaozinho%' OR body LIKE '%mariasilva%');
