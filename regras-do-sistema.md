# Regras do Sistema — ArenaX1 (referência completa)

> Documento de regras de negócio e funcionamento da plataforma. É a fonte de
> verdade sobre **como o sistema se comporta** — estados, prazos, dinheiro,
> punições, disputas. Complementa os docs de visão (`visao-do-sistema.md`),
> telas (`telas-do-sistema.md`) e design. Quando uma regra tem código, o
> arquivo/migração é citado entre parênteses.
>
> **Princípios inegociáveis** (guiam toda decisão abaixo):
> 1. **O usuário nunca pode ser lesado sem recurso** — todo movimento
>    automático de dinheiro é reversível dentro de uma janela.
> 2. **Punição a quem avacalha é reputacional, nunca financeira** — tirar
>    dinheiro de alguém como "multa" é risco jurídico. Dinheiro só se move como
>    resultado legítimo da aposta.
> 3. **Mutação de saldo é sempre atômica** — passa por função Postgres
>    `SECURITY DEFINER` com a carteira travada (`FOR UPDATE`), chamada só pelo
>    backend (`service_role`). O client nunca escreve saldo direto.
> 4. **Consequência reputacional por alegação de terceiro sempre passa por
>    admin.** Só um fato **100% verificável pelo próprio sistema** (ex.: a
>    confirmação de presença que não foi clicada no prazo) pode gerar
>    consequência automática — e, mesmo assim, com **janela de contestação**
>    antes de virar público. É por isso que denúncia de conduta vira disputa
>    (quem decide é o admin) e o contador de abandono, mesmo automático, só
>    exibe o selo depois da janela do item 1.4.

---

## 1. Contas e Perfil

### 1.1 Cadastro
- Login por e-mail/senha ou Google OAuth (Supabase Auth).
- Ao criar a conta, um trigger cria automaticamente o `profile` e a `wallet`
  zerada (`schema.sql`, `handle_new_user`).
- Campos do perfil: `username` (apelido público, único, exibido em todo canto),
  `full_name` (nome completo, privado-ish), `ea_id` (EA ID/Gamertag),
  `main_platform` (PS5/Xbox/PC/Crossplay), `fair_play_rating`,
  `abandoned_matches`.

### 1.2 Plataforma principal
- Configurada em Ajustes → Perfil (`main_platform`, migração `21`).
- Usada como **valor pré-selecionado** ao criar desafio/torneio — não impede
  escolher outra na hora.

### 1.3 Fair Play Rating (reputação de conduta)
- Escala 0–5, começa em 5.0.
- **Só cai por má conduta real:** mentir sobre resultado, trapaça, comportamento
  inadequado — sempre via decisão de mediação (admin). Cada resolução contra
  quem mentiu derruba **−1,5** (piso 0) (`26`, `09`).
- **Nunca cai por comportamento passivo** (não confirmar/reportar a tempo). O
  silêncio é esperado e inofensivo, não é misconduct.

### 1.4 Contador de abandono (reputação de presença) — separado do Fair Play
- `profiles.abandoned_matches` (migrações `26`/`27`). Punição **reputacional,
  não financeira**.
- **A contagem é 100% automática** e assim continua: um no-show (aceitou o
  desafio e não confirmou presença no prazo) é fato **verificável pelo próprio
  sistema** — não vale burocratizar cada ausência isolada com revisão humana
  (princípio 4).
