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

## Próximos Passos
- Estruturação inicial do projeto (criação de repositórios e configuração base do stack).
- Divisão de trabalho para a equipe de duas pessoas.
