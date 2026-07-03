<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import amigos from '@/assets/amigos.png'
import { vReveal, prefersReduce } from '@/composables/useReveal'
import {
  ArrowRight,
  Gamepad2,
  Star,
  CheckCircle2,
  Goal,
  Award,
  UserPlus,
  Swords,
  Wallet,
  Lock,
  Gavel,
  Zap,
  Clock,
  Trophy,
  BadgeCheck,
  Dices,
  Network,
  Users,
  QrCode,
  Crown,
  Share2,
} from '@lucide/vue'

/* ── Prêmio "ao vivo" (apenas decorativo, transmite atividade) ── */
const prizePool = ref(24500)
const prizePoolFmt = computed(() =>
  prizePool.value.toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }),
)
let prizeTimer: number | undefined

onMounted(() => {
  if (prefersReduce()) return
  prizeTimer = window.setInterval(() => {
    const delta = (Math.random() - 0.4) * 220
    prizePool.value = Math.min(28000, Math.max(21000, Math.round(prizePool.value + delta)))
  }, 2600)
})
onBeforeUnmount(() => {
  if (prizeTimer) clearInterval(prizeTimer)
})

/* ── Conteúdo ── */
const stats = [
  { value: 'R$ 1,2M+', label: 'Pago em prêmios' },
  { value: '48 mil', label: 'Partidas disputadas' },
  { value: '6.463', label: 'Jogadores ativos' },
  { value: '< 5 min', label: 'Tempo médio de saque' },
]

const steps = [
  {
    n: '01',
    icon: UserPlus,
    title: 'Crie sua conta grátis',
    desc: 'Cadastro em segundos, sem mensalidade e sem burocracia. É só criar e começar.',
  },
  {
    n: '02',
    icon: Swords,
    title: 'Crie ou entre num desafio',
    desc: 'Escolha o jogo (EA FC ou eFootball), a plataforma (PS5, Xbox, PC) e a aposta. O matchmaking acha seu rival na hora.',
  },
  {
    n: '03',
    icon: Wallet,
    title: 'Vença e receba o prêmio',
    desc: 'Reporte o placar, a plataforma valida e o prêmio cai na sua carteira. Saque quando quiser, com segurança.',
  },
]

const features = [
  {
    icon: Lock,
    title: 'Carteira protegida',
    desc: 'Os valores ficam retidos pela ArenaX1 e só são liberados ao vencedor. Ninguém toca no dinheiro dos outros.',
  },
  {
    icon: Gavel,
    title: 'Antifraude & disputas',
    desc: 'Todo resultado passa por duplo check. Deu divergência? A mediação com provas resolve. Tolerância zero com batota.',
  },
  {
    icon: Zap,
    title: 'Saque sem complicação',
    desc: 'Depósito e saque sem taxas escondidas e sem letras miúdas. Seu dinheiro, do seu jeito.',
  },
  {
    icon: Clock,
    title: 'Matchmaking 24/7',
    desc: 'Tem sempre alguém pra jogar. Encontre adversário do seu nível a qualquer hora do dia.',
  },
]

const tourneyFeatures = [
  {
    icon: Trophy,
    title: 'Estatísticas automáticas',
    desc: 'Melhor ataque, pior defesa, saldo de gols e ranking de vitórias — calculados a partir dos placares que vocês lançam.',
  },
  {
    icon: BadgeCheck,
    title: 'Card do Campeão',
    desc: 'No fim do torneio geramos um card do vencedor com os números da campanha — pronto pra postar nos Stories.',
  },
  {
    icon: Dices,
    title: 'Roleta de Times & Draft',
    desc: 'Sorteia quem joga com cada time e acaba com a briga eterna por PSG ou Real Madrid.',
  },
]

const championStats = [
  { k: 'GF', v: '14' },
  { k: 'GS', v: '3' },
  { k: 'SG', v: '+11' },
  { k: 'VIT', v: '3' },
  { k: 'JOG', v: '3' },
  { k: '%V', v: '100' },
]