- **Mas o selo público não é automático.** O que vira visível a terceiros passa
  por uma **janela de contestação de 48h**, reusando o mesmo padrão da retenção
  financeira do item 3.5 (nada reputacional aparece sem o usuário ter a chance
  de contestar):
  - Ao **cruzar o limiar de 3** abandonos, o sistema **agenda** a publicação do
    selo para dali a **48h** (`profiles.abandonment_badge_public_at`) e
    **notifica o usuário**, com uma **porta real de contestação**: "seu histórico
    de ausências vai ficar visível — se teve um motivo justo, conteste antes
    disso pelo **Suporte**". A notificação leva pra tela de Suporte
    (`SupportView.vue`, rota `/support`), onde ele abre um **ticket interno**
    (`support_tickets`, seção 4.4) já amarrado à conta — nunca um "fale com a
    gente" vago nem um e-mail solto (senão a janela vira promessa vazia).
  - **48h sem contestação** → o selo **"⚠️ Histórico de abandono"** aparece no
    perfil público (`ProfileView.vue`). Diferente do dinheiro, **não precisa de
    cron**: a visibilidade é derivada na leitura (`public_at <= now`).
  - Se o usuário **contestar** dentro da janela, um admin decide **publicar** (se
    negada, `public_at = now`) ou **arquivar** (se justificada, `public_at =
    NULL`); enquanto pende, o selo não aparece. **Hoje isso é manual** (o ticket
    entra em `support_tickets`, alerta o admin, e ele resolve por SQL) — mesmo
    padrão do `finalize-due-deletions` antes do cron. A automação dessa triagem é
    a **Fila de revisão de padrões reputacionais** (item 4.4, ainda a construir).
- Fica separado do Fair Play de propósito: um jogador pode ser confiável
  reportando resultados e ainda assim sumir de partidas — misturar as duas
  notas numa só perde informação.

---

## 2. Carteira e Dinheiro

### 2.1 Estrutura da carteira (`wallets`)
- `balance` — saldo livre, sacável.
- `locked_balance` — saldo travado (apostas em partidas ativas **e** prêmios
  retidos aguardando liberação).
- Toda operação é atômica e registrada em `transactions` (tipos: `deposit`,
  `withdraw`, `bet_freeze`, `bet_refund`, `challenge_win`, `challenge_loss`,
  `tournament_prize`, `rake`).

### 2.2 Depósito (Pix)
- Mínimo **R$ 10,00** (`pix.py`).
- Gera Pix Copia-e-Cola; o crédito cai via **webhook** do gateway, de forma
  **idempotente** (dois webhooks do mesmo `external_id` não creditam em
  duplicidade) (`04`, `fn_process_pix_deposit_webhook`).
- Taxa de depósito de R$ 0,99: **decidida, mas ainda NÃO implementada**.

### 2.3 Saque (Pix)
- Debita o saldo livre e registra a transação atomicamente (`04`, `fn_withdraw`).
- Exige saldo livre suficiente (prêmios retidos não contam até liberarem).

### 2.4 Rake (comissão da plataforma)
- **Desafio 1v1: 8%** sobre o pote (2× a aposta). O vencedor leva **1,84×** o
  valor da partida (`18`, `26`).
- **Torneio online pago: 10%** sobre o pote de inscrições (`07`, `08`, `19`).
- Overhead de organização/arbitragem justifica o torneio ser mais alto que a
  partida simples.

### 2.5 Valores mínimos
- Desafio 1v1: **R$ 1,00** (`18`, `fn_create_challenge`). Atalhos na UI: R$ 5 /
  10 / 20 / 50.
- Torneio pago: **R$ 1,00** de inscrição (`18`, UI sugere R$ 10).

---

## 3. Desafio 1v1 — ciclo de vida completo

Estados de `challenges.status`: `open → accepted → in_progress →
completed | disputed`, com saídas para `cancelled`.

```
            criar                 criador escolhe            os 2 confirmam
  (nada) ─────────► open ──────────────────────► accepted ──────────────► in_progress
                     │  solicitante                  │  "Iniciar partida"        │
                     │                                │  (15 min)                 │
       cancelar ◄────┘                    no-show ◄───┘                           │
      (reembolsa                       (devolve os 2                              │
       criador)                        + abandono++)                             │
                                                              consenso ┌─────────┤
                                                                       ▼         │ divergência
                                                                  completed      ▼
                                                          (pago na hora)     disputed
                              1 reporte + prazo venceu ──► completed          (admin)
                                (aceite auto, RETIDO 3d) ──► release/contestar
                              0 reportes + prazo venceu ──► cancelled (anula, devolve)
```

### 3.1 Criar desafio (`open`)
- Criador escolhe valor, jogo e plataforma. O saldo dele é **travado na hora**
  (`balance → locked_balance`) (`04`/`18`, `fn_create_challenge`).
- O desafio entra no lobby público (`/api/challenges/open`) — vitrine também
  para visitantes não logados (gancho de cadastro).
