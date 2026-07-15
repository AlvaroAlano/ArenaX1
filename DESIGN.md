# Documentação de Design: ArenaX1 (mono-lime dark)

> Atualizado em 15/07/2026. A versão anterior deste documento descrevia um
> template de referência (estética laranja/vermelho, "crypto/fintech Web3")
> usado só como inspiração inicial — **foi substituído** pelo rebrand de
> 02/07 e não reflete mais o site. Fonte de verdade real: os tokens em
> `frontend/tailwind.config.js` e os globais em `frontend/src/assets/main.css`.

## 1. Visão Geral

Dark mode com cor de marca única (mono-lime): verde-limão neon sobre fundo
cinza-escuro neutro-frio — **nunca preto absoluto**. Tom provocativo
("Você fala que é o melhor. Prova valendo grana."), fugindo tanto do
padrão "cassino neon multicolorido" quanto de um fintech genérico
azul/branco. Tipografia geométrica peso 900 em caixa alta pra títulos,
sans-serif neutra pro corpo.

## 2. Paleta de Cores (`tailwind.config.js`)

- **Marca (mono-lime):** `primary` / `accent` = `#C8F03C` (mesma cor,
  esquema mono). `primary-hover` = `#DAFB60`. `primary-focus` = `#aad42f`.
  Botões preenchidos com `primary` usam texto **escuro** (`text-canvas`),
  nunca branco.
- **Fundo (canvas):** `#15181e` — cinza-escuro neutro-frio, não preto.
  Bandas de seção alternadas usam `surface-1` (`#1b1f26`); cards usam
  `surface-2` (`#21252e`) até `surface-4` (`#2f353f`) pra profundidade.
- **Linhas/bordas:** `hairline` (`#323844`) até `hairline-tertiary`
  (`#4b525e`), sempre sutis, nunca competindo com o conteúdo.
- **Texto:** `ink` (`#f2f5f7`, principal) → `ink-muted` → `ink-subtle` →
  `ink-tertiary` (`#666c76`, o mais apagado), escala de ênfase por
  contraste, não por cor.
- **Semântico:** `semantic-success` (`#27a644`), `semantic-error`
  (`#ef4444`) — únicas cores fora do mono-lime, reservadas pra
  feedback de sistema (nunca decorativas).

## 3. Tipografia

- **Display/títulos:** Archivo, peso 900, uppercase, tracking apertado —
  classe `font-display`. Escala em `fontSize` do Tailwind:
  `display-xl` (80px) → `display-lg` (56px) → `display-md` (40px) →
  `headline` (28px) → `card-title` (22px).
- **Corpo:** Inter (`font-sans`), pesos 400-600. `body-lg` (18px) →
  `body` (16px) → `body-sm` (14px) → `caption` (12px).
- **Monoespaçada:** JetBrains Mono, usada só em valores tabulares
  (`tabular-nums`) como saldo e placar.

## 4. Efeitos e Componentes

- **Glassmorphism controlado:** `.glass` (blur 20px, fundo
  `rgba(33,37,46,0.62)`) e `.glass-strong` (blur 40px, mais opaco) —
  usado em cards flutuantes sobre imagem (hero), não em superfícies
  grandes.
- **Glow de marca:** sombras `shadow-glow-primary`/`shadow-glow-pill` em
  verde-limão translúcido, em CTAs e elementos "ao vivo" — reforça
  energia sem virar poluição visual.
- **Cards premium:** `shadow-card-premium` (sombra profunda e difusa,
  `rgba(0,0,0,0.7)`) em elementos hero/destaque.
- **Scroll-reveal:** diretiva `v-reveal` (`useReveal.ts`) via
  IntersectionObserver, com stagger opcional (`v-reveal="'120ms'"`) e
  respeito a `prefers-reduced-motion`.
- **Cantos:** escala de `borderRadius` de `xs` (4px) a `xxl` (24px), mais
  `pill` (9999px) pra badges/CTAs redondos.

## 5. Princípios

1. **Mono-lime, não multicolorido.** Uma cor de marca só — não introduzir
   novas cores de destaque sem necessidade real (isso já causou confusão
   antes; ver `design-direction` na memória do projeto).
2. **Cinza-escuro, nunca preto puro.** `canvas` é `#15181e`, não `#000`.
3. **Hierarquia por peso/tamanho/contraste, não por cor.** Cor é reservada
   pra marca (lime) e feedback semântico (sucesso/erro).
4. **Texto de botão preenchido é sempre escuro** (`text-canvas`) sobre
   fundo `primary` — nunca branco, é o que garante contraste AA.
5. **Sem CSS-in-JS.** Tudo via classes utilitárias do Tailwind + tokens
   do `tailwind.config.js`; `<style scoped>` só pra coisas que o Tailwind
   não cobre bem (scrollbar customizada, keyframes específicos).
