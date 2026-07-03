<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import amigos from '@/assets/amigos.png'
import { vReveal, prefersReduce } from '@/composables/useReveal'
import {
  ArrowRight,
  Star,
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
  Gamepad2,
} from '@lucide/vue'

/* ─────────────────────────────────────────────────────────
   Landing principal (rebrand verde-limão + Archivo + cinza-escuro).
   Usa os tokens do design system (canvas/surface/ink/primary), então
   ajustar a cor de fundo é uma mudança central no tailwind.config.js.
   Header/footer vêm do PublicLayout (AppHeader/AppFooter).
───────────────────────────────────────────────────────── */

/* ── Prêmio "ao vivo" (decorativo, transmite atividade) ── */
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

/* ── Stats do hero ── */
const stats = [
  { value: 'R$ 1,2M+', label: 'Pago em prêmios' },
  { value: '48 mil', label: 'Partidas disputadas' },
  { value: '6.463', label: 'Jogadores ativos' },
  { value: '< 5 min', label: 'Tempo médio de saque' },
]


/* ── Desafios abertos (formato real, ver backend-contract memory) ── */
const openChallenges = [
  { creator: '@lukinha77', initials: 'LK', bg: '#2A1E33', fg: '#C89FE5', rating: 4.7, wins: 89, winRate: 71, game: 'EA FC 25', platform: 'PS5', bet: 50 },
  { creator: '@matheuzets', initials: 'MA', bg: '#1E332A', fg: '#7FE5B0', rating: 4.6, wins: 142, winRate: 64, game: 'eFootball', platform: 'Crossplay', bet: 20 },
  { creator: '@vhgamer_of', initials: 'VH', bg: '#33301E', fg: '#E5D77F', rating: 4.9, wins: 203, winRate: 78, game: 'EA FC 25', platform: 'Xbox', bet: 500 },
]

/* ── Como funciona ── */
const steps = [
  { n: '01', icon: UserPlus, title: 'Crie sua conta', desc: 'Cadastro grátis em menos de 1 minuto. Só precisa de e-mail e do seu gamertag.' },
  { n: '02', icon: Wallet, title: 'Deposite via Pix', desc: 'A partir de R$ 5. Cai na carteira na hora, protegida por sistema antifraude.' },
  { n: '03', icon: Swords, title: 'Desafie e jogue', desc: 'Crie ou aceite um X1, combinem a sala e joguem no EA FC ou eFootball. O valor fica travado até o resultado.' },
  { n: '04', icon: Zap, title: 'Ganhou? Saca.', desc: 'O prêmio cai direto na carteira. Saque via Pix, sem burocracia.' },
]

/* ── Torneios em destaque (mesmo mock de TournamentsView.vue, sem backend próprio ainda) ── */
const tournamentsPreview = [
  { title: 'Copa Final de Semana', game: 'EA FC 25', prize: 80, entryFee: 10, date: 'Hoje, 20:00', enrolled: 4, maxPlayers: 8 },
  { title: 'Liga Noturna eFootball', game: 'eFootball', prize: 150, entryFee: 15, date: 'Amanhã, 22:00', enrolled: 12, maxPlayers: 16 },
  { title: 'Supercopa de Sexta', game: 'EA FC 25', prize: 500, entryFee: 25, date: 'Sexta, 21:00', enrolled: 16, maxPlayers: 32 },
]

/* ── Classificação (top fixos de RankingView.vue, ver backend-contract memory) ── */
const rankingPreview = [
  { rank: 1, nick: 'CarlosFC_10', initials: 'CF', bg: '#33301E', fg: '#E5D77F', wins: 180, winRate: 92.3, rating: 4.9 },
  { rank: 2, nick: 'MateusPro_99', initials: 'MP', bg: '#1E2A3A', fg: '#7FB2E5', wins: 165, winRate: 90.2, rating: 4.8 },
  { rank: 3, nick: 'ThiagoBR', initials: 'TB', bg: '#2A1E33', fg: '#C89FE5', wins: 150, winRate: 87.2, rating: 4.7 },
  { rank: 4, nick: 'RafaelBR_23', initials: 'RB', bg: '#1E332A', fg: '#7FE5B0', wins: 128, winRate: 81.0, rating: 4.5 },
  { rank: 5, nick: 'Lucas_Gamer_07', initials: 'LG', bg: '#33231E', fg: '#E5A07F', wins: 115, winRate: 80.4, rating: 4.4 },
]

