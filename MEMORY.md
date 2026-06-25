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

## Próximos Passos
- Integrar o gateway de pagamento (Pix) e criar webhook de depósitos no backend.
- Construir a autenticação básica no Frontend (Vue 3) conectando com o Supabase Auth.
