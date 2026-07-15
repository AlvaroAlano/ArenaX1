# Documento de Visão do Sistema: ArenaX1

> Atualizado em 15/07/2026 para refletir o sistema como ele realmente
> funciona hoje (código + `regras-do-sistema.md`), não como planejado
> originalmente. Ver esse último para o detalhamento regra a regra —
> este documento é a visão geral, não a fonte de verdade de negócio.

## 1. O Conceito Central (O Elevador Pitch)

Uma plataforma web (com PWA instalável) de competição de habilidade focada
no público brasileiro de futebol virtual (EA FC 25/26, eFootball) em
consoles (PS5/Xbox) ou PC. Jogadores desafiam-se em partidas 1v1 e torneios
valendo dinheiro real via Pix — o resultado financeiro depende
exclusivamente do desempenho na partida, nunca de sorteio ou evento de
terceiros (posicionamento formal em `termos-de-uso.md`, Seção 1.3-A).

## 2. A Proposta de Valor (O Diferencial)

- **Pix nativo, sem conversão de moeda:** depósito e saque em reais, sem
  fricção de gateway internacional.
- **Acessível em qualquer tela:** responsivo, com PWA instalável no celular.
- **Fair Play com prova:** sistema de reputação separado de conduta
  (Fair Play Rating) e de presença (contador de ausência), mediação de
  disputas com prova em foto/vídeo, e retenção temporária de prêmio em
  caso de aceite automático — ninguém saca antes que o prazo de contestação
  passe.
- **Torneio de Sofá grátis:** funil de aquisição sem fricção — só o
  anfitrião precisa de conta, os demais participantes entram só pelo nome,
  sem envolver dinheiro real.
- **Identidade visual própria:** dark mode verde-limão (`#C8F03C` sobre
  `#15181e`), tipografia Archivo/Inter — deliberadamente distante da
  estética "cassino neon".

## 3. A Jornada do Usuário (O Fluxo de Valor Real)

- **Cadastro:** e-mail/senha (com CPF, telefone e data de nascimento
  obrigatórios — validados no banco, não só na tela) ou login Google
  (ainda sem essa verificação — ver `regras-do-sistema.md` §1 e a nota de
  lacuna conhecida abaixo). Menor de 18 anos é bloqueado no próprio
  cadastro.
- **Depósito:** gera um Pix real via Mercado Pago. O valor pedido soma uma
  taxa de R$ 0,99 (ex.: pede R$ 50, paga R$ 50,99, recebe R$ 50,00
  líquidos na carteira). Crédito é automático via webhook assim que o
  pagamento é aprovado.
- **Desafio 1v1:** o criador define jogo/plataforma/valor. Outros jogadores
  **solicitam entrada** (não existe "aceitar direto") — o criador escolhe
  um solicitante, e só aí o saldo dos dois é travado. Ambos têm 15 minutos
  pra confirmar presença ("Iniciar partida"); passou o prazo sem os dois
  confirmarem, cancela e devolve.
- **A Partida:** acontece fora da plataforma (PSN/Xbox Live/EA App), sem
  vínculo técnico com o jogo em si.
- **Reporte e validação:** cada lado tem 24h pra reportar "Ganhei"/"Perdi".
  Bateu, paga na hora. Só um lado reportou, o prazo vence e aquele
  resultado é aceito automaticamente — mas o prêmio fica **retido por 3
  dias** antes de virar sacável, janela em que o lado silencioso ainda
  pode contestar. Resultados divergentes vão pra mediação com prova
  (foto/vídeo).
- **Torneios:** Online Pago (mata-mata de 4/8/16, chave sorteada ao
  encher as vagas, premiação escalonada por colocação) ou Torneio de Sofá
  (grátis, presencial, sem dinheiro real).
- **Saque:** pede o valor e a chave Pix — a carteira é debitada na hora
  (evita saque duplicado), mas o envio **não é automático**: a API do
  Mercado Pago não manda Pix pra chave de terceiro, então um admin
  confirma manualmente pelo painel `/admin/withdrawals` depois de
  transferir pelo próprio banco. Se rejeitado, o valor volta pro saldo do
  usuário.

