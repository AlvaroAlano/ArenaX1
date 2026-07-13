# Mapa de Riscos Legais e Regulatórios — ArenaX1

> **O que este documento é:** um levantamento de leis, regulamentos e questões
> jurídicas que tocam o modelo de negócio da ArenaX1 (desafios 1v1 e torneios
> com aposta em dinheiro real, entre jogadores, com resultado definido por
> habilidade no próprio jogo). Foi montado a partir de pesquisa (fontes
> oficiais e análises jurídicas publicadas) cruzada com o funcionamento real
> do sistema (ver `regras-do-sistema.md`).
>
> **O que este documento NÃO é:** parecer jurídico. Não substitui análise de
> advogado — é o material bruto para acelerar essa análise. Cada seção termina
> com a pergunta específica que precisa da palavra de um profissional
> licenciado. Nenhuma classificação abaixo ("provavelmente não se aplica",
> etc.) deve ser tratada como decisão tomada.
>
> Última pesquisa: 13/07/2026.

---

## 1. Classificação do produto — o eixo central de tudo, e o item mais grave do documento

Esta é a pergunta da qual a maioria das outras seções depende. **Revisão de
13/07/2026:** a primeira versão deste documento tratou o argumento
"habilidade predominante" com otimismo excessivo, incluindo pelo menos um
erro factual. Corrigido abaixo, com a gravidade real nomeada.

### O risco real não é só regulatório — é exposição criminal pessoal
- **Decreto-Lei nº 3.688/1941, art. 50** (Lei das Contravenções Penais)
  tipifica como infração **penal** estabelecer ou explorar "jogo em que o
  ganho e a perda dependem exclusiva ou principalmente da sorte". Se um juiz
  entender que, no modelo da ArenaX1, **a aposta em dinheiro é o núcleo do
  produto** (e a partida é só o mecanismo de definição do ganhador), a
  discussão deixa de ser "precisamos de licença/autorização?" e passa a ser
  "os operadores cometeram contravenção penal?". **Isso é responsabilidade
  pessoal dos sócios/administradores, não apenas risco financeiro da
  empresa.** Este documento não nomeava isso com clareza suficiente antes —
  fica corrigido aqui.

