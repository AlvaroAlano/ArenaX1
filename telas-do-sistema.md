# O Plano de Telas (UI/UX) do Novo Sistema

A arquitetura do front-end será dividida em 6 telas principais, desenhadas para fluir de forma lógica:

## Tela 1: Dashboard (A Nova Home)
- **Header:** Saldo atual em R$ bem visível e botão "Depositar / Sacar".
- **Hero Section:** Um banner de destaque ("Pronto para o X1?").
- **Feed Rápido:** Uma lista horizontal (carrossel) mostrando os últimos resultados ao vivo (Ex: "João ganhou R$ 20 de Pedro no EA FC 25"), gerando prova social.
- **Ações Rápidas:** Botão gigante para "Criar Desafio".

## Tela 2: Desafios (O Lobby)
- **Filtros Inteligentes:** Abas para "Meus Desafios", "Salas Abertas", "Em Andamento" e "Histórico".
- **Cards de Partida:** Limpos (verde/azul). Mostram o valor da aposta, a plataforma, o botão de "Aceitar Desafio" e o botão de "Compartilhar (WhatsApp)".
- **Ação:** Ao clicar em um desafio em andamento, abre-se a tela de "Reportar Resultado" (Botões grandes: "Eu Venci" ou "Eu Perdi").

## Tela 3: Torneios (A Competição)
- **Visualização em cards:** Com o número de vagas (Ex: 3/8 preenchidas), valor da inscrição (Ex: R$ 10) e Prêmio Total (Ex: R$ 70).
- **Chaveamento (Bracket):** Dentro do torneio, uma visualização simples de chaveamento, estilo mata-mata.

## Tela 4: Classificação (Leaderboard)
- Ranking focado nos "Reis do X1".
- **Métricas principais:** Número de vitórias, Lucro total (opcional, pode ser oculto por privacidade) e a Nota de Fair Play (5 estrelas).

## Tela 5: Carteira (O Motor Financeiro)
- Tela exclusiva para o dinheiro.
- **Aba Depósito:** Gera o QR Code Pix na tela com valores rápidos (R$ 10, R$ 20, R$ 50).
- **Aba Saque:** Campo para colar a Chave Pix e botão de retirada (com indicação de saldo liberado).
- **Extrato:** Histórico de "Aposta X", "Vitória Y", "Taxa da Plataforma".

## Tela 6: Como Funciona & Regras
- Uma versão simplificada e direta das regras da plataforma.
- Explicando claramente o "Duplo Check".
- Detalhando as punições por mentir o resultado.
- Instruções de como acionar o "Tribunal do X1" (Suporte) em caso de disputas.
