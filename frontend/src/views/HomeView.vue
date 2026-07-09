<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  Wallet, ArrowDownToLine, ArrowUpFromLine, Swords, Trophy, Target,
  Star, Plus, History, Receipt, ArrowRight, CalendarDays, Gamepad2,
  ShieldAlert, Activity, ChevronRight,
} from '@lucide/vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useWalletStore } from '@/stores/wallet'
import { api } from '@/services/api'
import { vReveal } from '@/composables/useReveal'

const authStore = useAuthStore()
const walletStore = useWalletStore()
const MY_ID = authStore.user?.id || null

/* ── Tipos alinhados ao contrato real do backend (ver challenges.py) ── */
type ChallengeStatus = 'open' | 'in_progress' | 'completed' | 'disputed'
interface ChallengeProfile { username: string; fair_play_rating: number }
interface Challenge {
  id: string
  creator_id: string
  opponent_id: string | null
  bet_amount: number
  platform: string
  game: string
  status: ChallengeStatus
  winner_id: string | null
  created_at: string
  creator_profile: ChallengeProfile
  opponent_profile: ChallengeProfile | null
}

const profile = ref<any>(null)
const challenges = ref<Challenge[]>([])
const transactions = ref<any[]>([])
const loading = ref(true)
// Desafios vêm do backend (Render) — pode ser bem mais lento que o Supabase
// direto (perfil/carteira/extrato) se o serviço estiver "dormindo" (plano
// free hiberna após inatividade). Por isso tem loading próprio: o resto do
// painel aparece assim que estiver pronto, sem esperar o backend acordar.
const challengesLoading = ref(true)

const loadUserData = async () => {
  if (!authStore.user) return
  loading.value = true
  challengesLoading.value = true

  // Desafios reais — disparado em paralelo com o resto, não depende de nada
  // aqui. Resiliente: se o backend estiver fora, mostra estado vazio.
  const challengesPromise = api.get<Challenge[]>('/api/challenges/my-challenges')
    .catch(() => [] as Challenge[])
    .then(data => {
      challenges.value = data
      challengesLoading.value = false
    })

  try {
    const [{ data: profileData }] = await Promise.all([
      supabase.from('profiles').select('*').eq('id', authStore.user.id).single(),
      walletStore.fetchWallet(),
    ])
    profile.value = profileData

    // Extrato: depende de já termos a carteira
    if (walletStore.id) {
      const { data: txData } = await supabase
        .from('transactions')
        .select('*')
        .eq('wallet_id', walletStore.id)
        .order('created_at', { ascending: false })
        .limit(6)
      transactions.value = txData || []
    }
  } catch (err) {
    console.error('Erro ao carregar dados do usuário:', err)
  } finally {
    loading.value = false
  }

  await challengesPromise
}

onMounted(loadUserData)

/* ── Saudação + data ── */
const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Bom dia'
  if (h < 18) return 'Boa tarde'
  return 'Boa noite'
})
const todayLabel = computed(() => {
  const d = new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })
  return d.charAt(0).toUpperCase() + d.slice(1)
})

const displayName = computed(() => profile.value?.username || authStore.user?.user_metadata?.username || 'Jogador')
const initials = computed(() => displayName.value.substring(0, 2).toUpperCase())
const mainPlatform = computed(() => profile.value?.psn_id ? 'PS5' : profile.value?.xbox_id ? 'Xbox' : 'PC')

/* ── Estatísticas derivadas dos desafios reais (profiles não tem colunas
   wins/losses — nunca teve; isso ficava sempre zerado). 'disputed' não
   conta: partida sem vencedor definido ainda. ── */
const totalMatches = computed(() => challenges.value.filter(c => c.status === 'completed').length)
const wins = computed(() => challenges.value.filter(c => c.status === 'completed' && c.winner_id === MY_ID).length)
const losses = computed(() => totalMatches.value - wins.value)
const winRate = computed(() => totalMatches.value ? Math.round((wins.value / totalMatches.value) * 100) : 0)
const netWins = computed(() => wins.value - losses.value)
const rating = computed(() => profile.value?.fair_play_rating ?? 5.0)
const ratingLabel = computed(() => {
  const r = rating.value
  if (r >= 4.5) return 'Reputação exemplar'
  if (r >= 3.5) return 'Boa reputação'
  if (r >= 2.5) return 'Reputação regular'
  return 'Reputação em risco'
})
const ratingColor = computed(() => {
  const r = rating.value
  if (r >= 4.5) return 'text-accent'
  if (r >= 3.5) return 'text-emerald-400'
  if (r >= 2.5) return 'text-amber-400'
  return 'text-red-400'
})
const ratingIconClass = computed(() => {
  const r = rating.value
  if (r >= 4.5) return 'bg-accent/10 text-accent'
  if (r >= 3.5) return 'bg-emerald-400/10 text-emerald-400'
  if (r >= 2.5) return 'bg-amber-400/10 text-amber-400'
  return 'bg-red-400/10 text-red-400'
})

