# TODO & Ideias (Roadmap do Projeto)

## 📌 Tarefas Imediatas (Setup Inicial)
- [x] Inicializar o repositório Git para o projeto.
- [x] Configurar o projeto Frontend (Vue 3 + Vite + Tailwind CSS).
- [x] Configurar o projeto Backend (Python + FastAPI).
- [x] Configurar o projeto no Supabase (Banco de dados e Autenticação).
- [x] Definir e criar a estrutura inicial do banco de dados (Tabelas de Usuários, Partidas, Carteiras).
- [x] Integrar o gateway de pagamento (Pix) e criar webhook para depósitos.

## 💡 Ideias de Produto e Engajamento (Backlog)
- [ ] **Sistema de Divisões/Patentes:** Implementar um ranking (Bronze, Prata, Ouro, Elite) baseado nos resultados dos usuários.
- [ ] **Histórico H2H (Head-to-Head):** Exibir os confrontos diretos passados ao desafiar um usuário específico.
- [ ] **Cronômetro de W.O:** Adicionar um timer na partida ativa para permitir reivindicação automática de vitória se o adversário não interagir.

## 🛡️ Ideias de Segurança e Mediação
- [ ] **Tribunal da Comunidade:** Criar uma interface para que jogadores confiáveis ajudem a julgar disputas de partidas, sendo recompensados com % do Rake.
- [ ] **Validação KYC:** Atrelar o CPF da chave Pix ao usuário, evitando contas fakes e reincidentes de fraudes.

## ⚙️ Arquitetura e Performance
- [ ] **Realtime do Supabase:** Utilizar o Supabase Realtime no Frontend para o chat e feed ao vivo, diminuindo a carga sobre o FastAPI.
- [ ] **Fila de Processamento (Redis/Celery):** Implementar filas no Backend para processar os Webhooks do gateway de pagamento, garantindo idempotência e prevenindo saldo duplicado.