- Contas **desativadas** somem do lobby (`challenges.py`).

### 3.2 Entrar num desafio (solicitação, não aceite direto) (migração `20`)
- Não existe "aceitar direto". Qualquer um **solicita entrada**
  (`challenge_join_requests`, status `pending`) — não trava saldo ainda, só
  confere se dá pra pagar.
- O **criador vê todos os solicitantes e escolhe um**. Só nesse momento o saldo
  do escolhido é travado.
- Ao escolher um, **todas as outras solicitações pendentes são recusadas
  automaticamente** (só se joga contra um por vez).
- O solicitante pode cancelar o próprio pedido antes de ser respondido
  (silencioso).

### 3.3 Checkpoint "Iniciar partida" (`accepted`, migrações `24`/`26`)
- Ao escolher o oponente, o desafio vai para `accepted` (**não** direto para
  `in_progress`).
- **Os dois** precisam clicar "Iniciar partida" (`fn_mark_ready`) dentro de
  **15 minutos** (`start_deadline`). Só então vira `in_progress`.
- Isso separa "nunca jogaram" de "jogaram e não bateram o placar" e é o marco
  verificável de que a partida começou.
- **Não existe agendamento formal** — o padrão é "jogar agora". Quem quiser
  combinar horário faz informalmente pelo chat da partida.
- **Se o prazo vence sem os dois confirmarem** → partida **cancelada**, saldo
  **devolvido aos dois**, e quem não confirmou leva **+1 no contador de
  abandono** (nunca punição financeira).

### 3.4 Jogar e reportar (`in_progress`)
- Os dois se adicionam na rede (PSN/Xbox/EA App), jogam no console/PC e voltam
  pra reportar "Ganhei" ou "Perdi".
- Ao **abrir** a partida (`in_progress`), começa um prazo de **24h**
  (`report_deadline`).
- Quando o **primeiro** reporta, o prazo é **resetado para +24h a partir dali**
  — quem foi avisado sempre tem 24h cheias, não importa quando o outro reportou
  (`26`, `fn_report_challenge_result`).
- **Caminho feliz (consenso):** os dois reportam e batem (um "ganhei", outro
  "perdi") → o vencedor recebe o prêmio **na hora**, rake descontado. Sem
  retenção (`fn_settle_challenge(hold=false)`).
- **Divergência** (os dois "ganhei" ou os dois "perdi") → vai para `disputed`,
  dinheiro fica travado, abre chat de mediação.

### 3.5 Timeout do resultado — aceite automático com retenção (migração `26`)

O caso central. Quando o prazo de 24h vence com **um lado só reportado**:

- **Aceita automaticamente o resultado de quem reportou** — sem fila de admin.
  Racional: se o reporte foi honesto, o perdedor não tem motivo pra reagir
  (silêncio esperado); se foi mentira, o verdadeiro vencedor **tem todo motivo
  pra reagir** e não ficaria calado vendo o dinheiro dele ser roubado. O
  silêncio, portanto, já é sinal confiável.
- **MAS o prêmio fica RETIDO por 3 dias** (`settlement_release_at`), no
  `locked_balance` do vencedor — **não-sacável**. Nessa janela:
  - O rake **ainda não é cobrado** (`rake_amount = 0`). Se a retenção for
    revertida por contestação, a plataforma nunca cobrou taxa sobre um
    resultado que não valeu.
  - O lado silencioso pode **contestar** (disputa reativa) → admin analisa e
    reverte, porque o dinheiro **ainda está retido** (dá pra estornar). Isso
    mata a "corrida de saque" (fraudador sacar antes do lesado reclamar).
- **Passou os 3 dias sem contestação** → o prêmio **libera** (locked → balance,
  rake cobrado agora) via job horário (`fn_release_due_settlements`).
- **Notificação nomeia a causa** para os dois lados:
  - Vencedor: "Como [oponente] não confirmou no prazo, o prêmio fica reservado
    3 dias — **isso só acontece quando falta confirmação, não em toda vitória**.
    Libera em [data]." (evita o usuário achar que toda vitória demora 3 dias).
  - Lado silencioso: "[oponente] reportou vitória, o resultado foi aceito.
    Discorda? Conteste até [data]."