/* ── Carteira ── */
const balance = computed(() => walletStore.balance)
const locked = computed(() => walletStore.lockedBalance)
const totalFunds = computed(() => balance.value + locked.value)
const availablePct = computed(() => totalFunds.value > 0 ? (balance.value / totalFunds.value) * 100 : 100)
const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

/* ── Desafios ── */
const activeChallenges = computed(() =>
  challenges.value
    .filter(c => c.status === 'open' || c.status === 'in_progress')
    .sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at))
)
const historyChallenges = computed(() =>
  challenges.value
    .filter(c => c.status === 'completed' || c.status === 'disputed')
    .sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at))
    .slice(0, 4)
)
const recentTx = computed(() => transactions.value.slice(0, 5))

function timeAgo(iso: string): string {
  const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60_000)
  if (mins < 1) return 'Agora mesmo'
  if (mins < 60) return `Há ${mins} min`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return hours === 1 ? 'Há 1 hora' : `Há ${hours} horas`
  const days = Math.floor(hours / 24)
  return days === 1 ? 'Ontem' : `Há ${days} dias`
}

// Rake do desafio 1v1 = 8% (ver backend/18_rake_minimums_and_wording.sql)
const totalPrize = (c: Challenge) => c.bet_amount * 1.84

/* Adversário exibido do ponto de vista do usuário logado */
const opponentName = (c: Challenge) => {
  if (c.creator_id === MY_ID) return c.opponent_profile?.username || 'Aguardando adversário'
  return c.creator_profile.username
}

const statusMeta: Record<ChallengeStatus, { label: string; dot: string; text: string }> = {
  open: { label: 'Aberto', dot: 'bg-semantic-success', text: 'text-semantic-success' },
  in_progress: { label: 'Ao vivo', dot: 'bg-accent', text: 'text-accent' },
  completed: { label: 'Concluído', dot: 'bg-ink-tertiary', text: 'text-ink-tertiary' },
  disputed: { label: 'Em disputa', dot: 'bg-semantic-error', text: 'text-semantic-error' },
}

/* Resultado de um desafio concluído para o usuário logado */
const challengeResult = (c: Challenge) => {
  if (c.status === 'disputed') return { label: 'Em disputa', amount: 0, tone: 'text-semantic-error' as const }
  const won = c.winner_id === MY_ID
  return won
    ? { label: 'Vitória', amount: c.bet_amount * 0.84, tone: 'text-semantic-success' as const }
    : { label: 'Derrota', amount: -c.bet_amount, tone: 'text-ink-subtle' as const }
}

/* Transações: rótulo + sinal (cobre nomes antigos e novos do backend) */
const txMeta = (type: string): { label: string; positive: boolean } => {
  switch (type) {
    case 'deposit': return { label: 'Depósito', positive: true }
    case 'challenge_win': case 'win_prize': return { label: 'Prêmio', positive: true }
    case 'withdraw': return { label: 'Saque', positive: false }
    case 'challenge_loss': return { label: 'Derrota', positive: false }
    case 'bet_freeze': return { label: 'Valor retido', positive: false }
    case 'rake': return { label: 'Comissão', positive: false }
    default: return { label: type, positive: false }
  }
}
</script>