const tools = [
  { icon: Dices, title: 'Roleta de Times', desc: 'Sorteie os times de cada jogador.' },
  { icon: Network, title: 'Gerador de Chave', desc: 'Monte o mata-mata em 1 clique.' },
  { icon: Users, title: 'Roleta de Draft', desc: 'Distribua jogadores entre os capitães.' },
]
</script>

<template>
  <div class="overflow-x-clip">
    <!-- ══════════════════ HERO ══════════════════ -->
    <section class="relative -mt-16 overflow-hidden">
      <!-- Orbs ambiente -->
      <div
        class="pointer-events-none absolute -left-24 top-44 h-72 w-72 rounded-full bg-primary/20 blur-[110px]"
      ></div>
      <div
        class="pointer-events-none absolute -right-10 bottom-0 h-80 w-80 rounded-full bg-accent/20 blur-[120px]"
      ></div>

      <div
        class="relative mx-auto grid max-w-7xl grid-cols-1 items-center gap-12 px-6 pb-20 pt-32 lg:grid-cols-2 lg:px-20 lg:pb-28 lg:pt-44"
      >
        <!-- Coluna de texto -->
        <div class="flex flex-col gap-7">
          <span
            class="inline-flex w-fit items-center gap-2 rounded-pill border border-hairline bg-surface-1/70 px-3 py-1.5 text-eyebrow uppercase tracking-widest text-ink-muted backdrop-blur"
          >
            <span class="size-1.5 rounded-full bg-accent shadow-glow-accent"></span>
            Skill-gaming • EA FC e eFootball
          </span>

          <h1 class="font-display text-[40px] font-bold leading-[1.05] tracking-tight text-ink sm:text-[52px] lg:text-[62px]">
            Transforme cada partida de futebol em
            <span class="text-gradient-blue">dinheiro real</span>.
          </h1>

          <p class="max-w-xl text-body-lg text-ink-subtle">
            X1, torneios e resenha entre amigos — com a segurança de uma fintech e a
            praticidade que a resenha pede. Você joga, a ArenaX1 cuida do resto.
          </p>

          <div class="flex flex-col gap-3 sm:flex-row sm:gap-4">
            <router-link
              to="/register"
              class="group inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-7 py-4 text-button font-semibold text-white no-underline shadow-glow-primary transition-all duration-200 hover:bg-primary-hover hover:shadow-[0_0_50px_-6px_rgba(59,130,246,0.6)]"
            >
              Criar conta grátis
              <ArrowRight :size="20" class="transition-transform duration-200 group-hover:translate-x-0.5" />
            </router-link>
            <router-link
              to="/desafios"
              class="inline-flex items-center justify-center gap-2 rounded-xl border border-hairline-strong bg-surface-1/50 px-7 py-4 text-button font-semibold text-ink no-underline backdrop-blur transition-colors duration-200 hover:border-hairline-tertiary hover:bg-surface-2"
            >
              <Gamepad2 :size="20" class="text-accent" />
              Ver partidas ao vivo
            </router-link>
          </div>

          <!-- Prova social -->
          <div class="flex flex-wrap items-center gap-4 pt-2">
            <div class="flex -space-x-2.5">
              <span
                v-for="(initials, i) in ['DY', 'AL', 'LU', 'T1']"
                :key="i"
                class="grid size-9 place-items-center rounded-full border-2 border-canvas bg-surface-3 text-[11px] font-bold text-ink-muted"
              >{{ initials }}</span>
            </div>
            <p class="text-body-sm text-ink-subtle">
              <span class="font-semibold text-ink">+6.463</span> jogando agora
              <span class="mx-1.5 text-ink-tertiary">·</span>
              <span class="inline-flex items-center gap-1 text-accent">
                <Star :size="16" fill="currentColor" />4,9
              </span>
            </p>
          </div>

          <!-- Chips de confiança -->
          <div class="flex flex-wrap gap-x-5 gap-y-2 text-caption text-ink-tertiary">
            <span class="inline-flex items-center gap-1.5">
              <CheckCircle2 :size="16" class="text-semantic-success" />
              Sem taxa de saque
            </span>
            <span class="inline-flex items-center gap-1.5">
              <CheckCircle2 :size="16" class="text-semantic-success" />
              Saque simplificado
            </span>
            <span class="inline-flex items-center gap-1.5">
              <CheckCircle2 :size="16" class="text-semantic-success" />
              Antifraude 24/7
            </span>
          </div>

          <!-- Jogos e plataformas suportados -->
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1.5 border-t border-hairline pt-5 text-caption text-ink-tertiary">
            <span class="inline-flex items-center gap-1.5 font-medium text-ink-subtle">
              <Goal :size="18" class="text-accent" />
              EA FC (FIFA)
            </span>
            <span class="text-ink-tertiary/60">·</span>
            <span class="font-medium text-ink-subtle">eFootball</span>
            <span class="text-ink-tertiary/60">·</span>
            <span>PS5 · Xbox · PC</span>
          </div>
        </div>

        <!-- Coluna visual (desktop): amigos no sofá -->
        <div class="relative hidden lg:block">
          <div
            class="animate-float relative overflow-hidden rounded-3xl border border-hairline-strong shadow-card-premium ring-1 ring-white/5"
          >
            <img
              :src="amigos"
              alt="Amigos jogando juntos no sofá"
              class="aspect-[16/11] w-full object-cover"
            />
            <div
              class="pointer-events-none absolute inset-0 bg-gradient-to-t from-canvas/80 via-canvas/10 to-transparent"
            ></div>
          </div>

          <!-- Card AO VIVO (prêmio em jogo) -->
          <div
            class="glass-strong animate-pulse-glow absolute -bottom-6 -left-6 w-60 rounded-2xl border border-primary/25 p-5"
          >
            <div class="mb-3 flex items-center justify-between">
              <span class="text-eyebrow uppercase tracking-widest text-ink-subtle">Prêmio em jogo agora</span>
              <span class="relative flex size-2.5">
                <span class="absolute inline-flex size-full animate-ping rounded-full bg-accent opacity-75"></span>
                <span class="relative inline-flex size-2.5 rounded-full bg-accent"></span>
              </span>
            </div>
            <p class="font-display text-[28px] font-bold tabular-nums text-ink">{{ prizePoolFmt }}</p>
            <p class="mt-1 text-caption text-ink-tertiary">em 312 partidas abertas</p>
          </div>

          <!-- Mini chip de resultado -->
          <div
            class="glass absolute -right-4 top-6 flex items-center gap-3 rounded-xl border border-hairline px-4 py-3"
          >
            <div class="grid size-9 place-items-center rounded-lg bg-primary/15 text-primary">
              <Award :size="20" />
            </div>
            <div class="leading-tight">
              <p class="text-caption text-ink-tertiary">Vitória de @rapha</p>
              <p class="text-body-sm font-semibold text-semantic-success">+ R$ 50,00</p>
            </div>
          </div>
        </div>

        <!-- Card AO VIVO compacto (mobile) -->
        <div
          class="glass-strong flex items-center justify-between rounded-2xl border border-accent/20 p-4 lg:hidden"
        >
          <div>
            <p class="text-eyebrow uppercase tracking-widest text-ink-subtle">Prêmio em jogo agora</p>
            <p class="font-display text-2xl font-bold tabular-nums text-ink">{{ prizePoolFmt }}</p>
          </div>
          <span class="relative flex size-3">
            <span class="absolute inline-flex size-full animate-ping rounded-full bg-accent opacity-75"></span>
            <span class="relative inline-flex size-3 rounded-full bg-accent"></span>
          </span>
        </div>
      </div>
    </section>

    <!-- ══════════════════ BARRA DE STATS ══════════════════ -->
    <section class="border-y border-hairline bg-surface-1/40">
      <div class="mx-auto grid max-w-7xl grid-cols-2 gap-px px-6 lg:grid-cols-4 lg:px-20">
        <div
          v-for="(s, i) in stats"
          :key="s.label"
          v-reveal="`${i * 80}ms`"
          class="flex flex-col items-center gap-1 px-4 py-8 text-center"
        >
          <span class="font-display text-3xl font-bold tabular-nums text-ink lg:text-4xl">{{ s.value }}</span>
          <span class="text-caption uppercase tracking-widest text-ink-tertiary">{{ s.label }}</span>
        </div>
      </div>
    </section>

    <!-- ══════════════════ COMO FUNCIONA ══════════════════ -->
    <section class="mx-auto max-w-7xl px-6 py-24 lg:px-20 lg:py-section">
      <div v-reveal class="mx-auto mb-16 max-w-2xl text-center">
        <span class="text-eyebrow uppercase tracking-widest text-accent">Como funciona</span>
        <h2 class="mt-3 font-display text-display-md font-bold text-ink">Do controle ao prêmio em 3 passos</h2>
        <p class="mt-4 text-body text-ink-subtle">
          Simples como deveria ser. Sem planilha, sem confiança cega, sem dor de cabeça.
        </p>
      </div>

      <div class="relative grid gap-6 md:grid-cols-3">
        <!-- linha conectora -->
        <div
          class="absolute left-0 right-0 top-9 hidden h-px bg-gradient-to-r from-transparent via-hairline-strong to-transparent md:block"
        ></div>
        <div
          v-for="(step, i) in steps"
          :key="step.n"
          v-reveal="`${i * 120}ms`"
          class="glow-border relative rounded-2xl border border-hairline bg-surface-1/60 p-7 backdrop-blur transition-colors duration-300 hover:border-hairline-strong"
        >
          <div class="mb-5 flex items-center justify-between">
            <span
              class="grid size-12 place-items-center rounded-xl bg-primary/15 text-primary ring-1 ring-primary/20"
            >
              <component :is="step.icon" />
            </span>
            <span class="font-display text-4xl font-bold text-hairline-tertiary">{{ step.n }}</span>
          </div>
          <h3 class="mb-2 text-card-title font-semibold text-ink">{{ step.title }}</h3>
          <p class="text-body-sm text-ink-subtle">{{ step.desc }}</p>
        </div>
      </div>
    </section>

    <!-- ══════════════════ TORNEIO DE SOFÁ ══════════════════ -->
    <section class="relative overflow-hidden border-y border-hairline">
      <!-- ambiente -->
      <div class="absolute inset-0 bg-gradient-to-b from-surface-1/30 via-canvas to-canvas"></div>
      <div
        class="pointer-events-none absolute right-0 top-1/4 h-80 w-80 rounded-full bg-accent/10 blur-[120px]"
      ></div>

      <div class="relative mx-auto max-w-7xl px-6 py-24 lg:px-20 lg:py-section">
        <div v-reveal class="mb-14 max-w-2xl">
          <span
            class="inline-flex items-center gap-2 rounded-pill bg-accent/15 px-3 py-1 text-eyebrow font-semibold uppercase tracking-widest text-accent"
          >
            <Zap :size="15" />
            Novo · Grátis pra sempre
          </span>
          <h2 class="mt-4 font-display text-display-md font-bold leading-tight text-ink">
            O Torneio de Sofá
          </h2>
          <p class="mt-4 text-body-lg text-ink-subtle">
            Juntou a galera? Em 30 segundos você monta a chave, joga e bate o chinelo na resenha.
            <span class="text-ink">Só o anfitrião precisa de conta</span> — digite os nomes dos 4, 8
            ou 16 e o sistema sorteia tudo na hora.
          </p>
        </div>

        <div class="grid items-start gap-12 lg:grid-cols-2">
          <!-- Esquerda: conteúdo -->
          <div class="flex flex-col gap-8">
            <!-- chips de formato -->
            <div class="flex flex-wrap gap-2.5">
              <span
                v-for="f in ['4 jogadores', '8 jogadores', '16 jogadores', 'Mata-mata', 'Fase de grupos']"
                :key="f"
                class="rounded-pill border border-hairline-strong bg-surface-2/60 px-3.5 py-1.5 text-body-sm font-medium text-ink-muted"
              >{{ f }}</span>
            </div>

            <!-- features do torneio -->
            <div class="flex flex-col gap-5">
              <div
                v-for="(t, i) in tourneyFeatures"
                :key="t.title"
                v-reveal="`${i * 100}ms`"
                class="flex gap-4"
              >
                <span
                  class="grid size-11 shrink-0 place-items-center rounded-xl bg-accent/15 text-accent ring-1 ring-accent/20"
                >
                  <component :is="t.icon" :size="22" />
                </span>
                <div>
                  <h3 class="text-card-title font-semibold text-ink">{{ t.title }}</h3>
                  <p class="mt-1 text-body-sm text-ink-subtle">{{ t.desc }}</p>
                </div>
              </div>
            </div>

            <!-- Upsell sutil -->
            <div
              v-reveal
              class="relative overflow-hidden rounded-2xl border border-accent/25 bg-gradient-to-br from-accent/10 to-transparent p-5"
            >
              <div class="flex items-start gap-3">
                <QrCode class="text-accent" />
                <div>
                  <p class="text-body-sm font-semibold text-ink">
                    Quer deixar a resenha mais séria?
                  </p>
                  <p class="mt-1 text-body-sm text-ink-subtle">
                    Transforme o torneio grátis em disputa por dinheiro real: a galera lê o QR Code,
                    paga a entrada online e o anfitrião ainda ganha
                    <span class="font-semibold text-accent">cashback</span> no fechamento do pote.
                  </p>
                </div>
              </div>
            </div>

            <div class="flex flex-col gap-3 sm:flex-row">
              <router-link
                to="/register"
                class="group inline-flex items-center justify-center gap-2 rounded-xl bg-accent px-7 py-3.5 text-button font-semibold text-white no-underline shadow-glow-accent transition-all duration-200 hover:bg-accent-hover"
              >
                Criar Torneio Rápido
                <ArrowRight :size="20" class="transition-transform duration-200 group-hover:translate-x-0.5" />
              </router-link>
              <router-link
                to="/como-funciona"
                class="inline-flex items-center justify-center gap-2 rounded-xl border border-hairline-strong px-7 py-3.5 text-button font-semibold text-ink no-underline transition-colors duration-200 hover:bg-surface-2"
              >
                Ver exemplo de chave
              </router-link>
            </div>
          </div>

          <!-- Direita: mockup do chaveamento + card do campeão -->
          <div v-reveal="'120ms'" class="flex flex-col gap-6">
            <!-- Painel de chaveamento (glass) -->
            <div class="glass-strong rounded-2xl border border-hairline p-5 shadow-card-premium sm:p-6">
              <div class="mb-5 flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <Network class="text-accent" />
                  <span class="text-body-sm font-semibold text-ink">Resenha de Sábado</span>
                </div>
                <span class="rounded-pill bg-surface-3 px-2.5 py-1 text-caption text-ink-subtle">
                  Mata-mata · 4
                </span>
              </div>

              <!-- Bracket -->
              <div class="flex items-center gap-2 sm:gap-3">
                <!-- Semifinais -->
                <div class="flex-1 space-y-3">
                  <div class="rounded-lg border border-hairline bg-surface-2/80 p-2.5">
                    <div class="flex items-center justify-between rounded-md bg-accent/15 px-2 py-1 text-body-sm font-semibold text-ink">
                      <span>João</span><span class="tabular-nums text-accent">3</span>
                    </div>
                    <div class="flex items-center justify-between px-2 py-1 text-body-sm text-ink-subtle">
                      <span>Bruno</span><span class="tabular-nums">1</span>
                    </div>
                  </div>
                  <div class="rounded-lg border border-hairline bg-surface-2/80 p-2.5">
                    <div class="flex items-center justify-between px-2 py-1 text-body-sm text-ink-subtle">
                      <span>Léo</span><span class="tabular-nums">2</span>
                    </div>
                    <div class="flex items-center justify-between rounded-md bg-accent/15 px-2 py-1 text-body-sm font-semibold text-ink">
                      <span>Caio</span><span class="tabular-nums text-accent">4</span>
                    </div>
                  </div>
                </div>

                <!-- conector -->
                <div class="flex w-4 shrink-0 items-center sm:w-6">
                  <div class="h-px w-full bg-gradient-to-r from-hairline-strong to-accent/60"></div>
                </div>

                <!-- Final -->
                <div class="flex-1">
                  <p class="mb-1.5 text-center text-caption uppercase tracking-widest text-ink-tertiary">Final</p>
                  <div class="rounded-lg border border-accent/30 bg-surface-2/80 p-2.5 shadow-glow-accent">
                    <div class="flex items-center justify-between rounded-md bg-accent/20 px-2 py-1 text-body-sm font-semibold text-ink">
                      <span>João</span><span class="tabular-nums text-accent">2</span>
                    </div>
                    <div class="flex items-center justify-between px-2 py-1 text-body-sm text-ink-subtle">
                      <span>Caio</span><span class="tabular-nums">1</span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- rodapé: estatística -->
              <div class="mt-5 flex items-center justify-between border-t border-hairline pt-4 text-body-sm">
                <span class="flex items-center gap-1.5 text-ink-subtle">
                  <Goal :size="18" class="text-accent" />
                  Melhor ataque
                </span>
                <span class="font-semibold text-ink">João · 14 gols</span>
              </div>
            </div>

            <!-- Card do Campeão (estilo Ultimate Team) -->
            <div class="flex justify-end">
              <div
                class="w-48 rounded-2xl bg-gradient-to-b from-amber-300/70 via-accent/40 to-transparent p-px shadow-glow-accent sm:rotate-3"
              >
                <div class="rounded-2xl bg-surface-2/95 p-4 backdrop-blur">
                  <div class="flex items-start justify-between text-amber-300">
                    <div class="leading-none">
                      <p class="font-display text-3xl font-bold">94</p>
                      <p class="text-caption font-semibold tracking-widest">OVR</p>
                    </div>
                    <Crown fill="currentColor" />
                  </div>
                  <div class="my-3 grid h-16 place-items-center">
                    <span class="grid size-14 place-items-center rounded-full bg-gradient-to-b from-amber-300/30 to-transparent font-display text-xl font-bold text-ink ring-1 ring-amber-300/40">JO</span>
                  </div>
                  <p class="text-center font-display text-body-sm font-bold tracking-wide text-ink">JOÃO “O REI”</p>
                  <p class="mb-3 text-center text-[10px] uppercase tracking-widest text-amber-300/80">Campeão da rodada</p>
                  <div class="grid grid-cols-3 gap-x-2 gap-y-1.5 text-center">
                    <div v-for="cs in championStats" :key="cs.k">
                      <p class="font-display text-body-sm font-bold tabular-nums text-ink">{{ cs.v }}</p>
                      <p class="text-[9px] uppercase tracking-wider text-ink-tertiary">{{ cs.k }}</p>
                    </div>
                  </div>
                  <div class="mt-3 flex items-center justify-center gap-1 text-[10px] font-semibold text-accent">
                    <Share2 :size="14" />
                    Compartilhar nos Stories
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ POR QUE ARENAX1 (features) ══════════════════ -->
    <section class="mx-auto max-w-7xl px-6 py-24 lg:px-20 lg:py-section">
      <div v-reveal class="mx-auto mb-16 max-w-2xl text-center">
        <span class="text-eyebrow uppercase tracking-widest text-accent">Confiança em primeiro lugar</span>
        <h2 class="mt-3 font-display text-display-md font-bold text-ink">
          Feito pra você apostar sua habilidade — não sua sorte
        </h2>
        <p class="mt-4 text-body text-ink-subtle">
          Fuga total do visual poluído de site de aposta. Aqui é tipo painel de fintech: limpo, seguro e direto ao ponto.
        </p>
      </div>

      <div class="grid gap-5 sm:grid-cols-2">
        <div
          v-for="(f, i) in features"
          :key="f.title"
          v-reveal="`${(i % 2) * 100}ms`"
          class="glow-border group rounded-2xl border border-hairline bg-surface-1/60 p-7 transition-colors duration-300 hover:border-hairline-strong"
        >
          <span
            class="mb-5 grid size-12 place-items-center rounded-xl bg-primary/15 text-primary ring-1 ring-primary/20 transition-transform duration-300 group-hover:scale-105"
          >
            <component :is="f.icon" :size="26" />
          </span>
          <h3 class="mb-2 text-card-title font-semibold text-ink">{{ f.title }}</h3>
          <p class="text-body-sm text-ink-subtle">{{ f.desc }}</p>
        </div>
      </div>
    </section>

    <!-- ══════════════════ FERRAMENTAS GRÁTIS ══════════════════ -->
    <section class="border-t border-hairline bg-surface-1/30">
      <div class="mx-auto max-w-7xl px-6 py-20 lg:px-20">
        <div class="flex flex-col gap-8 lg:flex-row lg:items-center lg:justify-between">
          <div v-reveal class="max-w-md">
            <span class="text-eyebrow uppercase tracking-widest text-accent">Ferramentas grátis</span>
            <h2 class="mt-3 font-display text-headline font-bold text-ink">
              Resolva a treta antes de começar
            </h2>
            <p class="mt-3 text-body-sm text-ink-subtle">
              Utilitários rápidos pra qualquer rolê — sem cadastro. Use, compartilhe e quando quiser
              valer dinheiro de verdade, é só criar a conta.
            </p>
          </div>
          <div class="grid flex-1 gap-4 sm:grid-cols-3">
            <div
              v-for="(tool, i) in tools"
              :key="tool.title"
              v-reveal="`${i * 90}ms`"
              class="group cursor-pointer rounded-2xl border border-hairline bg-surface-2/60 p-5 transition-all duration-300 hover:-translate-y-1 hover:border-accent/30"
            >
              <component :is="tool.icon" :size="28" class="mb-3 text-accent" />
              <h3 class="text-body font-semibold text-ink">{{ tool.title }}</h3>
              <p class="mt-1 text-caption text-ink-tertiary">{{ tool.desc }}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ CTA FINAL ══════════════════ -->
    <section class="px-6 py-24 lg:px-20 lg:py-section">
      <div
        v-reveal
        class="relative mx-auto max-w-7xl overflow-hidden rounded-[2rem] border border-hairline bg-gradient-to-br from-primary/90 via-primary to-primary-focus p-10 text-center sm:p-16 lg:p-20"
      >
        <div
          class="pointer-events-none absolute -right-16 -top-16 size-72 rounded-full bg-accent/30 blur-[100px]"
        ></div>
        <div
          class="pointer-events-none absolute -bottom-20 -left-10 size-72 rounded-full bg-white/10 blur-[100px]"
        ></div>
        <div class="relative">
          <h2 class="mx-auto max-w-3xl font-display text-display-md font-bold leading-tight text-white">
            Pronto pra transformar sua paixão por futebol em dinheiro?
          </h2>
          <p class="mx-auto mt-4 max-w-xl text-body-lg text-white/80">
            Crie sua conta grátis, chame a galera e comece a jogar hoje mesmo.
          </p>
          <div class="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <router-link
              to="/register"
              class="inline-flex items-center justify-center gap-2 rounded-xl bg-white px-8 py-4 text-button font-bold text-primary no-underline shadow-xl transition-transform duration-200 hover:scale-105"
            >
              Começar agora
              <ArrowRight :size="20" />
            </router-link>
            <router-link
              to="/torneios"
              class="inline-flex items-center justify-center gap-2 rounded-xl border border-white/30 bg-white/10 px-8 py-4 text-button font-semibold text-white no-underline backdrop-blur transition-colors duration-200 hover:bg-white/20"
            >
              Explorar torneios
            </router-link>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
