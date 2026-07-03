-- Execute este script no SQL Editor do seu painel Supabase.
--
-- Agora que create/accept/report rodam via funções SECURITY DEFINER
-- chamadas pelo backend (service_role, que ignora RLS), o client autenticado
-- não tem mais nenhum motivo legítimo para dar UPDATE direto em `challenges`.
-- A policy antiga permitia isso sem restringir coluna nenhuma: um usuário
-- podia, via supabase-js no próprio navegador, setar status='completed' e
-- winner_id=si mesmo, pulando toda a lógica de rake/carteira. Removendo.
DROP POLICY IF EXISTS "Permitir atualização de desafios pelos participantes" ON public.challenges;

-- Pelo mesmo motivo, wallets e transactions nunca devem ser escritas pelo
-- client — só possuem policy de SELECT hoje, o que já está correto
-- (nenhuma policy de INSERT/UPDATE existe para essas tabelas, então o
-- comportamento padrão do RLS — negar — já se aplica). Este bloco só
-- documenta a garantia, sem alterar nada.