/* ── Torneio de Sofá (grátis) ── */
const tourneyFeatures = [
  { icon: Trophy, title: 'Estatísticas automáticas', desc: 'Melhor ataque, pior defesa, saldo de gols e ranking de vitórias — calculados a partir dos placares que vocês lançam.' },
  { icon: BadgeCheck, title: 'Card do Campeão', desc: 'No fim do torneio geramos um card do vencedor com os números da campanha — pronto pra postar nos Stories.' },
  { icon: Dices, title: 'Roleta de Times & Draft', desc: 'Sorteia quem joga com cada time e acaba com a briga eterna por PSG ou Real Madrid.' },
]

const championStats = [
  { k: 'GF', v: '14' },
  { k: 'GS', v: '3' },
  { k: 'SG', v: '+11' },
  { k: 'VIT', v: '3' },
  { k: 'JOG', v: '3' },
  { k: '%V', v: '100' },
]

/* ── Segurança ── */
const features = [
  { icon: Lock, title: 'Carteira protegida', desc: 'O valor do X1 fica travado em custódia durante a partida. Ninguém saca o que não ganhou.' },
  { icon: Gavel, title: 'Antifraude & disputas', desc: 'Todo resultado passa por duplo check. Deu divergência? A mediação com provas resolve. Tolerância zero com batota.' },
  { icon: Zap, title: 'Pix em minutos', desc: 'Depósito cai na hora e o saque é processado via Pix, sem taxas escondidas e sem letras miúdas.' },
  { icon: Clock, title: 'Matchmaking 24/7', desc: 'Tem sempre alguém pra jogar. Encontre adversário do seu nível a qualquer hora do dia.' },
]

/* ── Ferramentas grátis ── */
const tools = [
  { icon: Dices, title: 'Roleta de Times', desc: 'Sorteie os times de cada jogador.' },
  { icon: Network, title: 'Gerador de Chave', desc: 'Monte o mata-mata em 1 clique.' },
  { icon: Users, title: 'Roleta de Draft', desc: 'Distribua jogadores entre os capitães.' },
]

/* ── FAQ ── */
const faqs = [
  {
    q: 'Como eu combino a partida com meu adversário?',
    a: 'Depois que o desafio é aceito, vocês têm acesso ao perfil um do outro na tela da partida. Trocam gamertag/ID, combinam a sala e jogam no EA FC ou eFootball. Terminou, cada um reporta o placar na plataforma.',
  },
  {
    q: 'E se o adversário mentir sobre o resultado?',
    a: 'O valor fica travado em custódia até os dois confirmarem o mesmo resultado. Se divergir, a partida entra em mediação: vocês enviam prova e nosso time decide. Quem mente é banido.',
  },
  {
    q: 'Quanto tempo demora o saque?',
    a: 'Saques são via Pix, sem valor mínimo abusivo e sem taxa escondida. O tempo pode variar conforme o horário e a análise antifraude.',
  },
  {
    q: 'A chave de mata-mata com amigos é grátis mesmo?',
    a: 'Sim, 100% grátis. Só o anfitrião precisa de conta — ele cadastra o nome da galera, escolhe os times (ou deixa o sistema sortear) e a chave de 4, 8 ou 16 sai pronta pra jogar.',
  },
  {
    q: 'Em quais plataformas eu posso jogar?',
    a: 'PS5, Xbox e PC — inclusive desafios Crossplay, pra encontrar adversário em qualquer plataforma.',
  },
]
</script>