## 4. Arquitetura e Stack Tecnológica

- **Frontend:** Vue 3 + Vite + TypeScript, Tailwind CSS (design tokens em
  `tailwind.config.js` — verde-limão mono, sem CSS-in-JS), Pinia para
  estado global (auth, toast, confirm, wallet), Vue Router. PWA via
  `vite-plugin-pwa`. Hospedado na **Vercel**.
- **Backend:** Python + FastAPI + Uvicorn. É uma API REST **stateless**,
  sem WebSocket — chat de partida e atualização de saldo em tempo real
  passam direto pelo **Supabase Realtime** a partir do frontend, sem
  tocar no backend (decisão deliberada pra tirar carga do servidor
  Python). O backend cuida das ações que mexem em dinheiro/estado (criar
  desafio, depositar, sacar, reportar resultado, ações de admin) e do
  polling de notificações (a cada 30s). Hospedado no **Render**.
- **Banco de dados & Autenticação:** Supabase (PostgreSQL). Toda escrita
  de saldo passa por função Postgres `SECURITY DEFINER` chamada só pelo
  backend com `service_role` — o client nunca escreve saldo direto (RLS
  fecha `authenticated`/`anon` pra `INSERT`/`UPDATE` nas tabelas
  financeiras). Jobs agendados (timeout de partida, liberação de prêmio
  retido, exclusão de conta) rodam via `pg_cron` dentro do próprio
  Supabase, não no backend.
- **Gateway financeiro:** Mercado Pago (API de Pagamentos Pix) para
  **depósito**, com verificação de assinatura HMAC no webhook. O
  **saque** é manual por decisão de arquitetura (ver Seção 3) — a API
  pública do Mercado Pago não oferece envio de Pix a chave de terceiro.
- **Domínio + hospedagem:** os três gastos fixos de infra são domínio,
  Render (backend) e, se necessário no futuro, upgrade do Supabase pra
  Pro (a versão free não tem backup automático — risco real pra um
  sistema com dinheiro de verdade).

## 5. Modelo de Negócio (Monetização)

- **Comissão (rake):** 8% sobre o total apostado no desafio 1v1 (o
  vencedor leva 1,84× o valor apostado); 10% sobre o total arrecadado em
  inscrições de torneio pago. Cobrada só quando o prêmio é efetivamente
  liberado — nunca sobre desafio cancelado ou revertido por disputa.
- **Taxa de depósito:** R$ 0,99 por depósito via Pix, somada ao valor
  pedido e mostrada antes da confirmação (cláusula 4.4 do
  `termos-de-uso.md`). **Não existe taxa de saque.**
- Valores mínimos: depósito R$ 10, desafio/inscrição de torneio R$ 1.

## 6. O que ainda não existe (lacunas conhecidas, não escondidas)

- **Verificação de idade/CPF só no cadastro por e-mail/senha.** Login via
  Google não passa por essa validação ainda — pendência de um fluxo de
  KYC pós-cadastro pra esse caminho.
- **Matching de titularidade CPF-chave-Pix no saque** — decidido, não
  implementado (antifraude barato via API do gateway, adiado de
  propósito junto com KYC pago).
- **"Card do Campeão" e "Roleta de Times/Draft"** aparecem como texto de
  marketing na landing page, mas não têm implementação real (nem backend
  nem tela própria) — só o motor de chaveamento/placar do Torneio de Sofá
  em si é real. Vale corrigir a copy ou construir a funcionalidade antes
  de crescer a divulgação disso.
- **Fila de processamento assíncrono (Redis/Celery)** pros webhooks de
  pagamento não existe — hoje a idempotência é garantida na camada do
  banco (índice único + `SELECT ... FOR UPDATE`), suficiente pra
  correção, mas não pra alto throughput.
- Ver `TODO.md` para o backlog completo e `mapa-riscos-legais.md` para a
  pendência de validação jurídica da classificação legal da atividade
  (habilidade vs. aposta).
