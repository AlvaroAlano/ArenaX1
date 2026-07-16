# Memória do Projeto

## Visão Geral
Plataforma Web multiplataforma de skill-based gaming para futebol virtual (EA FC / eFootball) focada no público brasileiro, utilizando Pix e evitando taxas internacionais.

## Stack Definida
- **Frontend:** Vue.js 3 + Vite, Tailwind CSS (PWA e Desktop).
- **Backend:** Python + FastAPI + Uvicorn (WebSockets).
- **Banco e Auth:** Supabase (PostgreSQL).

## Decisões e Padrões
- Design focado em usabilidade, sem padrão "cassino", inspirado na UI do EA FC.
- Sem taxa de depósito/saque; monetização via Rake sobre potes.
- Validação de partidas via duplo check com fluxo de mediação via chat/comprovantes.
- Arquitetura de UI dividida em 6 telas principais (Dashboard, Desafios, Torneios, Classificação, Carteira, Regras).
- Criado schema inicial do Supabase (profiles, wallets, challenges, transactions, disputes, dispute_messages) com trigger de sincronização automatizada a partir do auth.users.
- Habilitado Row Level Security (RLS) em todas as tabelas com políticas de acesso restritas (acesso financeiro apenas via backend/service_role; dados de partidas e chats vinculados ao auth.uid()).
- Implementada Autenticação (Login/Cadastro) no Frontend com Pinia e proteção de rotas (Navigation Guards).
- Integrado o fluxo financeiro do Pix (Backend FastAPI + Webhook e Carteira Realtime no Frontend com Vue 3).
- Implementado o novo visual da Landing Page, extraindo estrutura HTML bruta e componentizando em Vue com Tailwind (tema Laranja/Preto, dark mode e fonte Lexend), criando layouts públicos reutilizáveis e as telas: Inicial, Desafios (pública), Torneios, Classificação e Como Funciona.
- **Landing reescrita (saindo do clone do template "the1vs1"):** estrutura original premium dark-fintech com herói full-bleed (render da arena `hero-3d.png`), parallax sutil, glassmorphism, scroll-reveal via IntersectionObserver e `prefers-reduced-motion` respeitado. Sistema de cor definido: **azul `#3b82f6` = primário (confiança/fintech)** e **laranja `#FF5A36` = accent (energia/destaque)**, espelhando o duplo-neon do render. Tokens `accent`/`accent-hover`/`accent-soft` + sombras `glow-primary`/`glow-accent` adicionados ao `tailwind.config.js`. Mantida a fonte Lexend (limpa) em vez de fonte "gamer" agressiva, reforçando o anti-visual-de-aposta.
- Adicionada a seção **"Torneio de Sofá"** na landing (chaveamento mockup + card do campeão estilo Ultimate Team + upsell de QR Code/Pix + ferramentas grátis). Roadmap de backend correspondente registrado no `TODO.md`.
## Decisões de 14/07/2026 (revisão comparativa com operador concorrente)
- Ao revisar o Termos de Uso de um operador comparável no mercado
  brasileiro (mesmo nicho: recompensa por desempenho em jogos eletrônicos,
  Pix, KYC), duas cláusulas dele foram avaliadas e **conscientemente não
  adotadas**: (a) confisco total de saldo (incluindo valor depositado pelo
  próprio usuário) em caso de fraude comprovada — mantida a regra atual da
  ArenaX1, que só reverte os ganhos obtidos via fraude, nunca o saldo
  depositado (ver `termos-de-uso.md`, Seção 8.6); (b) taxa de administração
  mensal sobre contas inativas — não adotada, risco de questionamento sob o
  CDC.
- Adicionada ao `termos-de-uso.md` (Seção 8.4) proibição explícita de
  transferência de saldo entre contas de usuários fora do resultado normal
  de um desafio/torneio, e proibição de perder partidas de propósito para
  obter adversários mais fracos.

## Próximos Passos
- **Backend do Torneio de Sofá** (ver `TODO.md`): motor de torneios (4/8/16, mata-mata/grupos), estatísticas automáticas, Card do Campeão, upsell por QR Code/Pix com cashback do host e ferramentas avulsas (Roleta de Times/Draft).
- Implementar o lobby e o fluxo de criação/aceitação de Desafios (matchmaking).
- Construir o fluxo de duplo check de resultados de partidas no Frontend/Backend.
- Criar a interface de disputas/chat de mediação e o suporte a envio de arquivos/comprovantes.