- **Zero reportes** no prazo (ninguém reportou) → não há resultado pra aceitar
  → partida **anulada e devolvida aos dois**.

### 3.6 Cancelar desafio
- Só é possível cancelar um desafio **ainda aberto** (`open`, sem oponente). O
  saldo do criador volta (`14`, `fn_cancel_challenge`).

---

## 4. Reportar problema, disputas e mediação

### 4.1 Botão "Reportar" com motivos estruturados (item 5)
Na tela da partida, além de "Ganhei/Perdi", um "Reportar um problema" abre um
formulário com motivo (dropdown) + texto livre opcional. Motivos:
1. Resultado reportado incorretamente / trapaça
2. Não iniciou a partida / não apareceu
3. Abandonou no meio da partida
4. Comportamento inadequado (xingamento/assédio)
5. Outro

### 4.2 Como cada porta é tratada
- **"Perdi a aposta" vs "o cara sumiu" são portas diferentes:**
  - Reportar um **resultado** (Ganhei/Perdi) entra no fluxo de consenso/aceite
    automático com retenção (seção 3).
  - Reportar **ausência/abandono** (no-show) é resolvido pela mecânica de
    timeout: devolve os dois + contador de abandono. **Sem mover dinheiro como
    punição.** **Clicar nesses dois motivos não acelera nada** enquanto o
    desafio ainda está dentro do prazo normal (`accepted`/`in_progress`): de
    propósito, pra que o clique não vire atalho pra **forçar um resultado antes
    da hora**. Ele serve só como **registro/contexto** — fica guardado e vira
    útil se aquele mesmo desafio acabar indo pra disputa por outro motivo
    depois. Quem decide o desfecho de ausência continua sendo o timeout, não o
    reporte.
  - Reportar **má conduta / trapaça / outro** → abre **disputa** para mediação
    de admin (`fn_open_challenge_dispute`), guardando o motivo como primeira
    mensagem. Provas (print/vídeo) vão no chat da disputa (`dispute_messages`,
    `attachment_url`).

### 4.3 Disputa e mediação (`disputed`)
- Uma disputa nasce de: divergência de resultado, contestação reativa de um
  aceite automático, ou reporte de má conduta.
- Enquanto `disputed`, o dinheiro fica **travado** (nunca move sem revisão
  humana).
- **Resolução (admin)** (`26`, `fn_resolve_challenge_dispute` — preencheu um
  buraco: antes só torneio tinha resolução, no `09`):
  - Normaliza o dinheiro (se veio de aceite automático, o pote está consolidado
    no vencedor provisório; devolve a metade pro outro, ficando igual a uma
    divergência) e então **liquida para o vencedor decidido**.
  - **Penaliza o Fair Play (−1,5) só de quem mentiu** (reportou vitória e perdeu
    na decisão). Quem apenas ficou em silêncio não é penalizado.
  - Notifica os dois (`dispute_resolved_win` / `dispute_resolved_loss`).
- Punição a fraudadores é **Fair Play + banimento por reincidência** — nunca
  confisco financeiro arbitrário.

### 4.4 Fila de revisão de padrões reputacionais (a construir)
Estrutura de moderação para tratar **padrões**, não eventos isolados. É a peça
que fecha o princípio 4: consequência reputacional por alegação de terceiro
(ou por contestação de um selo automático) sempre passa por um humano com
contexto, nunca por um clique solto.

- **Entra por padrão acumulado, não por evento único.** Um caso só chega à fila
  quando: (a) o contador de abandono **cruza o limiar** e o usuário **contesta**
  a publicação do selo (item 1.4), ou (b) **reports de conduta se acumulam**
  contra o mesmo usuário. Um no-show avulso ou um report isolado **não** abrem
  caso — seguem só como registro (item 4.2).
- **Contexto completo por caso, nunca a alegação crua.** O admin vê o histórico
  de partidas envolvidas, datas, o contador atual e as **provas anexadas** (os
  prints/vídeos que já vão no chat da disputa) — o suficiente pra decidir sem
  abrir o painel do banco.
- **Ações padronizadas:** aplicar/segurar o selo de abandono, ajustar o Fair
  Play, **arquivar sem ação** (contestação justificada) ou **suspender
  temporariamente**. Cada ação é a mesma que o admin já toma numa disputa —
  não é um poder novo.
