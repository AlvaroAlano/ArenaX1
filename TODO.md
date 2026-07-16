# TODO & Ideias (Roadmap do Projeto)

> Atualizado em 15/07/2026 — checkboxes conferidos contra o código real,
> não só contra a memória do que foi planejado.

## 📌 Tarefas Imediatas (Setup Inicial)
- [x] Inicializar o repositório Git para o projeto.
- [x] Configurar o projeto Frontend (Vue 3 + Vite + Tailwind CSS).
- [x] Configurar o projeto Backend (Python + FastAPI).
- [x] Configurar o projeto no Supabase (Banco de dados e Autenticação).
- [x] Definir e criar a estrutura inicial do banco de dados (Tabelas de Usuários, Partidas, Carteiras).
- [x] Integrar o gateway de pagamento (Pix) e criar webhook para depósitos — **Mercado Pago real**, com taxa de R$0,99 e webhook com verificação de assinatura HMAC (14/07).

## 🏆 Torneio de Sofá (Porta de Entrada / Growth)
> Funil de aquisição com fricção zero: o anfitrião (único com conta) monta um torneio presencial em segundos. Ferramenta gratuita que vira receita via upsell para disputa por dinheiro real.

### 1. Motor de Torneios (Core) — ✅ implementado
- [x] **Modelo de dados e endpoints reais** (`backend/tournaments.py`): criar torneio local só com nomes (`POST /create`), inserir placar (`POST /submit-result`), listar (`GET /my-tournaments`, `GET /{id}`).
- [x] **Torneio Online Pago também real**: `POST /online/create`, `GET /online/open`, `POST /online/join`, `POST /online/leave`, `POST /online/submit-result` — mata-mata de 4/8/16, prêmio escalonado por colocação (ver `regras-do-sistema.md` §5.1).

### 2. Motor de Viralização (Estatísticas & Compartilhamento) — ⚠️ ainda não é real
- [ ] **Estatísticas automáticas** (Artilheiro, Melhor Ataque, Pior Defesa): hoje é **mock hardcoded** na landing page (`championStats` em `LandingViewV2.vue`), não calculado a partir de dados reais de partida.
- [ ] **Card do Campeão** (imagem gerada server-side): não implementado — a landing promete isso como feature, mas não existe tela nem endpoint.
- [ ] **Gancho orgânico** (card com QR pra Stories): depende do item acima.

### 3. Upsell para o Pago (Conversão)
- [x] **Torneio Online Pago** existe e funciona como produto próprio (não é "upgrade" do torneio de sofá, é fluxo separado — decisão de 02/07 mantida).
- [ ] **Onboarding por QR Code** direto de dentro de um torneio de sofá pro pago: não confirmado como fluxo implementado.
- [ ] **Cashback do Host:** não implementado.

### 4. Ferramentas Extras de Captação (sem login) — ⚠️ só existem como texto de marketing
- [ ] **Roleta de Times / Roleta de Draft / Gerador de Chave avulso:** aparecem como cards na landing page (`tools` em `LandingViewV2.vue`) mas **não têm tela nem lógica implementada** por trás. Isso é risco de propaganda enganosa se a divulgação crescer antes da feature existir de verdade — mesmo princípio já aplicado antes no projeto (não prometer o que não existe). Prioridade: ou constrói de verdade, ou ajusta a copy da landing.

## 💰 Mercado Pago / Carteira (pendências desta fase)
- [ ] **Depósito via cartão de crédito/débito:** hoje `backend/pix.py` só cria pagamento com `payment_method_id: "pix"` — cartão não é aceito, mesmo a API do Mercado Pago suportando (dá pra confirmar em sandbox com o cartão de teste deles, mas o backend rejeita/ignora porque só monta o payload de Pix). Requer tokenização de cartão no frontend (Checkout Bricks/SDK JS do MP, nunca número de cartão cru passando pelo nosso backend) + tratar parcelamento e taxas maiores que o Pix.
- [ ] **Automatizar o saque:** hoje é 100% manual (admin confirma depois de mandar o Pix pelo próprio banco), porque a API pública do Mercado Pago não manda Pix pra chave de terceiro. Se o volume justificar, avaliar um segundo provedor com Pix-out real (Efí/Gerencianet, Asaas, Celcoin) só pro saque.
- [ ] **KYC pós-cadastro pra login via Google:** a verificação de idade/CPF (implementada 15/07) só roda no cadastro por e-mail/senha — quem entra via Google ainda não passa por isso.
- [ ] **Matching de titularidade CPF-chave-Pix no saque:** decidido, não implementado (antifraude barata via API do gateway, ver `regras-do-sistema.md` §12). Diferente da validação de CPF no cadastro (essa já existe).
- [ ] **SMTP próprio pro Supabase Auth** (Resend/Postmark/etc.): o envio de e-mail compartilhado do Supabase tem rate limit curto — confirmado na prática ao testar cadastro em sequência. Vira problema real com volume de cadastro em produção.
- [ ] **Supabase Pro antes de operar com dinheiro real em escala:** o plano free não tem backup automático do banco — risco sério pra um sistema financeiro.
- [ ] Avaliar tornar `POST /api/pix/deposit` assíncrono (`async def` + `httpx.AsyncClient`) se o volume de depósito simultâneo crescer — hoje é síncrono e usa a pool de threads padrão do FastAPI.

## 💡 Ideias de Produto e Engajamento (Backlog)
- [ ] **Sistema de Divisões/Patentes:** Implementar um ranking (Bronze, Prata, Ouro, Elite) baseado nos resultados dos usuários. (Decisão anterior: não incluir na comunicação até existir de verdade.)
- [ ] **Histórico H2H (Head-to-Head):** Exibir os confrontos diretos passados ao desafiar um usuário específico.
- [ ] **Cronômetro de W.O. visível na tela:** o mecanismo de fundo já existe (timeout de 15min/24h com aceite automático e retenção, ver `regras-do-sistema.md` §3.3-3.5) — falta só a UI de contagem regressiva mais visível/clara pro usuário.

## 🛡️ Ideias de Segurança e Mediação
- [ ] **Tribunal da Comunidade:** ideia de backlog antiga — hoje a mediação é só via admin (`fn_resolve_challenge_dispute`/`fn_resolve_online_match_dispute`). Reavaliar se ainda faz sentido dado o modelo atual antes de priorizar.
- [x] **Validação de CPF no cadastro** (formato + dígito verificador + unicidade) — implementado 15/07, ver `backend/32_signup_age_cpf_validation.sql`. O que falta é só o matching CPF-chave-Pix no saque (item na seção Mercado Pago acima).

## ⚙️ Arquitetura e Performance
- [x] **Realtime do Supabase no Frontend** para chat de partida e atualização de saldo — confirmado: passa direto pelo Supabase, sem tocar no FastAPI/Render.
- [ ] **Fila de Processamento (Redis/Celery):** ainda não existe. A idempotência do webhook de pagamento já é garantida na camada do banco (índice único em `external_id` + `SELECT ... FOR UPDATE`) — isso resolve corretude, não throughput. Vale a pena só se o volume de webhooks simultâneos justificar.