<template>
  <div class="overflow-x-clip">
    <!-- ══════════════════ HERO ══════════════════ -->
    <section id="top" class="mx-auto grid max-w-[1600px] grid-cols-1 items-center gap-14 px-6 pb-16 pt-12 lg:grid-cols-2 lg:gap-16 lg:px-16 lg:pb-24 lg:pt-16">
      <div class="flex flex-col gap-7">
        <div class="flex flex-wrap items-center gap-2.5">
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">EA FC 25</span>
          <span class="size-1 rounded-full bg-ink/30"></span>
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">eFootball</span>
          <span class="size-1 rounded-full bg-ink/30"></span>
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-ink-tertiary">PS5 · Xbox · PC</span>
        </div>

        <h1 class="font-display text-[42px] font-black uppercase leading-[1.03] tracking-tight text-ink sm:text-[52px] lg:text-[62px]">
          Você fala que é o melhor.<br>
          <span class="text-primary">Prova valendo grana.</span>
        </h1>

        <p class="max-w-xl text-lg leading-relaxed text-ink-subtle">
          X1 valendo de <strong class="text-ink">R$ 5 a R$ 1.000</strong>, torneios de sofá grátis e ranking nacional. Deposita via Pix, desafia, joga e saca na hora. Sem desculpa.
        </p>

        <div class="flex flex-col gap-3.5 sm:flex-row">
          <router-link to="/register" class="group inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-7 py-4 text-base font-extrabold text-canvas no-underline shadow-glow-primary transition-colors hover:bg-primary-hover">
            Criar conta e desafiar
            <ArrowRight :size="20" class="transition-transform duration-200 group-hover:translate-x-0.5" />
          </router-link>
          <a href="#desafios" class="inline-flex items-center justify-center gap-2 rounded-xl border border-hairline-strong px-6 py-4 text-base font-bold text-ink no-underline transition-colors hover:border-primary hover:text-primary">
            <Gamepad2 :size="20" />
            Ver desafios abertos
          </a>
        </div>
      </div>

      <!-- Coluna visual -->
      <div class="relative hidden lg:block">
        <div class="animate-float relative overflow-hidden rounded-3xl border border-hairline-strong shadow-card-premium">
          <img :src="amigos" alt="Amigos jogando juntos no sofá" class="aspect-[16/11] w-full object-cover">
          <div class="pointer-events-none absolute inset-0 bg-gradient-to-t from-canvas/85 via-canvas/15 to-transparent"></div>
        </div>

        <!-- Card AO VIVO -->
        <div class="glass-strong absolute -bottom-6 -left-6 w-60 rounded-2xl border border-primary/25 p-5 shadow-card-premium">
          <div class="mb-3 flex items-center justify-between">
            <span class="text-[11px] font-bold uppercase tracking-widest text-ink-subtle">Prêmio em jogo agora</span>
            <span class="relative flex size-2.5">
              <span class="absolute inline-flex size-full animate-ping rounded-full bg-primary opacity-75"></span>
              <span class="relative inline-flex size-2.5 rounded-full bg-primary"></span>
            </span>
          </div>
          <p class="font-display text-[28px] font-black tabular-nums text-ink">{{ prizePoolFmt }}</p>
          <p class="mt-1 text-xs text-ink-tertiary">em 312 partidas abertas</p>
        </div>

        <!-- Mini chip -->
        <div class="glass absolute -right-4 top-6 flex items-center gap-3 rounded-xl border border-hairline px-4 py-3">
          <div class="grid size-9 place-items-center rounded-lg bg-primary/15 text-primary">
            <Award :size="20" />
          </div>
          <div class="leading-tight">
            <p class="text-xs text-ink-tertiary">Vitória de @rapha</p>
            <p class="text-sm font-semibold text-primary">+ R$ 50,00</p>
          </div>
        </div>
      </div>

      <!-- Card compacto (mobile) -->
      <div class="glass-strong flex items-center justify-between rounded-2xl border border-primary/20 p-4 lg:hidden">
        <div>
          <p class="text-[11px] font-bold uppercase tracking-widest text-ink-subtle">Prêmio em jogo agora</p>
          <p class="font-display text-2xl font-black tabular-nums text-ink">{{ prizePoolFmt }}</p>
        </div>
        <span class="relative flex size-3">
          <span class="absolute inline-flex size-full animate-ping rounded-full bg-primary opacity-75"></span>
          <span class="relative inline-flex size-3 rounded-full bg-primary"></span>
        </span>
      </div>
    </section>

    <!-- ══════════════════ BARRA DE STATS ══════════════════ -->
    <section class="border-y border-hairline bg-surface-1/40">
      <div class="mx-auto grid max-w-7xl grid-cols-2 gap-px px-6 lg:grid-cols-4 lg:px-20">
        <div
          v-for="s in stats"
          :key="s.label"
          class="flex flex-col items-center gap-1 px-4 py-8 text-center"
        >
          <span class="font-display text-3xl font-bold tabular-nums text-ink lg:text-4xl">{{ s.value }}</span>
          <span class="text-caption uppercase tracking-widest text-ink-tertiary">{{ s.label }}</span>
        </div>
      </div>
    </section>

    <!-- ══════════════════ DESAFIOS ABERTOS ══════════════════ -->
    <section id="desafios" class="mx-auto flex max-w-[1600px] flex-col gap-10 px-6 py-20 lg:px-16 lg:py-24">
      <div class="flex flex-wrap items-end justify-between gap-6">
        <div class="flex max-w-xl flex-col gap-2.5">
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">Desafios abertos</span>
          <h2 class="font-display text-[32px] font-black uppercase tracking-tight text-ink lg:text-[40px]">Tem gente te esperando</h2>
          <p class="text-base text-ink-subtle">Aceita o desafio, se encontrem no jogo e o X1 começa. A grana fica travada na carteira até sair o resultado.</p>
        </div>
        <router-link to="/desafios" class="shrink-0 border-b border-primary/40 pb-0.5 text-sm font-bold text-primary no-underline transition-colors hover:border-primary">Ver todos os desafios →</router-link>
      </div>

      <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <div v-for="c in openChallenges" :key="c.creator" v-reveal class="flex flex-col gap-4 rounded-2xl border border-hairline bg-surface-2 p-6 transition-colors hover:border-primary/40">
          <div class="flex items-center gap-3">
            <span class="grid size-11 place-items-center rounded-full text-sm font-black" :style="{ background: c.bg, color: c.fg }">{{ c.initials }}</span>
            <div class="flex flex-col gap-0.5">
              <span class="text-[15px] font-extrabold text-ink">{{ c.creator }}</span>
              <span class="inline-flex items-center gap-1 text-xs text-ink-tertiary">
                {{ c.wins }}V · {{ c.winRate }}% de vitórias
                <span class="mx-1 text-ink-tertiary/50">·</span>
                <Star :size="12" fill="currentColor" class="text-primary" />{{ c.rating }}
              </span>
            </div>
          </div>
          <div class="flex gap-2">
            <span class="rounded-full bg-surface-3 px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-ink-muted">{{ c.game }}</span>
            <span class="rounded-full bg-surface-3 px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-ink-muted">{{ c.platform }}</span>
          </div>
          <div class="mt-auto flex items-center justify-between pt-1">
            <span class="font-display text-2xl font-black text-primary">R$ {{ c.bet }}</span>
            <router-link to="/desafios" class="rounded-lg bg-primary px-[18px] py-2.5 text-[13px] font-extrabold text-canvas no-underline transition-colors hover:bg-primary-hover">Aceitar X1</router-link>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ COMO FUNCIONA ══════════════════ -->
    <section class="border-y border-hairline bg-surface-1">
      <div class="mx-auto flex max-w-[1600px] flex-col gap-12 px-6 py-20 lg:px-16 lg:py-24">
        <div class="mx-auto flex max-w-2xl flex-col items-center gap-2.5 text-center">
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">Como funciona</span>
          <h2 class="font-display text-[32px] font-black uppercase tracking-tight text-ink lg:text-[40px]">Do cadastro ao saque em 4 passos</h2>
        </div>
        <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div v-for="(s, i) in steps" :key="s.n" v-reveal="`${i * 90}ms`" class="flex flex-col gap-3.5 rounded-2xl border border-hairline bg-surface-2 p-6">
            <span class="font-display text-4xl font-black tracking-tight text-primary">{{ s.n }}</span>
            <span class="text-[17px] font-extrabold text-ink">{{ s.title }}</span>
            <p class="text-sm leading-relaxed text-ink-subtle">{{ s.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ TORNEIOS ══════════════════ -->
    <section id="torneios" class="mx-auto flex max-w-[1600px] flex-col gap-10 px-6 py-20 lg:px-16 lg:py-24">
      <div class="flex flex-col gap-2.5">
        <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">Torneios em destaque</span>
        <h2 class="font-display text-[32px] font-black uppercase tracking-tight text-ink lg:text-[40px]">Mata-mata com premiação de verdade</h2>
      </div>
      <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <div
          v-for="(t, i) in tournamentsPreview"
          :key="t.title"
          v-reveal="`${i * 90}ms`"
          class="flex flex-col gap-[18px] rounded-2xl border p-6"
          :class="i === 0 ? 'border-primary/30 bg-gradient-to-br from-primary/10 to-transparent' : 'border-hairline bg-surface-2'"
        >
          <div class="flex items-center justify-between">
            <span
              class="rounded-full px-2.5 py-1 text-[11px] font-extrabold uppercase tracking-wide"
              :class="i === 0 ? 'bg-primary text-canvas' : 'bg-surface-3 text-ink-muted'"
            >{{ t.date }}</span>
            <span class="text-xs font-semibold text-ink-tertiary">{{ t.game }}</span>
          </div>
          <span class="font-display text-xl font-black tracking-tight text-ink">{{ t.title }}</span>
          <div class="flex flex-col gap-1.5 text-sm">
            <div class="flex justify-between"><span class="text-ink-tertiary">Premiação</span><span class="font-extrabold text-primary">R$ {{ t.prize }}</span></div>
            <div class="flex justify-between"><span class="text-ink-tertiary">Inscrição</span><span class="font-bold text-ink">R$ {{ t.entryFee }}</span></div>
            <div class="flex justify-between"><span class="text-ink-tertiary">Vagas</span><span class="font-bold text-ink">{{ t.maxPlayers }} · restam {{ t.maxPlayers - t.enrolled }}</span></div>
          </div>
          <router-link
            to="/torneios"
            class="mt-auto rounded-lg py-3 text-center text-sm font-extrabold no-underline transition-colors"
            :class="i === 0 ? 'bg-primary text-canvas hover:bg-primary-hover' : 'border border-hairline-strong text-ink hover:border-primary hover:text-primary'"
          >Garantir vaga</router-link>
        </div>
      </div>
    </section>

    <!-- ══════════════════ CLASSIFICAÇÃO ══════════════════ -->
    <section id="classificacao" class="border-y border-hairline bg-surface-1">
      <div class="mx-auto grid max-w-[1600px] items-center gap-12 px-6 py-20 lg:grid-cols-2 lg:px-16 lg:py-24">
        <div class="flex flex-col gap-5">
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">Classificação</span>
          <h2 class="font-display text-[32px] font-black uppercase tracking-tight text-ink lg:text-[40px]">O ranking nacional é o seu palco</h2>
          <p class="text-base leading-relaxed text-ink-subtle">Cada vitória vale posição. Sobe no ranking, ganha destaque e atrai desafios maiores.</p>
          <router-link to="/classificacao" class="w-fit border-b border-primary/40 pb-0.5 text-sm font-bold text-primary no-underline">Ver ranking completo →</router-link>
        </div>
        <div class="overflow-hidden rounded-2xl border border-hairline-strong bg-surface-2">
          <div class="grid grid-cols-[34px_1fr_64px_58px_58px] gap-2 border-b border-hairline px-[18px] py-3.5 text-[11px] font-bold uppercase tracking-widest text-ink-tertiary">
            <span>#</span><span>Jogador</span><span class="text-right">Vitórias</span><span class="text-right">Aprov.</span><span class="text-right">Rating</span>
          </div>
          <div v-for="p in rankingPreview" :key="p.rank" class="grid grid-cols-[34px_1fr_64px_58px_58px] items-center gap-2 border-b border-hairline/60 px-[18px] py-3.5 last:border-b-0">
            <span class="font-display text-[15px] font-black" :class="p.rank <= 3 ? 'text-primary' : 'text-ink-tertiary'">{{ p.rank }}</span>
            <div class="flex items-center gap-2.5">
              <span class="grid size-8 place-items-center rounded-full text-xs font-black" :style="{ background: p.bg, color: p.fg }">{{ p.initials }}</span>
              <span class="text-sm font-bold text-ink">{{ p.nick }}</span>
            </div>
            <span class="text-right text-sm font-semibold text-ink">{{ p.wins }}</span>
            <span class="text-right text-sm text-ink-subtle">{{ p.winRate }}%</span>
            <span class="inline-flex items-center justify-end gap-1 text-right text-sm font-extrabold text-primary">
              <Star :size="12" fill="currentColor" />{{ p.rating }}
            </span>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ TORNEIO DE SOFÁ (GRÁTIS) ══════════════════ -->
    <section class="mx-auto grid max-w-[1600px] items-center gap-14 px-6 py-20 lg:grid-cols-2 lg:px-16 lg:py-24">
      <div class="flex flex-col gap-6">
        <span class="w-fit rounded-full bg-primary/12 px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-primary">Novo · Grátis pra sempre</span>
        <h2 class="font-display text-[32px] font-black uppercase leading-tight tracking-tight text-ink lg:text-[40px]">O Torneio de Sofá</h2>
        <p class="text-base leading-relaxed text-ink-subtle">
          Juntou a galera? Em 30 segundos você monta a chave, joga e bate o chinelo na resenha.
          <span class="text-ink">Só o anfitrião precisa de conta</span> — digite os nomes dos 4, 8 ou 16 e o sistema sorteia tudo na hora. Sem pagar nada.
        </p>

        <div class="flex flex-col gap-5">
          <div v-for="t in tourneyFeatures" :key="t.title" class="flex gap-4">
            <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-primary/12 text-primary">
              <component :is="t.icon" :size="22" />
            </span>
            <div>
              <h3 class="text-lg font-bold text-ink">{{ t.title }}</h3>
              <p class="mt-1 text-sm text-ink-subtle">{{ t.desc }}</p>
            </div>
          </div>
        </div>

        <div class="relative overflow-hidden rounded-2xl border border-primary/25 bg-gradient-to-br from-primary/10 to-transparent p-5">
          <div class="flex items-start gap-3">
            <QrCode class="text-primary" />
            <div>
              <p class="text-sm font-bold text-ink">Quer deixar a resenha mais séria?</p>
              <p class="mt-1 text-sm text-ink-subtle">Transforme o torneio grátis em disputa por dinheiro real — a galera paga a entrada online e o anfitrião ganha <span class="font-bold text-primary">cashback</span> no fechamento do pote.</p>
            </div>
          </div>
        </div>

        <div class="flex flex-col gap-3 sm:flex-row">
          <router-link to="/register" class="group inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-7 py-3.5 text-base font-extrabold text-canvas no-underline shadow-glow-primary transition-colors hover:bg-primary-hover">
            Criar Torneio Rápido
            <ArrowRight :size="20" class="transition-transform duration-200 group-hover:translate-x-0.5" />
          </router-link>
          <router-link to="/como-funciona" class="inline-flex items-center justify-center gap-2 rounded-xl border border-hairline-strong px-7 py-3.5 text-base font-bold text-ink no-underline transition-colors hover:bg-surface-2">Ver exemplo de chave</router-link>
        </div>
      </div>

      <!-- Bracket + Card do Campeão -->
      <div class="flex flex-col gap-6">
        <div class="glass-strong rounded-2xl border border-hairline-strong p-5 shadow-card-premium sm:p-6">
          <div class="mb-5 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Network :size="18" class="text-primary" />
              <span class="text-sm font-bold text-ink">Resenha de Sábado</span>
            </div>
            <span class="rounded-full bg-surface-3 px-2.5 py-1 text-xs text-ink-subtle">Mata-mata · 4</span>
          </div>
          <div class="flex items-center gap-2 sm:gap-3">
            <div class="flex-1 space-y-3">
              <div class="overflow-hidden rounded-lg border border-hairline">
                <div class="flex items-center justify-between bg-primary/12 px-2.5 py-1.5 text-sm font-bold text-ink"><span>João</span><span class="tabular-nums text-primary">3</span></div>
                <div class="flex items-center justify-between px-2.5 py-1.5 text-sm text-ink-subtle"><span>Bruno</span><span class="tabular-nums">1</span></div>
              </div>
              <div class="overflow-hidden rounded-lg border border-hairline">
                <div class="flex items-center justify-between px-2.5 py-1.5 text-sm text-ink-subtle"><span>Léo</span><span class="tabular-nums">2</span></div>
                <div class="flex items-center justify-between bg-primary/12 px-2.5 py-1.5 text-sm font-bold text-ink"><span>Caio</span><span class="tabular-nums text-primary">4</span></div>
              </div>
            </div>
            <div class="flex w-4 shrink-0 items-center sm:w-6">
              <div class="h-px w-full bg-gradient-to-r from-hairline-strong to-primary/60"></div>
            </div>
            <div class="flex-1">
              <p class="mb-1.5 text-center text-[10px] font-bold uppercase tracking-widest text-ink-tertiary">Final</p>
              <div class="rounded-lg border border-primary/30 bg-surface-3/60 p-0.5 shadow-glow-primary">
                <div class="flex items-center justify-between rounded bg-primary/20 px-2.5 py-2 text-sm font-bold text-ink"><span>João</span><span class="tabular-nums text-primary">2</span></div>
                <div class="flex items-center justify-between px-2.5 py-2 text-sm font-bold text-ink"><span>Caio</span><span class="tabular-nums">1</span></div>
              </div>
            </div>
          </div>
          <div class="mt-5 flex items-center justify-between border-t border-hairline pt-4 text-sm">
            <span class="flex items-center gap-1.5 text-ink-subtle"><Goal :size="18" class="text-primary" />Melhor ataque</span>
            <span class="font-semibold text-ink">João · 14 gols</span>
          </div>
        </div>

        <div class="flex justify-end">
          <div class="w-48 rounded-2xl bg-gradient-to-b from-amber-300/70 via-primary/40 to-transparent p-px shadow-glow-primary sm:rotate-3">
            <div class="rounded-2xl bg-surface-2/95 p-4 backdrop-blur">
              <div class="flex items-start justify-between text-amber-300">
                <div class="leading-none">
                  <p class="font-display text-3xl font-bold">94</p>
                  <p class="text-[10px] font-semibold tracking-widest">OVR</p>
                </div>
                <Crown fill="currentColor" :size="18" />
              </div>
              <div class="my-3 grid h-16 place-items-center">
                <span class="grid size-14 place-items-center rounded-full bg-gradient-to-b from-amber-300/30 to-transparent font-display text-xl font-bold text-ink ring-1 ring-amber-300/40">JO</span>
              </div>
              <p class="text-center font-display text-sm font-bold tracking-wide text-ink">JOÃO "O REI"</p>
              <p class="mb-3 text-center text-[10px] uppercase tracking-widest text-amber-300/80">Campeão da rodada</p>
              <div class="grid grid-cols-3 gap-x-2 gap-y-1.5 text-center">
                <div v-for="cs in championStats" :key="cs.k">
                  <p class="font-display text-sm font-bold tabular-nums text-ink">{{ cs.v }}</p>
                  <p class="text-[9px] uppercase tracking-wider text-ink-tertiary">{{ cs.k }}</p>
                </div>
              </div>
              <div class="mt-3 flex items-center justify-center gap-1 text-[10px] font-semibold text-primary">
                <Share2 :size="14" />Compartilhar nos Stories
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ SEGURANÇA ══════════════════ -->
    <section class="border-y border-hairline bg-surface-1">
      <div class="mx-auto flex max-w-[1600px] flex-col gap-11 px-6 py-20 lg:px-16 lg:py-24">
        <div class="mx-auto flex max-w-2xl flex-col items-center gap-2.5 text-center">
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">Jogo limpo, grana segura</span>
          <h2 class="font-display text-[32px] font-black uppercase tracking-tight text-ink lg:text-[40px]">Sua carteira é intocável</h2>
        </div>
        <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div v-for="f in features" :key="f.title" class="flex flex-col gap-3 rounded-2xl border border-hairline bg-surface-2 p-6">
            <span class="grid size-11 place-items-center rounded-xl bg-primary/12 text-primary"><component :is="f.icon" :size="22" /></span>
            <span class="text-base font-extrabold text-ink">{{ f.title }}</span>
            <p class="text-sm leading-relaxed text-ink-subtle">{{ f.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ FERRAMENTAS GRÁTIS ══════════════════ -->
    <section class="mx-auto max-w-[1600px] px-6 py-20 lg:px-16">
      <div class="flex flex-col gap-8 lg:flex-row lg:items-center lg:justify-between">
        <div class="max-w-md">
          <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">Ferramentas grátis</span>
          <h2 class="mt-2.5 font-display text-2xl font-black uppercase tracking-tight text-ink">Resolva a treta antes de começar</h2>
          <p class="mt-3 text-sm text-ink-subtle">Utilitários rápidos pra qualquer rolê, sem cadastro. Quando quiser valer dinheiro de verdade, é só criar a conta.</p>
        </div>
        <div class="grid flex-1 gap-4 sm:grid-cols-3">
          <div v-for="tool in tools" :key="tool.title" class="group cursor-pointer rounded-2xl border border-hairline bg-surface-2 p-5 transition-all hover:-translate-y-1 hover:border-primary/30">
            <component :is="tool.icon" :size="26" class="mb-3 text-primary" />
            <h3 class="text-sm font-bold text-ink">{{ tool.title }}</h3>
            <p class="mt-1 text-xs text-ink-tertiary">{{ tool.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════ FAQ ══════════════════ -->
    <section class="mx-auto flex max-w-4xl flex-col gap-9 px-6 py-20 lg:py-24">
      <div class="flex flex-col items-center gap-2.5 text-center">
        <span class="text-xs font-bold uppercase tracking-[0.14em] text-primary">FAQ</span>
        <h2 class="font-display text-[32px] font-black uppercase tracking-tight text-ink lg:text-[40px]">Perguntas frequentes</h2>
      </div>
      <div class="flex flex-col gap-3">
        <details v-for="f in faqs" :key="f.q" class="group rounded-xl border border-hairline bg-surface-2 px-6 py-5">
          <summary class="flex cursor-pointer list-none items-center justify-between gap-4 text-base font-bold text-ink marker:content-none">
            {{ f.q }}
            <span class="text-lg font-black text-primary transition-transform group-open:rotate-45">+</span>
          </summary>
          <p class="mt-3.5 text-sm leading-relaxed text-ink-subtle">{{ f.a }}</p>
        </details>
      </div>
    </section>

    <!-- ══════════════════ CTA FINAL ══════════════════ -->
    <section class="mx-auto max-w-[1600px] px-6 pb-24 lg:px-16">
      <div class="flex flex-col items-center gap-5 rounded-[20px] border border-primary/30 bg-gradient-to-br from-primary/12 to-transparent p-12 text-center sm:p-16">
        <h2 class="max-w-2xl font-display text-3xl font-black uppercase leading-tight tracking-tight text-ink sm:text-[42px]">Chega de vencer <span class="text-primary">só no papo</span></h2>
        <p class="max-w-md text-base text-ink-subtle">Cria a conta grátis, deposita a partir de R$ 5 e joga o primeiro X1 hoje.</p>
        <router-link to="/register" class="rounded-xl bg-primary px-9 py-[18px] text-base font-extrabold text-canvas no-underline shadow-glow-primary transition-colors hover:bg-primary-hover">Criar conta grátis</router-link>
        <span class="text-xs text-ink-tertiary">Proibido para menores de 18 anos. Jogue com responsabilidade.</span>
      </div>
    </section>
  </div>
</template>
