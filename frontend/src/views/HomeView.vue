<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  Star, Plus, History, Receipt, ArrowRight, CalendarDays, Gamepad2,
  ShieldAlert, ChevronRight, Clock, BellRing, Flag, UserPlus,
} from '@lucide/vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useWalletStore } from '@/stores/wallet'
import { api } from '@/services/api'
import { txMeta } from '@/utils/transactions'
import { vReveal } from '@/composables/useReveal'

const authStore = useAuthStore()
const walletStore = useWalletStore()
const MY_ID = authStore.user?.id || null

/* ── Tipos alinhados ao contrato real do backend (ver challenges.py) ── */
type ChallengeStatus = 'open' | 'accepted' | 'in_progress' | 'completed' | 'disputed'
interface ChallengeProfile { username: string; fair_play_rating: number }
interface JoinRequest { id: string; requester_id: string; status: string; created_at: string }
interface Challenge {
  id: string
  creator_id: string
  opponent_id: string | null
  bet_amount: number
  platform: string
  game: string
  status: ChallengeStatus
  creator_result: string | null
  opponent_result: string | null
  winner_id: string | null
  settlement_release_at: string | null
  created_at: string
  creator_profile: ChallengeProfile
  opponent_profile: ChallengeProfile | null
  join_requests?: JoinRequest[]
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

/* ═══════════════════════════════════════════════════════════════════════
   MOCK TEMPORÁRIO (só visual) — simula um usuário que já usa o app há um
   tempo: ações pendentes, desafios ativos, histórico, estatísticas e extrato.
   NÃO fala com o backend. Para desligar: troque USE_MOCK para false (ou
   remova este bloco + a ramificação no início de loadUserData).
   ═══════════════════════════════════════════════════════════════════════ */
const USE_MOCK = false
const mockIso = (minsAgo: number) => new Date(Date.now() - minsAgo * 60_000).toISOString()

function buildMockChallenges(): Challenge[] {
  const me = MY_ID || 'mock-me'
  const prof = (username: string, r = 4.5): ChallengeProfile => ({ username, fair_play_rating: r })
  const list: Challenge[] = [
    // Precisa de você → reportar resultado (sou criador, in_progress, meu result nulo)
    { id: 'mk-1', creator_id: me, opponent_id: 'u-rafa', bet_amount: 20, platform: 'PlayStation', game: 'EA FC 25',
      status: 'in_progress', creator_result: null, opponent_result: 'loss', winner_id: null, settlement_release_at: null,
      created_at: mockIso(40), creator_profile: prof('Você', 4.7), opponent_profile: prof('Rafa_10', 4.2), join_requests: [] },
    // Precisa de você → 2 solicitações de entrada (sou criador, open)
    { id: 'mk-2', creator_id: me, opponent_id: null, bet_amount: 10, platform: 'PC', game: 'EA FC 25',
      status: 'open', creator_result: null, opponent_result: null, winner_id: null, settlement_release_at: null,
      created_at: mockIso(18), creator_profile: prof('Você', 4.7), opponent_profile: null,
      join_requests: [ { id: 'jr-1', requester_id: 'u-bia', status: 'pending', created_at: mockIso(12) },
                       { id: 'jr-2', requester_id: 'u-leo', status: 'pending', created_at: mockIso(6) } ] },
    // Desafio ativo → confirmar presença (sou oponente, accepted)
    { id: 'mk-3', creator_id: 'u-gustavo', opponent_id: me, bet_amount: 50, platform: 'PlayStation', game: 'EA FC 25',
      status: 'accepted', creator_result: null, opponent_result: null, winner_id: null, settlement_release_at: null,
      created_at: mockIso(55), creator_profile: prof('Gustavo_PS', 4.9), opponent_profile: prof('Você', 4.7), join_requests: [] },
  ]
  // Concluídos → alimentam estatísticas + histórico
  const done: Array<[string, number, 'win' | 'loss']> = [
    ['Rafa_10', 20, 'win'], ['MK_Silva', 15, 'win'], ['Duda99', 30, 'loss'], ['Leo_ZR', 10, 'win'],
    ['Bia_star', 25, 'win'], ['ZéDaGol', 40, 'loss'], ['TioRicardo', 10, 'win'], ['PH_Santos', 20, 'win'],
  ]
  done.forEach(([name, bet, res], i) => {
    const iWon = res === 'win'
    list.push({
      id: `mk-done-${i}`, creator_id: me, opponent_id: `u-${i}`, bet_amount: bet, platform: i % 2 ? 'PC' : 'PlayStation',
      game: 'EA FC 25', status: 'completed', creator_result: res, opponent_result: iWon ? 'loss' : 'win',
      winner_id: iWon ? me : `u-${i}`, settlement_release_at: null,
      created_at: mockIso(120 + i * 90), creator_profile: prof('Você', 4.7), opponent_profile: prof(name), join_requests: [] })
  })
  // Prêmio retido (chip "libera em Xd") e uma disputa em aberto
  list.push({ id: 'mk-held', creator_id: me, opponent_id: 'u-held', bet_amount: 30, platform: 'PC', game: 'EA FC 25',
    status: 'completed', creator_result: 'win', opponent_result: 'loss', winner_id: me,
    settlement_release_at: new Date(Date.now() + 2 * 86_400_000).toISOString(),
    created_at: mockIso(60), creator_profile: prof('Você', 4.7), opponent_profile: prof('NovatoX'), join_requests: [] })
  list.push({ id: 'mk-disp', creator_id: 'u-disp', opponent_id: me, bet_amount: 15, platform: 'PlayStation', game: 'EA FC 25',
    status: 'disputed', creator_result: 'win', opponent_result: 'win', winner_id: null, settlement_release_at: null,
    created_at: mockIso(200), creator_profile: prof('Contestador'), opponent_profile: prof('Você', 4.7), join_requests: [] })
  return list
}

function buildMockTransactions(): any[] {
  return [
    { id: 'tx-1', type: 'challenge_win', amount: 18.40, created_at: mockIso(38) },
    { id: 'tx-2', type: 'bet_freeze', amount: 20, created_at: mockIso(42) },
    { id: 'tx-3', type: 'deposit', amount: 50, created_at: mockIso(180) },
    { id: 'tx-4', type: 'bet_refund', amount: 10, created_at: mockIso(320) },
    { id: 'tx-5', type: 'withdraw', amount: 30, created_at: mockIso(1500) },
  ]
}

const loadUserData = async () => {
  if (USE_MOCK) {
    profile.value = { username: 'Alano', fair_play_rating: 4.7, main_platform: 'PC', ea_id: 'Alvaroalano' }
    challenges.value = buildMockChallenges()
    transactions.value = buildMockTransactions()
    loading.value = false
    challengesLoading.value = false
    return
  }
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
const mainPlatform = computed(() => profile.value?.main_platform || 'Não definida')

/* ── Estatísticas derivadas dos desafios reais (profiles não tem colunas
   wins/losses — nunca teve; isso ficava sempre zerado). 'disputed' não
   conta: partida sem vencedor definido ainda. ── */
const totalMatches = computed(() => challenges.value.filter(c => c.status === 'completed').length)
const wins = computed(() => challenges.value.filter(c => c.status === 'completed' && c.winner_id === MY_ID).length)
const losses = computed(() => totalMatches.value - wins.value)
const winRate = computed(() => totalMatches.value ? Math.round((wins.value / totalMatches.value) * 100) : 0)
const rating = computed(() => profile.value?.fair_play_rating ?? 5.0)
const ratingLabel = computed(() => {
  const r = rating.value
  if (r >= 4.5) return 'Reputação exemplar'
  if (r >= 3.5) return 'Boa reputação'
  if (r >= 2.5) return 'Reputação regular'
  return 'Reputação em risco'
})
const ratingIconClass = computed(() => {
  const r = rating.value
  if (r >= 4.5) return 'bg-accent/10 text-accent'
  if (r >= 3.5) return 'bg-emerald-400/10 text-emerald-400'
  if (r >= 2.5) return 'bg-amber-400/10 text-amber-400'
  return 'bg-red-400/10 text-red-400'
})

const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

/* ── Desafios ── */
const activeChallenges = computed(() =>
  challenges.value
    .filter(c => c.status === 'open' || c.status === 'accepted' || c.status === 'in_progress')
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

/* ── Ações pendentes (banner "Precisa de você") ──────────────────────────
   Deriva 100% do payload de /my-challenges (já embute join_requests). Duas
   ações time-sensitive, ambas resolvidas dentro da tela da partida (/match):
   1. Reportar resultado: desafio 'in_progress' onde o MEU lado ainda não
      reportou (fn_report_challenge_result exige in_progress + meu *_result
      nulo — ver 26_match_settlement_hold.sql).
   2. Solicitações de entrada: sou o criador e há pedido 'pending' na fila. */
type PendingKind = 'report' | 'join'
interface PendingAction { key: string; kind: PendingKind; title: string; subtitle: string; to: string }

const pendingActions = computed<PendingAction[]>(() => {
  const out: PendingAction[] = []
  for (const c of challenges.value) {
    const iAmCreator = c.creator_id === MY_ID
    const myResult = iAmCreator ? c.creator_result : c.opponent_result
    if (c.status === 'in_progress' && !myResult) {
      out.push({
        key: `report-${c.id}`,
        kind: 'report',
        title: 'Reportar resultado',
        subtitle: `${c.game} · vs ${opponentName(c)}`,
        to: `/match/${c.id}`,
      })
    }
    if (iAmCreator) {
      const n = (c.join_requests || []).filter(r => r.status === 'pending').length
      if (n > 0) {
        out.push({
          key: `join-${c.id}`,
          kind: 'join',
          title: n === 1 ? '1 solicitação de entrada' : `${n} solicitações de entrada`,
          subtitle: `${c.game} · aguardando sua aprovação`,
          to: `/match/${c.id}`,
        })
      }
    }
  }
  return out
})

const statusMeta: Record<ChallengeStatus, { label: string; dot: string; text: string }> = {
  open: { label: 'Aberto', dot: 'bg-semantic-success', text: 'text-semantic-success' },
  accepted: { label: 'Confirmar presença', dot: 'bg-amber-400', text: 'text-amber-400' },
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

/* Prêmio retido (resultado aceito por timeout): dias até liberar, ou null. */
const heldDaysLeft = (c: Challenge): number | null => {
  if (c.status !== 'completed' || !c.settlement_release_at) return null
  const ms = new Date(c.settlement_release_at).getTime() - Date.now()
  return ms > 0 ? Math.max(1, Math.ceil(ms / 86_400_000)) : null
}

</script>

<template>
  <div class="mx-auto w-full max-w-[1600px] space-y-8 p-6 lg:p-10">

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
            <div class="flex flex-wrap items-center gap-x-3 gap-y-1.5">
              <h1 class="font-display text-2xl font-bold text-ink sm:text-3xl">{{ greeting }}, {{ displayName }}</h1>
              <span
                :title="ratingLabel"
                class="inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-body-sm font-bold tabular-nums transition-colors"
                :class="ratingIconClass"
              >
                <Star :size="14" fill="currentColor" /> {{ rating.toFixed(1) }}
              </span>
            </div>
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

      <!-- Ações pendentes ("Precisa de você") — só aparece quando há algo a
           resolver; nada de placeholder oco quando a fila está limpa. -->
      <section v-if="pendingActions.length" class="space-y-3">
        <h2 class="flex items-center gap-2 text-xl font-bold text-ink">
          <span class="grid size-6 place-items-center rounded-md bg-amber-400/15 text-amber-400"><BellRing :size="14" /></span>
          Precisa de você
        </h2>
        <div class="space-y-2.5">
          <router-link
            v-for="a in pendingActions"
            :key="a.key"
            :to="a.to"
            class="group flex items-center gap-4 rounded-2xl border border-amber-400/30 bg-amber-400/[0.06] p-4 no-underline transition-all hover:border-amber-400/50 hover:bg-amber-400/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400/50"
          >
            <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-amber-400/15 text-amber-400">
              <component :is="a.kind === 'report' ? Flag : UserPlus" :size="20" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="font-semibold text-ink">{{ a.title }}</p>
              <p class="mt-0.5 truncate text-caption text-ink-tertiary">{{ a.subtitle }}</p>
            </div>
            <span class="flex shrink-0 items-center gap-1 text-caption font-semibold text-amber-400">
              Resolver <ChevronRight :size="15" class="transition-transform group-hover:translate-x-0.5" />
            </span>
          </router-link>
        </div>
      </section>

      <!-- Desafios ativos -->
      <section class="space-y-4">
        <div v-if="challengesLoading || activeChallenges.length" class="flex items-center justify-between">
          <div>
            <h2 class="text-xl font-bold text-ink">Desafios ativos</h2>
            <p class="mt-0.5 text-body-sm text-ink-subtle">Suas partidas em aberto e ao vivo.</p>
          </div>
          <router-link
            to="/create-challenge"
            class="inline-flex shrink-0 items-center gap-2 whitespace-nowrap rounded-lg border border-hairline bg-surface-2 px-4 py-2 text-body-sm font-semibold text-ink no-underline transition-colors hover:bg-surface-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
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
            :to="(c.status === 'in_progress' || c.status === 'accepted') ? `/match/${c.id}` : '/challenges'"
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

        <!-- Vazio: colapsa num CTA compacto de uma linha em vez de um bloco
             tracejado grande — só "pesa" na tela quando há desafio de verdade. -->
        <router-link
          v-else
          to="/create-challenge"
          class="group flex items-center gap-4 rounded-2xl border border-hairline bg-surface-1 p-4 no-underline transition-all hover:border-primary/40 hover:bg-surface-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
        >
          <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
            <Plus :size="22" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold text-ink">Criar um desafio</p>
            <p class="mt-0.5 truncate text-caption text-ink-tertiary">Sem desafios ativos. Abre um e mostra em campo quem manda.</p>
          </div>
          <ChevronRight :size="18" class="shrink-0 text-ink-tertiary transition-transform group-hover:translate-x-0.5" />
        </router-link>
      </section>

      <!-- Estatísticas (faixa compacta — o retrospecto detalhado vive no Perfil) -->
      <section v-reveal class="flex items-stretch divide-x divide-hairline overflow-hidden rounded-2xl border border-hairline bg-surface-1">
        <div class="flex-1 px-3 py-3.5 text-center sm:px-4">
          <p class="font-display text-xl font-bold tabular-nums text-ink sm:text-2xl">{{ totalMatches }}</p>
          <p class="mt-0.5 text-caption text-ink-tertiary">Partidas</p>
        </div>
        <div class="flex-1 px-3 py-3.5 text-center sm:px-4">
          <p class="font-display text-xl font-bold tabular-nums text-semantic-success sm:text-2xl">{{ wins }}</p>
          <p class="mt-0.5 text-caption text-ink-tertiary">Vitórias</p>
        </div>
        <div class="flex-1 px-3 py-3.5 text-center sm:px-4">
          <p class="font-display text-xl font-bold tabular-nums text-ink sm:text-2xl">{{ losses }}</p>
          <p class="mt-0.5 text-caption text-ink-tertiary">Derrotas</p>
        </div>
        <div class="flex-1 px-3 py-3.5 text-center sm:px-4">
          <p class="font-display text-xl font-bold tabular-nums text-accent sm:text-2xl">{{ winRate }}%</p>
          <p class="mt-0.5 text-caption text-ink-tertiary">Taxa</p>
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
            <router-link
              v-for="c in historyChallenges"
              :key="c.id"
              :to="`/match/${c.id}`"
              class="group flex items-center justify-between gap-3 px-5 py-3.5 no-underline transition-colors hover:bg-surface-2"
            >
              <div class="min-w-0">
                <p class="truncate text-body-sm font-medium text-ink">{{ c.game }} · vs {{ opponentName(c) }}</p>
                <p class="text-caption text-ink-tertiary">{{ timeAgo(c.created_at) }}</p>
              </div>
              <div class="flex shrink-0 items-center gap-2">
                <div class="text-right">
                  <p class="text-body-sm font-bold tabular-nums" :class="challengeResult(c).tone">
                    <template v-if="c.status === 'disputed'">
                      <ShieldAlert :size="14" class="mr-0.5 inline" />Em disputa
                    </template>
                    <template v-else>
                      {{ challengeResult(c).amount > 0 ? '+' : '' }}{{ fmtBRL(challengeResult(c).amount) }}
                    </template>
                  </p>
                  <p class="text-caption" :class="challengeResult(c).tone">{{ challengeResult(c).label }}</p>
                  <p v-if="heldDaysLeft(c)" class="mt-0.5 inline-flex items-center gap-1 rounded-full bg-amber-400/10 px-1.5 py-0.5 text-[10px] font-semibold text-amber-500">
                    <Clock :size="9" /> libera em {{ heldDaysLeft(c) }}d
                  </p>
                </div>
                <ChevronRight :size="16" class="shrink-0 text-ink-tertiary transition-transform group-hover:translate-x-0.5" />
              </div>
            </router-link>
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