<template>
  <div class="mx-auto w-full max-w-7xl space-y-8 p-6 lg:p-10">

    <!-- ════ Skeleton de carregamento ════ -->
    <div v-if="loading" class="animate-pulse space-y-8">
      <div class="h-16 w-64 rounded-xl bg-surface-2"></div>
      <div class="grid gap-5 lg:grid-cols-3">
        <div class="h-48 rounded-2xl bg-surface-2 lg:col-span-2"></div>
        <div class="h-48 rounded-2xl bg-surface-2"></div>
      </div>
      <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <div v-for="i in 4" :key="i" class="h-28 rounded-2xl bg-surface-2"></div>
      </div>
      <div class="h-56 rounded-2xl bg-surface-2"></div>
    </div>

    <!-- ════ Conteúdo ════ -->
    <template v-else>

      <!-- Saudação -->
      <header class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <div class="grid size-12 shrink-0 place-items-center rounded-2xl border border-primary/30 bg-primary/10 font-display text-lg font-bold uppercase text-primary">
            {{ initials }}
          </div>
          <div>
            <h1 class="font-display text-2xl font-bold text-ink sm:text-3xl">{{ greeting }}, {{ displayName }}</h1>
            <p class="mt-0.5 flex items-center gap-1.5 text-body-sm text-ink-subtle">
              <CalendarDays :size="14" /> {{ todayLabel }}
            </p>
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle">
            <Gamepad2 :size="14" class="text-accent" /> {{ mainPlatform }}
          </span>
          <span class="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle">
            EA ID: <span class="text-ink">{{ profile?.ea_id || '—' }}</span>
          </span>
        </div>
      </header>

      <!-- Carteira + Reputação -->
      <section class="grid gap-5 lg:grid-cols-3">
        <!-- Carteira (destaque financeiro) -->
        <div
          v-reveal
          class="relative overflow-hidden rounded-2xl border border-hairline bg-surface-1 p-6 lg:col-span-2 lg:p-7"
        >
          <div class="pointer-events-none absolute -right-16 -top-16 size-56 rounded-full bg-primary/10 blur-3xl"></div>

          <div class="relative flex items-start justify-between">
            <div>
              <p class="flex items-center gap-2 text-caption font-semibold uppercase tracking-widest text-ink-tertiary">
                <Wallet :size="14" /> Saldo disponível
              </p>
              <p class="mt-2 font-display text-4xl font-bold tabular-nums text-ink lg:text-5xl">{{ fmtBRL(balance) }}</p>
            </div>
            <span
              v-if="locked > 0"
              class="hidden shrink-0 items-center gap-1.5 rounded-full border border-amber-500/20 bg-amber-500/10 px-3 py-1.5 text-caption font-semibold text-amber-400 sm:inline-flex"
            >
              {{ fmtBRL(locked) }} em jogo
            </span>
          </div>

          <!-- Barra disponível / em jogo -->
          <div class="relative mt-6">
            <div class="flex h-2 w-full overflow-hidden rounded-full bg-surface-3">
              <div class="bg-semantic-success transition-[width] duration-500" :style="{ width: availablePct + '%' }"></div>
              <div class="bg-amber-500 transition-[width] duration-500" :style="{ width: (100 - availablePct) + '%' }"></div>
            </div>
            <div class="mt-2.5 flex items-center gap-4 text-caption text-ink-subtle">
              <span class="inline-flex items-center gap-1.5">
                <span class="size-2 rounded-full bg-semantic-success"></span> Disponível
              </span>
              <span v-if="locked > 0" class="inline-flex items-center gap-1.5">
                <span class="size-2 rounded-full bg-amber-500"></span> Em jogo
              </span>
              <span class="ml-auto tabular-nums">Total: {{ fmtBRL(totalFunds) }}</span>
            </div>
          </div>

          <!-- Ações -->
          <div class="relative mt-6 flex flex-col gap-3 sm:flex-row">
            <router-link
              to="/wallet"
              class="inline-flex flex-1 items-center justify-center gap-2 rounded-xl bg-primary py-3 text-button font-semibold text-canvas no-underline shadow-glow-primary transition-all hover:bg-primary-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
            >
              <ArrowDownToLine :size="18" /> Depositar
            </router-link>
            <router-link
              to="/wallet?tab=withdraw"
              class="inline-flex flex-1 items-center justify-center gap-2 rounded-xl border border-hairline-strong bg-surface-2 py-3 text-button font-semibold text-ink no-underline transition-colors hover:bg-surface-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
            >
              <ArrowUpFromLine :size="18" /> Sacar
            </router-link>
          </div>
        </div>

        <!-- Reputação -->
        <div v-reveal="'80ms'" class="flex flex-col justify-between rounded-2xl border border-hairline bg-surface-1 p-6">
          <div class="flex items-start justify-between">
            <p class="text-caption font-semibold uppercase tracking-widest text-ink-tertiary">Reputação</p>
            <span class="grid size-9 place-items-center rounded-lg transition-colors" :class="ratingIconClass">
              <Star :size="18" fill="currentColor" />
            </span>
          </div>
          <div class="mt-4">
            <p class="font-display text-4xl font-bold tabular-nums text-ink">
              {{ rating.toFixed(1) }}<span class="text-xl text-ink-tertiary">/5.0</span>
            </p>
            <p class="mt-1 text-body-sm font-medium transition-colors" :class="ratingColor">{{ ratingLabel }}</p>
          </div>
          <div class="mt-5 flex items-center justify-between border-t border-hairline pt-4">
            <span class="text-caption text-ink-subtle">Saldo de partidas</span>
            <span class="font-bold tabular-nums" :class="netWins > 0 ? 'text-semantic-success' : netWins < 0 ? 'text-semantic-error' : 'text-ink-subtle'">
              {{ netWins > 0 ? '+' : '' }}{{ netWins }}
            </span>
          </div>
        </div>
      </section>

      <!-- KPIs -->
      <section class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <div v-reveal class="rounded-2xl border border-hairline bg-surface-1 p-5">
          <span class="grid size-9 place-items-center rounded-lg bg-primary/10 text-primary"><Activity :size="18" /></span>
          <p class="mt-3 font-display text-2xl font-bold tabular-nums text-ink">{{ totalMatches }}</p>
          <p class="text-caption text-ink-tertiary">Partidas jogadas</p>
        </div>
        <div v-reveal="'60ms'" class="rounded-2xl border border-hairline bg-surface-1 p-5">
          <span class="grid size-9 place-items-center rounded-lg bg-semantic-success/10 text-semantic-success"><Trophy :size="18" /></span>
          <p class="mt-3 font-display text-2xl font-bold tabular-nums text-semantic-success">{{ wins }}</p>
          <p class="text-caption text-ink-tertiary">Vitórias</p>
        </div>
        <div v-reveal="'120ms'" class="rounded-2xl border border-hairline bg-surface-1 p-5">
          <span class="grid size-9 place-items-center rounded-lg bg-semantic-error/10 text-semantic-error"><Swords :size="18" /></span>
          <p class="mt-3 font-display text-2xl font-bold tabular-nums text-ink">{{ losses }}</p>
          <p class="text-caption text-ink-tertiary">Derrotas</p>
        </div>
        <div v-reveal="'180ms'" class="rounded-2xl border border-hairline bg-surface-1 p-5">
          <span class="grid size-9 place-items-center rounded-lg bg-accent/10 text-accent"><Target :size="18" /></span>
          <p class="mt-3 font-display text-2xl font-bold tabular-nums text-ink">{{ winRate }}%</p>
          <p class="text-caption text-ink-tertiary">Taxa de vitória</p>
          <div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-surface-3">
            <div class="h-full rounded-full bg-accent transition-[width] duration-500" :style="{ width: winRate + '%' }"></div>
          </div>
        </div>
      </section>

      <!-- Desafios ativos -->
      <section class="space-y-4">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-xl font-bold text-ink">Desafios ativos</h2>
            <p class="mt-0.5 text-body-sm text-ink-subtle">Suas partidas em aberto e ao vivo.</p>
          </div>
          <router-link
            to="/create-challenge"
            class="inline-flex items-center gap-2 rounded-lg border border-hairline bg-surface-2 px-4 py-2 text-body-sm font-semibold text-ink no-underline transition-colors hover:bg-surface-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
          >
            <Plus :size="16" /> Novo desafio
          </router-link>
        </div>

        <div v-if="challengesLoading" class="grid animate-pulse grid-cols-1 gap-4 lg:grid-cols-2">
          <div v-for="i in 2" :key="i" class="h-[76px] rounded-2xl bg-surface-2"></div>
        </div>

        <div v-else-if="activeChallenges.length" class="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <router-link
            v-for="c in activeChallenges"
            :key="c.id"
            :to="c.status === 'in_progress' ? `/match/${c.id}` : '/challenges'"
            class="group flex items-center gap-4 rounded-2xl border border-hairline bg-surface-1 p-4 no-underline transition-all hover:border-hairline-strong hover:bg-surface-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
          >
            <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-surface-2 text-ink-subtle">
              <Gamepad2 :size="20" />
            </span>
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <p class="truncate font-semibold text-ink">{{ c.game }}</p>
                <span class="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider" :class="statusMeta[c.status].text">
                  <span class="size-1.5 rounded-full" :class="statusMeta[c.status].dot"></span>{{ statusMeta[c.status].label }}
                </span>
              </div>
              <p class="mt-0.5 truncate text-caption text-ink-tertiary">{{ c.platform }} · vs {{ opponentName(c) }}</p>
            </div>
            <div class="shrink-0 text-right">
              <p class="text-caption text-ink-tertiary">Prêmio</p>
              <p class="font-bold tabular-nums text-semantic-success">{{ fmtBRL(totalPrize(c)) }}</p>
            </div>
            <ChevronRight :size="18" class="shrink-0 text-ink-tertiary transition-transform group-hover:translate-x-0.5" />
          </router-link>
        </div>

        <!-- Vazio -->
        <div v-else class="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-hairline-strong bg-surface-1 py-14 text-center">
          <span class="grid size-14 place-items-center rounded-2xl bg-surface-2 text-ink-tertiary"><Swords :size="26" /></span>
          <p class="font-semibold text-ink">Nenhum desafio ativo</p>
          <p class="max-w-xs text-body-sm text-ink-subtle">Tá esperando o quê? Abre um desafio e mostra em campo quem manda.</p>
          <router-link
            to="/create-challenge"
            class="mt-1 inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-body-sm font-semibold text-canvas no-underline shadow-glow-primary transition-all hover:bg-primary-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
          >
            <Plus :size="16" /> Criar desafio
          </router-link>
        </div>
      </section>

      <!-- Histórico + Transações -->
      <section class="grid gap-6 lg:grid-cols-2">
        <!-- Histórico de desafios -->
        <div class="flex flex-col rounded-2xl border border-hairline bg-surface-1">
          <div class="flex items-center justify-between border-b border-hairline px-5 py-4">
            <h3 class="flex items-center gap-2 font-bold text-ink"><History :size="18" class="text-ink-subtle" /> Histórico</h3>
            <router-link to="/challenges" class="inline-flex items-center gap-1 text-caption font-semibold text-primary no-underline hover:underline">
              Ver tudo <ArrowRight :size="13" />
            </router-link>
          </div>
          <div v-if="challengesLoading" class="animate-pulse space-y-3.5 p-5">
            <div v-for="i in 3" :key="i" class="h-9 rounded-lg bg-surface-2"></div>
          </div>
          <div v-else-if="historyChallenges.length" class="divide-y divide-hairline">
            <div v-for="c in historyChallenges" :key="c.id" class="flex items-center justify-between gap-3 px-5 py-3.5">
              <div class="min-w-0">
                <p class="truncate text-body-sm font-medium text-ink">{{ c.game }} · vs {{ opponentName(c) }}</p>
                <p class="text-caption text-ink-tertiary">{{ timeAgo(c.created_at) }}</p>
              </div>
              <div class="shrink-0 text-right">
                <p class="text-body-sm font-bold tabular-nums" :class="challengeResult(c).tone">
                  <template v-if="c.status === 'disputed'">
                    <ShieldAlert :size="14" class="mr-0.5 inline" />Em disputa
                  </template>
                  <template v-else>
                    {{ challengeResult(c).amount > 0 ? '+' : '' }}{{ fmtBRL(challengeResult(c).amount) }}
                  </template>
                </p>
                <p class="text-caption" :class="challengeResult(c).tone">{{ challengeResult(c).label }}</p>
              </div>
            </div>
          </div>
          <div v-else class="flex flex-1 flex-col items-center justify-center gap-2 py-12 text-center">
            <History :size="30" class="text-ink-tertiary" />
            <p class="text-body-sm text-ink-subtle">Você ainda não concluiu desafios.</p>
          </div>
        </div>

        <!-- Transações recentes -->
        <div class="flex flex-col rounded-2xl border border-hairline bg-surface-1">
          <div class="flex items-center justify-between border-b border-hairline px-5 py-4">
            <h3 class="flex items-center gap-2 font-bold text-ink"><Receipt :size="18" class="text-ink-subtle" /> Transações</h3>
            <router-link to="/wallet" class="inline-flex items-center gap-1 text-caption font-semibold text-primary no-underline hover:underline">
              Ver tudo <ArrowRight :size="13" />
            </router-link>
          </div>
          <div v-if="recentTx.length" class="divide-y divide-hairline">
            <div v-for="tx in recentTx" :key="tx.id" class="flex items-center justify-between gap-3 px-5 py-3.5">
              <div class="min-w-0">
                <p class="truncate text-body-sm font-medium text-ink">{{ txMeta(tx.type).label }}</p>
                <p class="text-caption text-ink-tertiary">{{ new Date(tx.created_at).toLocaleDateString('pt-BR') }}</p>
              </div>
              <span class="shrink-0 text-body-sm font-bold tabular-nums" :class="txMeta(tx.type).positive ? 'text-semantic-success' : 'text-ink-subtle'">
                {{ txMeta(tx.type).positive ? '+' : '−' }}{{ fmtBRL(Math.abs(Number(tx.amount))) }}
              </span>
            </div>
          </div>
          <div v-else class="flex flex-1 flex-col items-center justify-center gap-2 py-12 text-center">
            <Receipt :size="30" class="text-ink-tertiary" />
            <p class="text-body-sm text-ink-subtle">Sem transações por enquanto.</p>
            <router-link to="/wallet" class="text-body-sm font-semibold text-primary no-underline hover:underline">Fazer um depósito</router-link>
          </div>
        </div>
      </section>

    </template>
  </div>
</template>
