# Telas do Sistema (real, `frontend/src/router/index.ts`)

> Atualizado em 15/07/2026. A versão anterior era um plano de 6 telas
> escrito antes da maior parte do sistema existir — várias descrições não
> batem mais com o fluxo real (ex.: desafio não tem "aceitar direto",
> torneio de sofá e portal de admin nem existiam). Isto aqui é o
> inventário real, agrupado por layout.

## Público (`PublicLayout` — sem login)

- **Landing (`/`):** hero com prêmio "ao vivo", barra de stats, desafios
  abertos, "Como funciona" em 4 passos, torneios em destaque,
  classificação, seção Torneio de Sofá, seção "Por que a ArenaX1"
  (cards com tilt 3D), ferramentas grátis, FAQ curto, CTA final.
- **Desafios (`/desafios`):** lobby público de desafios abertos (mesma
  tela usada logado, mas sem ações que exigem conta).
- **Torneios (`/torneios`, `/torneios/:id`):** listagem e detalhe de
  torneios online pagos.
- **Classificação (`/classificacao`):** ranking nacional.
- **Como Funciona (`/como-funciona`):** passo a passo, regras de
  validação/punição (ghosting, disputa, desconexão, ônus da prova) e
  FAQ completo (20 perguntas, componente `FaqAccordion.vue`).
- **Termos de Uso / Política de Privacidade (`/termos`, `/privacidade`):**
  renderizam `termos-de-uso.md`/`politica-de-privacidade.md` direto da
  raiz do repo via `marked` (`LegalView.vue`).
- **Login / Cadastro (`/login`, `/register`):** cadastro por e-mail/senha
  coleta CPF, telefone e data de nascimento (validados no backend — ver
  `regras-do-sistema.md` §1) ou login/cadastro via Google (sem essa
  verificação ainda).

## Autenticado (`DashboardLayout`, `meta: requiresAuth`)

- **Painel (`/dashboard`):** home logada.
- **Carteira (`/wallet`):** saldo disponível vs. travado (com
  detalhamento de onde vem cada real congelado), aba Depósito (breakdown
  valor + taxa de R$0,99 + total, QR Pix real via Mercado Pago) e aba
  Saque (chave Pix + valor, fica pendente até confirmação manual de
  admin), extrato completo.
- **Desafios (`/challenges`) / Criar Desafio (`/create-challenge`):**
  mesmo lobby da versão pública + formulário de criação.
- **Torneios (`/tournaments`) / Criar Torneio (`/create-tournament`):**
  cobre tanto Torneio Online Pago quanto Torneio de Sofá (grátis,
  presencial, participantes avulsos só por nome).
- **Meus Torneios / Chaveamento (`/my-tournaments/:id`):** bracket do
  Torneio de Sofá que o usuário está hospedando.
- **Partida (`/match/:id`):** tela da partida em si — confirmar presença
  ("Iniciar partida", 15 min), reportar resultado (Ganhei/Perdi),
  reportar problema (motivo estruturado), chat direto com o oponente
  (Supabase Realtime).
- **Classificação (`/ranking`):** mesma tela pública, versão logada.
- **Perfil (`/profile/:username`):** perfil público de um jogador
  (Fair Play Rating, histórico, selo de abandono se aplicável).
- **Configurações (`/settings`):** dados da conta, desativar/excluir
  conta (dois fluxos distintos, ver `regras-do-sistema.md` §6).
- **Menu (`/menu`):** versão em tela cheia do menu (substitui painel
  deslizante no mobile).
- **Suporte (`/support`, `/support/:id`):** abrir ticket e ver a
  conversa/thread (mesma tela serve usuário e admin).

## Portal de Admin (dentro do `DashboardLayout`, requer `is_admin`)

- **Visão Geral (`/admin`):** métricas + atalhos com contador ao vivo
  pras três filas abaixo.
- **Disputas (`/admin/disputes`):** disputas de torneio online abertas,
  aguardando decisão.
- **Suporte (`/admin/support`):** fila de tickets de suporte por status.
- **Saques (`/admin/withdrawals`):** fila de saques pendentes — confirmar
  (já mandou o Pix manualmente) ou rejeitar com motivo (estorna o
  usuário). Adicionado nesta atualização — o Mercado Pago não manda Pix
  pra chave de terceiro via API, então esse fluxo é sempre manual.

## O que ficou de fora do plano original e não existe

- "Tribunal do X1" como conceito de suporte — virou sistema de ticket
  normal (`support_tickets`), sem nome próprio na UI.
- Card do Campeão / Roleta de Times / Roleta de Draft como ferramentas
  standalone — hoje só existem como texto de marketing na landing, sem
  tela ou endpoint próprio (ver lacuna anotada em `TODO.md`).
