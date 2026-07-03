# TODO & Ideias (Roadmap do Projeto)

## 📌 Tarefas Imediatas (Setup Inicial)
- [x] Inicializar o repositório Git para o projeto.
- [x] Configurar o projeto Frontend (Vue 3 + Vite + Tailwind CSS).
- [x] Configurar o projeto Backend (Python + FastAPI).
- [x] Configurar o projeto no Supabase (Banco de dados e Autenticação).
- [x] Definir e criar a estrutura inicial do banco de dados (Tabelas de Usuários, Partidas, Carteiras).
- [x] Integrar o gateway de pagamento (Pix) e criar webhook para depósitos.

## 🏆 Torneio de Sofá (Porta de Entrada / Growth) — Backend a construir
> Funil de aquisição com fricção zero: o anfitrião (único com conta) monta um torneio presencial em segundos. Ferramenta gratuita que vira receita via upsell para disputa por dinheiro real.

### 1. Motor de Torneios (Core)
- [ ] **Modelo de dados:** Tabelas `tournaments`, `tournament_participants` (jogadores avulsos por nome, sem conta), `tournament_matches`, `match_events` (gols, cartões).
- [ ] **Criação rápida:** Endpoint para criar torneio com 4/8/16 jogadores informando apenas os nomes (somente o host autenticado).
- [ ] **Geração de chave:** Algoritmo de chaveamento automático para **Mata-Mata (eliminação direta)** e **Fase de Grupos** (sorteio + tabela).
- [ ] **Gestão de partidas:** Endpoint para inserir placar; avanço automático da chave para a próxima fase ao concluir a partida.

### 2. Motor de Viralização (Estatísticas & Compartilhamento)
- [ ] **Estatísticas automáticas:** Cálculo de Artilheiro, Melhor Ataque, Pior Defesa e líder de Cartões a partir dos `match_events`.
- [ ] **Card do Campeão:** Geração server-side de uma imagem (estilo Ultimate Team) com stats do vencedor — formato vertical ideal para Stories do Instagram.
- [ ] **Gancho orgânico:** Card exportado com logo da ArenaX1 + texto/QR Code automático ("Escaneie e me desafie valendo Pix na ArenaX1").

### 3. Upsell para o Pago (Conversão)
> Decisão (02/07): não existirá "Torneio Online Grátis" — Torneio Online só terá a versão paga. Torneio Local (presencial, grátis) continua existindo normalmente.
- [ ] **Torneio Online Pago:** cada jogador entra remotamente pelo link/QR do torneio (sem estar no mesmo sofá), com inscrição em dinheiro real (define taxa de inscrição / valor do pote).
- [ ] **Onboarding por QR Code:** Gerar QR Code grande que leva os amigos da sala a um cadastro rápido + **Pix Copia e Cola** do valor definido.
- [ ] **Cashback do Host (indicação):** Ao fechar o pote, depositar cashback instantâneo na carteira do anfitrião (regra de bônus configurável).
- [ ] **Custódia:** Reaproveitar o fluxo de carteira protegida (fundos retidos pela plataforma até a distribuição final dos prêmios) — regra de reembolso já documentada na memória do projeto (`torneio-de-sofa`).

### 4. Ferramentas Extras de Captação (sem login)
- [ ] **Roleta de Times:** Sorteio de qual time cada jogador vai usar (evita briga por PSG/Real).
- [ ] **Roleta de Draft:** Distribuição de jogadores entre capitães.
- [ ] **Gerador de Chave avulso:** Montar e exportar um chaveamento sem precisar criar conta.

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