- **Trilha de auditoria:** quem decidiu, quando e o motivo ficam registrados
  (como a `resolution` da disputa).
- **Reaproveita a estrutura de disputa que já existe** (`backend/admin.py` +
  `disputes`/`dispute_messages` + as `fn_resolve_*`), não um sistema paralelo:
  a fila é uma nova **origem** e uma nova **visão** sobre o mesmo motor de
  mediação. (Pendência de implementação — ver seção 12.)

**Semente já no lugar — o "e-mail interno" (`support_tickets`, migração `28`).**
A captura estruturada e o alerta de admin já existem, como primeira fatia disto:
- A tela de **Suporte** (`SupportView.vue`, rota `/support`) é um **formulário**,
  não um `mailto`: grava um ticket (`support_tickets`) já **amarrado ao
  `user_id`** logado — resolve o problema de matching que o e-mail tem (não
  precisa adivinhar de qual conta veio) — via `fn_open_support_ticket`
  (`SECURITY DEFINER`, `user_id` do JWT).
- **Alerta de admin é obrigatório, não opcional:** abrir um ticket dispara uma
  notificação `support_ticket_opened` pra todo `is_admin`. Como o admin também
  joga, o sino (polling 30s, em toda tela) acende quando ele abre o app. Ainda
  **não há push/e-mail** que chegue no celular offline — o próximo passo pra isso
  é plugar um webhook (Discord/Telegram) ou e-mail no `fn_open_support_ticket`.
- **Resposta ainda é manual** (admin resolve `support_tickets` por SQL; os
  snippets estão no cabeçalho da migração `28`). O que falta pra fechar a 4.4:
  a **thread** de ida e volta (mesmo papel do `dispute_messages`) e a **tela de
  lista** no admin — construídos **por cima da mesma tabela**, sem retrabalho.

---

## 5. Torneios

### 5.1 Torneio Online Pago (`online_paid`, migrações `07`/`08`/`19`)
- Taxa de inscrição vira um **pote compartilhado** no momento da inscrição
  (`balance → locked_balance`). Não é aposta direta entre duas pessoas.
- Vagas: **4, 8 ou 16** jogadores. A chave (mata-mata) só é sorteada quando as
  vagas enchem.
- **Rake 10%.** Premiação sobre o pote líquido (`19`):
  - **4 jogadores:** campeão leva **100%**.
  - **8 jogadores:** 1º **55%**, 2º **30%**, 3º **15%**.
  - **16 jogadores:** 1º **50%**, 2º **25%**, 3º **15%**, 4º **10%**.
- Cada partida do chaveamento (`tournament_matches`) usa a **mesma mecânica** de
  reportar/timeout dos desafios.
- **Abandono em torneio** (decidido, motor de bracket a implementar): quem
  abandona leva **penalidade reputacional** e o adversário **vence por W.O.** e
  avança. Como o prêmio sai do **pote compartilhado** (não de transferência
  direta), não há "tirar dinheiro" de ninguém — quem abandona só perde a chance
  que já pagou pra concorrer. Falta desenhar como o W.O. se propaga em cascata
  nas rodadas seguintes.

### 5.2 Torneio de Sofá / Local (grátis)
- Funil de aquisição com fricção zero: só o anfitrião tem conta; participantes
  são nomes avulsos (`tournament_participants.user_id` nulo). Ferramenta grátis
  que vira receita via upsell. (Ver `TODO.md` e memória do projeto.)

---

## 6. Exclusão e Desativação de Conta (migrações `22`/`23`)

Duas portas distintas, ambas com uma trava comum: **não é possível sair com
partida/torneio em andamento** (status `accepted`/`in_progress`, ou inscrição
viva em torneio pago) — resolve/termine antes. Disputas em análise **não**
bloqueiam (a carteira sobrevive e ainda pode receber saldo depois).

