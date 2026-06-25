# Documento de Visão do Sistema: A Plataforma Definitiva de X1 no Brasil

## 1. O Conceito Central (O Elevador Pitch)
Uma plataforma Web multiplataforma de skill-based gaming focada no público brasileiro de futebol virtual (EA FC / eFootball) em consoles (PS5/Xbox) ou PC. O sistema permite que jogadores apostem dinheiro real em suas próprias partidas (1v1 e Torneios), resolvendo a maior dor do mercado atual: a lentidão e os custos de transações internacionais.

## 2. A Proposta de Valor (O Diferencial)
- **Acessibilidade Total (PC e Mobile):** O sistema será fluido, responsivo e otimizado tanto para quem usa no PC (navegador Desktop) quanto para quem acessa via celular (como PWA instalável).
- **Atrito Financeiro Zero:** Depósitos e saques instantâneos via Pix, sem taxas de conversão para Euro/Dólar.
- **Foco na "Resenha":** Geração de links de desafio nativos para compartilhamento em grupos de WhatsApp, Discord ou Telegram.
- **Design Profissional e Familiar:** Fuga do padrão "cassino neon/cyberpunk". A interface será focada em alta usabilidade, com a identidade visual e o layout inspirados diretamente na UI do EA FC (utilizando a mesma linguagem visual e disposição de elementos como modelo, sem cópias diretas). Isso cria um ambiente imersivo, transmitindo segurança de fintech e a vibração nativa dos esportes virtuais.
- **Resolução Rápida:** Suporte e mediação de disputas ágeis, com punição severa para fraudadores (banimento e perda de saldo).

## 3. A Jornada do Usuário (O Fluxo de Valor)
- **Onboarding:** O usuário acessa a plataforma (pelo PC ou Celular), cria a conta e tem acesso ao painel principal.
- **Aporte:** Clica em "Depositar", gera um Pix Copia e Cola e o saldo atualiza na tela em segundos via Webhook.
- **Matchmaking / Desafio:** 
  - Ele cria uma sala pública ou gera um link privado para enviar a um amigo.
  - O adversário aceita. O sistema congela o valor da aposta da carteira de cada um.
- **A Partida:** Eles se adicionam na rede correspondente (PSN / Xbox Live / Steam / EA App) e jogam a partida no videogame ou computador.
- **A Validação (Duplo Check):**
  - Ambos acessam a plataforma e reportam o resultado.
  - **Caminho Feliz:** Resultados batem, o vencedor recebe o pote na hora (descontado o rake).
  - **Disputa:** Resultados divergem. O pote fica retido, abre-se um chat de mediação onde anexam o vídeo/foto da tela comprovando a vitória.
- **Cash Out:** O vencedor clica em "Sacar", insere a chave Pix e o dinheiro cai na conta bancária dele imediatamente.

## 4. Arquitetura e Stack Tecnológica
A construção utiliza tecnologias modernas para garantir velocidade e confiabilidade.
- **Frontend (A Cara):** Vue.js 3 + Vite, com Tailwind CSS para garantir responsividade perfeita entre as versões Web Desktop e PWA Mobile.
- **Backend (O Motor):** Python com FastAPI e Uvicorn para alta performance e suporte a WebSockets (chat e feed em tempo real).
- **Banco de Dados & Autenticação:** Supabase (PostgreSQL).
- **Gateway Financeiro:** Integração via API para automatizar toda a esteira do Pix.

## 5. Divisão de Trabalho e Estruturação
A estrutura de desenvolvimento (quem faz o quê e como os blocos do sistema serão divididos) será mapeada e definida em uma etapa posterior, garantindo que a divisão de tarefas seja a mais eficiente possível para a equipe de duas pessoas.

## 6. O Modelo de Negócios (Monetização)
- **A Regra de Ouro:** Não há taxa para depósito, nem taxa para saque.
- **A Receita:** Cobrança de um Rake (Taxa da Plataforma) sobre o pote total de cada partida ou sobre o pote de inscrição dos torneios. O lucro escala com o volume de jogos, tornando o sistema altamente sustentável.