### Correção: não existe decisão do STF reconhecendo poker como jogo de habilidade
- A versão anterior deste documento afirmava "o STF reconheceu em 2012 que o
  poker é jogo de habilidade", citando artigos de portais. **Isso é
  impreciso e não deve ser usado como base de nenhuma decisão.** Ao verificar
  em fontes primárias:
  - O que existe de 2012 é um **reconhecimento administrativo do Ministério
    do Esporte** à CBTH (Confederação Brasileira de Texas Hold'em) como
    "esporte da mente" — um ato do Executivo, não uma decisão judicial.
  - Existem decisões de **tribunais estaduais** (TJSC principalmente, também
    TJRS/TJMG) reconhecendo o poker como jogo de habilidade em casos
    concretos — mas essas decisões **não vinculam o país** (não são
    precedente obrigatório fora daquele processo).
  - Existe um caso real no STF com repercussão geral reconhecida — **Tema
    924 (RE 966.177)** — mas ele trata da constitucionalidade de
    **criminalizar bingo/loteria** à luz da Constituição de 1988, não da
    distinção entre jogo de habilidade e jogo de azar, e não é
    especificamente sobre poker ou skill games. Vale monitorar o andamento
    desse tema, mas não deve ser citado como precedente favorável direto.
    [Portal STF — Tema 924](https://portal.stf.jus.br/jurisprudenciaRepercussao/verAndamentoProcesso.asp?classeProcesso=RE&incidente=4970952&numeroProcesso=966177&numeroTema=924)

### A analogia com o poker é mais fraca do que parecia — não mais forte
- A decisão do TJSC mais citada (ConJur, 2012) envolvia um **torneio com
  fichas fictícias, sem dinheiro real em jogo** — "a aquisição de novas
  fichas ou apostas intervenientes eram proibidas". O próprio juiz definiu a
  distinção com todas as letras: **"proibida é a aposta, não o jogo"**.
  [ConJur — Pôquer é jogo de habilidade, e não de azar, entende Justiça catarinense](https://www.conjur.com.br/2012-jan-14/poquer-jogo-habilidade-nao-azar-entende-justica-catarinense/)
- Ou seja: esse precedente protege a **exibição de habilidade** (jogar a
  partida), não necessariamente a **aposta em dinheiro real** sobre o
  resultado — que é exatamente o que a ArenaX1 faz (vencedor leva o valor
  apostado pelos dois). A analogia favorável existe para "o jogo em si", mas
  é bem menos clara para "apostar dinheiro real no resultado entre os
  próprios jogadores", que é o núcleo do produto.

### Lei 14.852/2024 — a exclusão é mais ampla e mais desfavorável do que a versão anterior registrava
- Texto oficial do **art. 5º, parágrafo único**: excluem-se do conceito de
  jogo eletrônico "promoções comerciais ou modalidades lotéricas
  regulamentadas pelas Leis nºs 13.756/2018 e 14.790/2023, **ou qualquer
  tipo de jogo que ofereça algum tipo de aposta, com prêmios em ativos reais
  ou virtuais, ou que envolva resultado aleatório ou de prognóstico**" —
  remetendo essas atividades à "legislação específica" de apostas.
  [Planalto — Lei 14.852](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/l14852.htm)
- A ArenaX1 é, literalmente, um jogo que oferece aposta com prêmio em
  dinheiro real. Isso não é só "fora do escopo, neutro" — é o legislador
  colocando explicitamente "qualquer jogo com aposta e prêmio real" na
  mesma categoria remetida ao regime de apostas. **É um sinal normativo
  contrário à tese de que basta ser habilidade para escapar de regulação de
  apostas — a camada de dinheiro real, por si, parece deslocar a atividade
  para esse outro regime aos olhos do legislador.**

### Paralelo (com cautela): fantasy games
- Durante a tramitação do marco dos jogos eletrônicos, fantasy sports foram
  retirados desse marco e tratados dentro da lei de apostas, com a
  clarificação de que a atividade "não constitui modalidade de loteria" —
  mostra que o Legislativo está ativamente desenhando categorias
  intermediárias. Não é uma analogia direta com desafio 1v1 (o formato de
  fantasy sports é diferente), mas confirma que o cenário está em movimento,
  não é uma foto parada. [BNLData — fantasy games](https://bnldata.com.br/camara-dos-deputados-aprova-marco-legal-para-a-industria-de-jogos-eletronicos-aprova-os-jogos-de-fantasia/)

**Perguntas para o advogado (reformuladas, mais diretas):**
1. Dado que o precedente de habilidade mais citado protege o jogo mas não
   necessariamente a aposta em dinheiro sobre o resultado, e que a 14.852
   agrupa "qualquer jogo com aposta e prêmio real" junto do regime de
   apostas — qual é a exposição real da ArenaX1 e dos seus sócios sob o
   art. 50 do Decreto-Lei 3.688/1941?
2. Essa exposição é **pessoal** (dos administradores) ou se limita à pessoa
   jurídica? Isso muda a estrutura societária recomendada?
3. Existe hoje uma estrutura de produto (ex.: cobrar entrada fixa em vez de
   aposta sobre o resultado, distribuir por mérito e não por "quem ganhou o
   confronto") que reduziria esse risco sem descaracterizar o produto?

---

## 2. Verificação de idade — Lei FELCA (já em vigor, prazo vencido)

- **Lei nº 15.211/2025** ("ECA Digital", popularmente "Lei FELCA"), sancionada
  17/09/2025, **em vigor desde 17/03/2026** — já valendo há ~4 meses.
  [Texto oficial — Planalto](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm)
- Exige "mecanismos **confiáveis** de verificação de idade **a cada
  acesso**... **vedada a autodeclaração**". Um checkbox "declaro ter 18+"
  não cumpre — e **"a cada acesso" é literal**, não "uma vez no cadastro".
  Confirmado em fonte especializada: "a simples autodeclaração deixa de ser
  suficiente, impondo o uso de mecanismos confiáveis ajustados conforme o
  risco do serviço". [ConJur — Lei Felca e compliance digital](https://www.conjur.com.br/2026-mar-28/lei-felca-e-compliance-digital-o-que-muda-na-governanca-das-empresas/)
- **Revisão de 13/07/2026:** a versão anterior deste mapa e os rascunhos de
  Termos/Privacidade descreviam a verificação como algo feito "no
  cadastro". Isso provavelmente não é suficiente — precisa de desenho de
  produto que reafirme a verificação em algum ritmo recorrente (não
  necessariamente literal a cada login, mas o texto da lei não abre exceção
  clara para "verificado uma vez, vale para sempre"). Isso é tanto pergunta
  jurídica (o que conta como cumprimento) quanto decisão de produto.
- Escopo amplo: qualquer produto/serviço digital que atinja ou possa
  impactar crianças/adolescentes — coordenação regulatória da ANPD.
- **Sanções: até 10% do faturamento do grupo econômico ou R$ 50 milhões por
  infração.** [Ambito Jurídico — Lei Felca](https://ambitojuridico.com.br/lei-felca/)

**Implicação técnica direta (não é só texto de política):** o age gate
planejado precisa ser verificação real (CPF + consulta que confirme
maioridade, e/ou biometria) **com alguma forma de reafirmação periódica**,
não uma checagem única e definitiva no cadastro. Isso converge com o item de
"matching de titularidade CPF" que já estava no backlog como antifraude —
agora tem uma segunda razão, com prazo já vencido.

**Perguntas para o advogado:**
1. O método de verificação (CPF via API consultando situação cadastral, sem
   necessariamente biometria) é suficiente para "mecanismo confiável" no
   sentido da lei, ou biometria é exigida dado o perfil de risco (dinheiro
   real envolvido)?
2. O que satisfaz "a cada acesso" na prática — reverificação em todo login,
   periodicamente (ex.: a cada X dias), ou uma verificação robusta única já
   atende desde que não haja indício de compartilhamento de conta? A leitura
   mais literal do texto é desfavorável à checagem única no cadastro.
3. Os dados de CPF coletados especificamente para esta finalidade podem ser
   reaproveitados para outro propósito (antifraude de Pix, ver Política de
   Privacidade) ou a lei exige segregação de finalidade? (Ver também
   pergunta nova na Seção 10, item 8.)

---

## 3. Custódia de saldo — instituição de pagamento (Banco Central)

- Uma carteira que **guarda saldo de terceiros e permite saque para conta
  bancária própria via Pix** tem o perfil funcional de uma "instituição de
  pagamento" gerindo conta de pagamento/moeda eletrônica — atividade que, em
  regra, exige autorização do Banco Central.
  [Levy & Salomão — quando pedir autorização](https://www.levysalomao.com.br/publicacoes/artigo/instituicoes-de-pagamento-quando-pedir-autorizacao)
- Existe a categoria "arranjo de pagamento de **propósito limitado**"
  (ex.: saldo só utilizável dentro do próprio ambiente, sem conversão de
  volta em dinheiro sacável) que fica fora dessa exigência — mas a ArenaX1
  **permite saque real via Pix**, o que foge do perfil de "propósito
  limitado" tal como normalmente entendido. [O que é arranjo de propósito limitado](https://silvalopes.adv.br/o-que-e-arranjo-de-pagamento-de-proposito-limitado/)
- **Atenuante relevante para o estágio atual:** existe uma dispensa de
  autorização para arranjos com volume abaixo de **R$ 20 bilhões e 100
  milhões de transações em 12 meses** — a ArenaX1 está muito abaixo disso
  hoje. Ou seja, não é bloqueador imediato no volume atual, mas é algo que
  **cresce junto com o negócio** e precisa ser monitorado, não esquecido.
  A leitura exata de como esse limiar se aplica ao caso específico (é uma
  isenção total ou um regime simplificado?) não ficou clara nas fontes
  consultadas — precisa de confirmação especializada.
  [Resolução BCB 150/2021](https://www.legisweb.com.br/legislacao/?id=421572)

**Pergunta para o advogado (ou especialista em direito bancário/pagamentos,
que pode ser um segundo profissional além do advogado de jogos/apostas):** no
volume atual (early-stage), a ArenaX1 precisa de registro/autorização do
BACEN para operar a carteira com saque real, ou o modelo de "o gateway Pix já
autorizado processa a liquidação, a ArenaX1 só mantém um livro-razão interno"
é suficiente para ficar fora dessa exigência? Vale revisar de novo conforme o
volume crescer.

---

## 4. Prevenção à lavagem de dinheiro (AML/COAF)

- **Lei nº 9.613/1998** é a lei geral de lavagem de dinheiro; a **Portaria
  SPA/MF 1.143/2024** obriga especificamente "agentes operadores de apostas"
  (registrados sob a 14.790) a implantar monitoramento, KYC do apostador,
  registro de operações e comunicação ao COAF em até 24h de suspeitas via
  SISCOAF. [Migalhas — lavagem de dinheiro nas apostas online](https://www.migalhas.com.br/depeso/430214/lavagem-de-dinheiro-nas-apostas-online)
- Essa obrigação específica está amarrada a ser um operador registrado sob a
  14.790 — se a ArenaX1 não for classificada assim (ver seção 1), essa
  portaria em particular não bate diretamente. **Mas** a preocupação de fundo
  não desaparece: uma carteira P2P onde dinheiro se move entre contas via
  "resultado de partida" é estruturalmente parecida com os vetores clássicos
  de lavagem citados nas fontes — "apostas cruzadas, uso de laranjas e
  fracionamento de valores" — mesmo fora do regime formal de apostas.
- Isso reforça (pela terceira razão diferente agora) o valor do matching de
  titularidade CPF no Pix: antifraude, conformidade com a Lei FELCA (idade),
  e mitigação de risco de lavagem — a mesma peça de infraestrutura resolve
  três frentes.

**Pergunta para o advogado:** mesmo fora do regime formal da 14.790, faz
sentido adotar voluntariamente controles análogos (monitoramento de padrão de
transação, KYC leve) como mitigação de risco reputacional/regulatório? Existe
exposição a responsabilização mesmo sem enquadramento formal como "pessoa
obrigada" pela Lei 9.613?

---

## 5. LGPD — já mapeado, resumo aqui

- Política de privacidade precisa ser clara, sem juridiquês desnecessário,
  identificar o controlador, base legal de cada tratamento, e oferecer canal
  de contato do titular com prazo de resposta definido (praxe: até 15 dias).
  [Guia oficial gov.br sobre termo de uso e política de privacidade](https://www.gov.br/governodigital/pt-br/privacidade-e-seguranca/ppsi/guia_termo_uso_politica_privacidade.pdf)
- Isso já está sendo endereçado na política de privacidade em elaboração —
  ver documento separado.

---

## 6. Marco Civil da Internet — retenção de dados (tensão a verificar)

- **Lei nº 12.965/2014, art. 15:** provedores de aplicação (o que a ArenaX1
  é) devem guardar **registros de acesso à aplicação por 6 meses**, sob
  sigilo, em ambiente controlado — e devem **eliminar** depois desse prazo,
  salvo ordem judicial. [Walmar Andrade — guarda de registros](https://walmarandrade.com.br/guarda-de-registros/)
- Isso é uma obrigação de **guardar por pelo menos 6 meses**, não conflita
  com a política de anonimização de conta que já desenhamos (que preserva
  histórico de transação/partida indefinidamente como âncora de FK) — mas
  vale confirmar que os registros de acesso (login, IP, timestamps) também
  estão sendo mantidos por esse prazo mínimo, e não descartados antes por
  engano numa limpeza de dados mais agressiva.

**Pergunta para o advogado:** confirmar que a política de retenção/exclusão
de conta (documentada em `regras-do-sistema.md`, seção 6) não colide com essa
obrguação mínima de 6 meses para logs de acesso — hoje o sistema não distingue
"dado de conta" de "log de acesso" explicitamente.

---

## 7. Código de Defesa do Consumidor (CDC) — aplicável independente da classificação

- CDC se aplica a qualquer relação de consumo — cobrar rake, reter prêmio
  por 3 dias, definir regras de disputa, tudo isso precisa ser transparente e
  não abusivo, com informação clara ao usuário (o que já é o espírito do
  design que temos: notificações nomeando a causa, motivo explícito em cada
  retenção, etc. — boa base para o CDC).
- **Sinal do que vem por aí:** PL 1561/2026 propõe alterar o CDC para
  classificar como prática abusiva permitir/induzir uso de instrumento de
  pagamento que atrase o desembolso financeiro (cartão de crédito, crediário)
  em apostas — especificamente mirando superendividamento. Não vale pra
  ArenaX1 hoje (não aceita cartão/crédito, só Pix), mas é sinal de para onde
  a regulação de proteção ao consumidor está indo nesse setor. [Yogonet — PL 1561/2026](https://www.yogonet.com/brasil/noticias/2025/02/14/4459-spa-e-coaf-orientam-empresas-de-apostas-sobre-comunicacao-de-atividades-suspeitas)

**Pergunta para o advogado:** os Termos de Uso em elaboração cobrem
adequadamente as exigências de transparência do CDC (rake, prazos de
retenção, política de reembolso/cancelamento)?

---

## 8. Tributário — fora do escopo deste documento, mas não pode ser esquecido

- Rake é receita de serviço — tratamento tributário (ISS, PIS/COFINS, etc.)
  precisa de contador/advogado tributário, não é uma pergunta que pesquisa
  na internet resolve com segurança.
- Prêmios pagos a jogadores podem ter retenção na fonte dependendo de como
  forem enquadrados (prêmio de jogo vs. mera devolução/ganho entre
  particulares) — isso também depende diretamente da classificação da
  seção 1.

**Ação recomendada:** incluir um contador/advogado tributário na mesma
rodada de consulta, não só o advogado de regulação de jogos.

---

## 9. O que monitorar (paisagem em movimento, não uma foto parada)

- Marco Legal dos Jogos Eletrônicos (14.852/2024) e a categoria fantasy
  games/skill games têm histórico recente de mudança de escopo durante a
  tramitação — sinal de que reguladores ainda estão desenhando essas
  fronteiras.
- PL 1561/2026 (CDC x superendividamento em apostas) e outros projetos sobre
  destinação de arrecadação de apostas mostram o Congresso ativo nessa área
  em 2026 — vale checagem periódica, não é assunto "resolvido e esquecido".

---

## 10. Lista consolidada de perguntas para o advogado

**Prioridade 1 — decide se o negócio existe do jeito atual:**
1. Dado que o precedente de habilidade mais citado (TJSC) protege o jogo mas
   não a aposta em dinheiro sobre o resultado, e que a Lei 14.852/2024
   agrupa explicitamente "qualquer jogo com aposta e prêmio real" junto do
   regime de apostas — qual a exposição real da ArenaX1 ao art. 50 do
   Decreto-Lei 3.688/1941?
2. Essa exposição atinge pessoalmente os sócios/administradores, ou se
   limita à pessoa jurídica?

**Prioridade 2 — bloqueia publicação de política/produto:**
3. O CPF coletado para verificação de idade (Lei FELCA) pode ser reaproveitado
   para antifraude de Pix, ou a lei exige segregação de finalidade? A
   Política de Privacidade hoje descreve uso duplo — isso pode ser
   caracterização arriscada sob a LGPD/FELCA se a segregação for exigida.
4. O que satisfaz "verificação a cada acesso" (Lei FELCA) na prática —
   reverificação periódica, ou uma checagem única robusta é suficiente?
5. No volume atual, a ArenaX1 precisa de registro/autorização do BACEN pra
   operar a carteira com saque real, ou a estrutura via gateway Pix já
   autorizado resolve isso?

**Prioridade 3 — ajustes de documento/produto, não bloqueiam o negócio:**
6. Faz sentido adotar controles antilavagem voluntários mesmo fora do regime
   formal da 14.790? Existe exposição mesmo sem enquadramento formal?
7. A política de retenção/exclusão de conta precisa diferenciar "dado de
   conta" de "log de acesso" para cumprir o mínimo de 6 meses do Marco Civil?
8. O termo "anonimização" usado na Política de Privacidade está correto
   tecnicamente, ou o que fazemos (mantendo dados de transação vinculados a
   um ID interno, possivelmente reconectável via registros do gateway de
   pagamento) é, na verdade, pseudonimização sob a LGPD? Isso muda o regime
   aplicável (dado anonimizado sai do escopo da LGPD; pseudonimizado, não).
9. Os Termos de Uso em elaboração cobrem as exigências de transparência do
   CDC adequadamente (retenção de saldo em apuração, taxa de depósito,
   critérios de mediação)?
10. Encaminhar em paralelo a um contador/advogado tributário: tratamento
    fiscal do rake e de eventual retenção sobre prêmios.

**Nota sobre qualidade das fontes:** a versão anterior deste documento citava
majoritariamente artigos secundários (Jusbrasil, portais especializados em
apostas). Nesta revisão, os pontos mais sensíveis (Seção 1) foram
reconferidos contra fontes primárias (Planalto, Portal do STF) ou análises
jurídicas de veículos especializados (ConJur). Ainda assim, o advogado deve
tratar todo o conteúdo abaixo da Seção 1 como pesquisa de apoio, não como
citação verificada em fonte primária linha a linha.

---

*Este documento deve ser lido junto com `regras-do-sistema.md` (como o
sistema funciona de fato) e os rascunhos de Termos de Uso / Política de
Privacidade / Jogo Responsável (ainda em elaboração).*