### 6.1 Desativar (temporário, reversível)
- Some da vitrine (desafios abertos não aparecem, perfil público mostra "conta
  desativada"), mas **nada é apagado** e o saldo fica guardado.
- **Volta ao normal no próximo login** (reativa automático, com toast
  "bem-vindo de volta"). Sem prazo, sem carência.
- Não bloqueia por saldo (o dinheiro fica seguro, é reversível).

### 6.2 Excluir (definitivo, com carência)
- **Exclusão = anonimização, nunca hard-delete.** A linha em
  `profiles`/`wallets` sobrevive pra sempre como âncora de FK (desafios,
  disputas e torneios de terceiros a referenciam).
- **Restrição técnica:** `profiles.id` referencia `auth.users ON DELETE
  CASCADE` — deletar o usuário do Auth apagaria o perfil. Por isso a
  anonimização **bane o login** (`ban_duration`), não deleta.
- **Bloqueia se houver saldo livre > 0** — o usuário precisa **sacar antes**
  (nunca há confisco).
- **Carência de 30 dias:** o pedido só marca `deletion_requested_at`. **Logar
  de novo dentro da janela cancela o pedido** e restaura a conta.
- Passados 30 dias, um job (`finalize-due-deletions`) bane o login e anonimiza:
  `username → "Usuário Excluído #<8 hex do id>"`, demais dados pessoais
  zerados. O **apelido original fica reservado pra sempre** (a linha nunca some).
- KYC/2FA: telas presentes, marcadas "Em breve" (KYC adiado de propósito).

---

## 7. Notificações

Feed próprio (`notifications`), sino no header/sidebar, polling a cada 30s.
Clicar leva direto ao contexto (deep-link por `challenge_id`/`tournament_id`).
Tipos usados: `tournament_open`, `match_ready`, `match_disputed`,
`tournament_prize`, `tournament_cancelled`, `dispute_resolved_win/loss`,
`deposit_confirmed`, `withdraw_completed`, `challenge_accepted`,
`challenge_result_pending`, `challenge_win`, `challenge_loss`,
`challenge_disputed`, `challenge_join_requested`, `challenge_request_accepted`,
`challenge_request_rejected`, `challenge_expired`, `abandonment_warning`
(aviso de que o selo de abandono vai ficar visível em 48h — item 1.4),
`support_ticket_opened` (alerta pro admin de que entrou um ticket de suporte —
item 4.4).

Toast in-app (`stores/toast.ts` + `ToastHost.vue`) para feedback não-bloqueante
(ex.: reativação de conta).

---

## 8. Jobs agendados (cron)

Rodados por **pg_cron**. **Os três jobs dependem de `pg_cron` habilitado (e
`pg_net`, só para o job de exclusão, que faz HTTP) no plano Supabase (Database →
Extensions) — confira isso antes de assumir que estão rodando.** Se
indisponíveis, cair para cron externo com segredo dedicado, batendo nos mesmos
alvos.

| Job | Frequência | O que faz | Arquivo |
|---|---|---|---|
| `process-match-timeouts` | a cada 5 min | Resolve prazos vencidos: `accepted` no-show → devolve+abandono; `in_progress` → aceite automático com retenção ou anula | `24`/`26` |
| `release-due-settlements` | de hora em hora | Libera prêmios retidos cuja janela de 3 dias passou (cobra o rake aqui) | `26` |
| `finalize-account-deletions` | diário 03:00 UTC | Bane login + anonimiza contas com carência vencida (via endpoint, autenticado por `X-Cron-Secret`) | `25` + `account.py` |

### Pra rodar (checklist de deploy)
1. **Migrações SQL em ordem numérica** no SQL Editor do Supabase
   (`schema.sql` → `04` → … → `27` → `28`). Cada arquivo diz no topo de qual
   depende.
2. **Confira as extensões** `pg_cron` e `pg_net` (Database → Extensions). Sem
   elas, os `cron.schedule(...)` embutidos em `24`/`25`/`26` não agendam nada —
   caia para cron externo chamando as mesmas funções/endpoint.
3. **`25_schedule_deletion_finalize.sql` tem placeholders** — troque
   `<SEU_BACKEND_URL>` (URL pública do FastAPI) e `<SEU_CRON_SECRET>` (mesmo
   valor da env `CRON_SECRET` do backend) **antes** de executar; senão o job de
   anonimização bate numa URL inválida e falha calado.

---

## 9. Prazos e valores — tabela de referência rápida

| Regra | Valor |
|---|---|
| Rake desafio 1v1 | 8% (vencedor leva 1,84×) |
| Rake torneio pago | 10% |
| Mínimo desafio 1v1 | R$ 1,00 |
| Mínimo inscrição torneio | R$ 1,00 |
| Mínimo depósito | R$ 10,00 |
| Confirmar presença ("Iniciar partida") | 15 min |
| Reportar resultado (`in_progress`) | 24 h |
| Retenção do prêmio (aceite automático) | 3 dias |
| Selo de abandono no perfil | ≥ 3 abandonos, público após a janela |
| Janela de contestação do selo de abandono | 48 h |
| Penalidade Fair Play por mentira | −1,5 (piso 0) |
| Carência de exclusão de conta | 30 dias |

---

## 10. Segurança e arquitetura das regras

- **RLS ligado** em todas as tabelas sensíveis. O client (`anon`/`authenticated`)
  só faz `SELECT` do que lhe é permitido; **toda escrita de saldo/estado passa
  por função `SECURITY DEFINER` chamada pelo backend com `service_role`**.
- Funções de dinheiro travam a(s) carteira(s) com `SELECT ... FOR UPDATE`, e
  quando travam duas, sempre na **mesma ordem** (menor `user_id` primeiro) para
  nunca gerar deadlock.
- Convenção de erro: `RAISE EXCEPTION 'CODIGO: mensagem'`; o backend faz o parse
  do prefixo para decidir o status HTTP e mostra o resto ao usuário.
- `user_id`/`creator_id` **nunca** vêm do corpo da requisição — sempre do JWT
  verificado (`auth.py`).
- Idempotência garantida em depósito/saque por índice único de `external_id`.

---

## 11. Glossário de status

**`challenges.status`**
- `open` — criado, saldo do criador travado, aguardando escolha de solicitante.
- `accepted` — oponente escolhido, os dois têm saldo travado, aguardando
  "Iniciar partida" (15 min).
- `in_progress` — partida em andamento, prazo de reporte rolando (24h).
- `completed` — resolvido. Se `settlement_release_at` != null, é aceite
  automático com prêmio **retido** (contestável); se null, já pago.
- `disputed` — em mediação de admin (divergência, contestação reativa ou má
  conduta).
- `cancelled` — cancelado pelo criador, no-show no `accepted`, ou sem reportes
  no `in_progress`.

**`challenge_join_requests.status`**: `pending`, `accepted`, `rejected`,
`cancelled`.

**`tournaments.status`**: `registration_open`, `in_progress`, `completed`,
`cancelled`.

**`disputes.status`**: `open`, `resolved`, `cancelled`.

**`support_tickets.status`** (migração `28`): `open` (aguardando o admin),
`resolved` (tratado), `closed` (arquivado sem ação). **`category`**:
`badge_contest`, `match`, `wallet`, `account`, `other`.

---

## 12. Decidido, mas ainda NÃO implementado (pendências de regra)

- **Taxa de depósito R$ 0,99** (decidida, não cobrada hoje).
- **Matching de titularidade CPF** (CPF do Pix = CPF do cadastro) — antifraude
  barato via API do gateway; KYC pago adiado de propósito.
- **W.O. de torneio em cascata no bracket** — regra fechada (penalidade + W.O.,
  pote compartilhado), falta o motor de propagação nas rodadas.
- **Selo de abandono evoluir** de contador para tags mais ricas — decisão de v2.
- **Fila de revisão de padrões reputacionais** (seção 4.4) — regra fechada;
  a **semente já está no código**: o "e-mail interno" (`support_tickets`,
  migração `28`) faz a captura estruturada do ticket **+ o alerta de admin**
  (obrigatório). **Falta**, por cima da mesma tabela: a **thread** de ida e volta
  (papel do `dispute_messages`), a **tela de lista** no admin, e — se quiser
  alerta que chegue no celular offline — um **webhook/e-mail** no
  `fn_open_support_ticket` (hoje o alerta é só a notificação in-app).

---

*Última consolidação: 10/07. Este documento acompanha o código — ao mudar uma
regra numa migração/endpoint, atualize a seção correspondente aqui.*
