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

## Próximos Passos
- Implementar o lobby e o fluxo de criação/aceitação de Desafios (matchmaking).
- Construir o fluxo de duplo check de resultados de partidas no Frontend/Backend.
- Criar a interface de disputas/chat de mediação e o suporte a envio de arquivos/comprovantes.
