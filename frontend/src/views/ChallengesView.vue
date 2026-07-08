<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  User,
  List,
  Swords,
  PlayCircle,
  CheckCircle2,
  Mail,
  CalendarDays,
  Wallet,
  Users,
  Trophy,
  UserPlus,
  Plus,
  SearchX,
  Star,
  ShieldAlert,
  Trash2,
} from '@lucide/vue'
import { vReveal } from '@/composables/useReveal'
import { useAuthStore } from '@/stores/auth'
import { useWalletStore } from '@/stores/wallet'
import { api } from '@/services/api'
import { useRouter } from 'vue-router'

const authStore = useAuthStore()
const walletStore = useWalletStore()
const router = useRouter()

/**
 * Formato alinhado ao contrato real do backend (ver backend/challenges.py):
 * GET /api/challenges/open (público) e GET /api/challenges/my-challenges
 * (autenticado) devolvem exatamente esta forma.
 */
type ChallengeStatus = 'open' | 'in_progress' | 'completed' | 'disputed' | 'cancelled'
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

const filter = ref(authStore.user ? 'meus' : 'all') // Default filter
const loading = ref(true)
const loadError = ref('')
const isMockData = ref(false)

/* ── Dados de exemplo pra não deixar a tela vazia quando o backend (Render)
   está fora do ar ou bloqueado por CORS — some assim que a API responder. ── */
const agoISO = (minutes: number) => new Date(Date.now() - minutes * 60_000).toISOString()
const MOCK_CHALLENGES: Challenge[] = [
    { id: 'mock-1', creator_id: 'mock-user-1', opponent_id: null, bet_amount: 25, platform: 'PS5', game: 'EA FC 26', status: 'open', winner_id: null, created_at: agoISO(8), creator_profile: { username: 'RonaldoBSB', fair_play_rating: 4.8 }, opponent_profile: null },
    { id: 'mock-2', creator_id: 'mock-user-2', opponent_id: 'mock-user-3', bet_amount: 50, platform: 'Xbox', game: 'EA FC 26', status: 'in_progress', winner_id: null, created_at: agoISO(22), creator_profile: { username: 'ZicoPlayer', fair_play_rating: 4.5 }, opponent_profile: { username: 'NetoGamer', fair_play_rating: 4.2 } },
    { id: 'mock-3', creator_id: 'mock-user-4', opponent_id: null, bet_amount: 15, platform: 'PC', game: 'eFootball', status: 'open', winner_id: null, created_at: agoISO(40), creator_profile: { username: 'FenomenoX', fair_play_rating: 5.0 }, opponent_profile: null },
    { id: 'mock-4', creator_id: 'mock-user-5', opponent_id: 'mock-user-6', bet_amount: 100, platform: 'Crossplay', game: 'EA FC 26', status: 'completed', winner_id: 'mock-user-5', created_at: agoISO(180), creator_profile: { username: 'CraqueDoGramado', fair_play_rating: 4.9 }, opponent_profile: { username: 'ZagueiroPro', fair_play_rating: 3.8 } },
    { id: 'mock-5', creator_id: 'mock-user-7', opponent_id: 'mock-user-8', bet_amount: 30, platform: 'PS5', game: 'eFootball', status: 'disputed', winner_id: null, created_at: agoISO(320), creator_profile: { username: 'ArteiroBR', fair_play_rating: 4.1 }, opponent_profile: { username: 'MuralhaFC', fair_play_rating: 4.6 } },
]

/* ── Tempo relativo a partir de um timestamp real (created_at) ── */
function timeAgo(iso: string): string {
    const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60_000)
    if (mins < 1) return 'Agora mesmo'
    if (mins < 60) return `Há ${mins} min`
    const hours = Math.floor(mins / 60)
    if (hours < 24) return hours === 1 ? 'Há 1 hora' : `Há ${hours} horas`
    const days = Math.floor(hours / 24)
    return days === 1 ? 'Ontem' : `Há ${days} dias`
}

const MY_ID = authStore.user?.id || null

const allChallenges = ref<Challenge[]>([])

/* ── Carrega dados reais: /open é público, /my-challenges só quando logado.
   "Ao vivo"/"Terminados" só cobrem partidas do próprio usuário porque não
   existe (ainda) um endpoint de partidas em andamento de outros jogadores. ── */
const loadChallenges = async () => {
    loading.value = true
    loadError.value = ''
    isMockData.value = false
    try {
        const requests: Promise<Challenge[]>[] = [api.get<Challenge[]>('/api/challenges/open')]
        if (authStore.user) requests.push(api.get<Challenge[]>('/api/challenges/my-challenges'))

        const results = await Promise.all(requests)
        const merged = new Map<string, Challenge>()
        results.flat().forEach((c) => merged.set(c.id, c))
        allChallenges.value = Array.from(merged.values())
    } catch {
        allChallenges.value = MOCK_CHALLENGES
        isMockData.value = true
    } finally {
        loading.value = false
    }
}

onMounted(loadChallenges)

const acceptingId = ref<string | null>(null)

const handleAccept = async (c: Challenge) => {
    if (!authStore.user) {
        router.push('/register')
        return
    }
    if (c.id.startsWith('mock-')) {
        alert('Este é um desafio de exemplo — volte quando o servidor estiver disponível.')
        return
    }
    if (!confirm(`Confirmar aposta de R$ ${c.bet_amount.toFixed(2)} contra ${c.creator_profile.username}?`)) return

    acceptingId.value = c.id
    try {
        await api.post('/api/challenges/accept', { challenge_id: c.id })
        walletStore.fetchWallet(true)
        router.push(`/match/${c.id}`)
    } catch (err: any) {
        alert(err.message || 'Erro ao aceitar o desafio.')
        await loadChallenges() // outro jogador pode ter aceitado primeiro
    } finally {
        acceptingId.value = null
    }
}

const cancellingId = ref<string | null>(null)

/* ── Só cancela (nunca edita) um desafio aberto — editar em cima de uma
   aposta que outro jogador pode aceitar a qualquer instante criaria uma
   corrida real entre o dono editando e alguém aceitando o valor antigo. ── */
const handleCancel = async (c: Challenge) => {
    if (c.id.startsWith('mock-')) return
    if (!confirm(`Cancelar este desafio de R$ ${c.bet_amount.toFixed(2)}? O valor volta pro seu saldo.`)) return

    cancellingId.value = c.id
    try {
        await api.post('/api/challenges/cancel', { challenge_id: c.id })
        await loadChallenges()
        walletStore.fetchWallet(true)
    } catch (err: any) {
        alert(err.message || 'Erro ao cancelar o desafio.')
    } finally {
        cancellingId.value = null
    }
}

const filteredChallenges = computed(() => {
    if (filter.value === 'meus') return allChallenges.value.filter(c => c.creator_id === MY_ID || c.opponent_id === MY_ID)
    if (filter.value === 'all') return allChallenges.value.filter(c => c.status === 'open' || c.status === 'in_progress')
    if (filter.value === 'abertos') return allChallenges.value.filter(c => c.status === 'open')
    if (filter.value === 'em_curso') return allChallenges.value.filter(c => c.status === 'in_progress')
    if (filter.value === 'terminados') return allChallenges.value.filter(c => c.status === 'completed' || c.status === 'disputed' || c.status === 'cancelled')
    if (filter.value === 'convites') return [] // Sem endpoint de convites ainda
    return []
})

/* ── Stats ao vivo (derivadas dos dados reais carregados) ── */
const openCount = computed(() => allChallenges.value.filter(c => c.status === 'open').length)
/* ── "Em jogo" é o que está de fato retido em locked_balance agora: só a
   aposta do criador enquanto ninguém aceitou (open), as duas apostas
   quando já tem oponente (in_progress) — nunca o prêmio hipotético
   pós-rake (1,8x), que só existe depois que a partida termina. ── */
const livePoolFmt = computed(() => {
    const pool = allChallenges.value.reduce((sum, c) => {
        if (c.status === 'open') return sum + c.bet_amount
        if (c.status === 'in_progress') return sum + c.bet_amount * 2
        return sum
    }, 0)
    return pool.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 })
})
const activePlayers = computed(() => {
    const set = new Set<string>()
    allChallenges.value
        .filter(c => c.status === 'open' || c.status === 'in_progress')
        .forEach(c => { set.add(c.creator_id); if (c.opponent_id) set.add(c.opponent_id) })
    return set.size
})

/* ── Filtros (com contagem) ── */
const filterTabs = computed(() => {
    const tabs = [
        { key: 'meus', label: 'Os meus', icon: User, count: allChallenges.value.filter(c => c.creator_id === MY_ID || c.opponent_id === MY_ID).length, authOnly: true },
        { key: 'all', label: 'Todos', icon: List, count: allChallenges.value.filter(c => c.status === 'open' || c.status === 'in_progress').length, authOnly: false },
        { key: 'abertos', label: 'Abertos', icon: Swords, count: openCount.value, authOnly: false },
        { key: 'em_curso', label: 'Ao vivo', icon: PlayCircle, count: allChallenges.value.filter(c => c.status === 'in_progress').length, authOnly: false },
        { key: 'terminados', label: 'Terminados', icon: CheckCircle2, count: allChallenges.value.filter(c => c.status === 'completed' || c.status === 'disputed' || c.status === 'cancelled').length, authOnly: true },
        { key: 'convites', label: 'Convites', icon: Mail, count: 0, authOnly: true, badge: 2 },
    ]
    return authStore.user ? tabs : tabs.filter(t => !t.authOnly)
})

/* ── Status visual (chaves alinhadas ao enum real do backend) ── */
const statusMeta: Record<ChallengeStatus, { label: string; dot: string; text: string; bg: string }> = {
    open: { label: 'Aberto', dot: 'bg-semantic-success', text: 'text-semantic-success', bg: 'bg-semantic-success/10 border-semantic-success/20' },
    in_progress: { label: 'Ao vivo', dot: 'bg-accent', text: 'text-accent', bg: 'bg-accent/10 border-accent/20' },
    completed: { label: 'Concluído', dot: 'bg-ink-tertiary', text: 'text-ink-tertiary', bg: 'bg-surface-3 border-hairline' },
    disputed: { label: 'Em disputa', dot: 'bg-semantic-error', text: 'text-semantic-error', bg: 'bg-semantic-error/10 border-semantic-error/20' },
    cancelled: { label: 'Cancelado', dot: 'bg-ink-tertiary', text: 'text-ink-tertiary', bg: 'bg-surface-3 border-hairline' },
}
const getStatusMeta = (status: ChallengeStatus) => statusMeta[status] ?? statusMeta.completed

/* ── Cor por plataforma (consistente com a Classificação) ── */
const platformColor: Record<string, string> = {
    PS5: '#00439C',
    Xbox: '#107C10',
    PC: '#52525b',
    Crossplay: '#8b5cf6',
}
const ringStyle = (platform: string) => ({
    boxShadow: `0 0 0 2px var(--canvas), 0 0 0 4px ${platformColor[platform] || '#52525b'}`,
})

/* ── Prêmio: mesma regra do backend (rake_percentage = 0.10 em challenges.py) ── */
const totalPrize = (c: Challenge) => c.bet_amount * 1.8
const netProfit = (c: Challenge) => c.bet_amount * 0.8
const winnerName = (c: Challenge) => {
    if (c.winner_id === c.creator_id) return c.creator_profile.username
    if (c.opponent_profile && c.winner_id === c.opponent_id) return c.opponent_profile.username
    return c.opponent_profile?.username || c.creator_profile.username
}
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-8">
    <!-- Cabeçalho -->
    <div class="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
        <div>
            <span class="text-eyebrow uppercase tracking-widest text-accent">Arena ao vivo</span>
            <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Desafios abertos</h1>
            <p class="mt-1 text-body-sm text-ink-subtle">Escolhe o oponente, fecha o valor e prova em campo. Aqui conversa fiada não paga boleto.</p>
        </div>
        <router-link
            :to="authStore.user ? '/create-challenge' : '/register'"
            class="group inline-flex w-fit items-center justify-center gap-2 rounded-xl bg-primary px-6 py-3 text-button font-semibold text-canvas no-underline shadow-glow-primary transition-all duration-200 hover:bg-primary-hover"
        >
            <Plus :size="18" class="transition-transform duration-200 group-hover:rotate-90" />
            {{ authStore.user ? 'Criar Desafio' : 'Criar conta para desafiar' }}
        </router-link>
    </div>

    <!-- Barra de stats ao vivo -->
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div class="glass flex items-center gap-3 rounded-xl border border-hairline px-4 py-3.5">
            <span class="grid size-9 shrink-0 place-items-center rounded-lg bg-semantic-success/10 text-semantic-success">
                <Swords :size="18" />
            </span>
            <div class="leading-tight">
                <p class="font-display text-lg font-bold tabular-nums text-ink">{{ openCount }}</p>
                <p class="text-caption text-ink-tertiary">desafios abertos agora</p>
            </div>
        </div>
        <div class="glass flex items-center gap-3 rounded-xl border border-hairline px-4 py-3.5">
            <span class="grid size-9 shrink-0 place-items-center rounded-lg bg-accent/10 text-accent">
                <Wallet :size="18" />
            </span>
            <div class="leading-tight">
                <p class="font-display text-lg font-bold tabular-nums text-ink">{{ livePoolFmt }}</p>
                <p class="text-caption text-ink-tertiary">em jogo neste momento</p>
            </div>
        </div>
        <div class="glass flex items-center gap-3 rounded-xl border border-hairline px-4 py-3.5">
            <span class="grid size-9 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
                <Users :size="18" />
            </span>
            <div class="leading-tight">
                <p class="font-display text-lg font-bold tabular-nums text-ink">{{ activePlayers }}</p>
                <p class="text-caption text-ink-tertiary">jogadores ativos</p>
            </div>
        </div>
    </div>

    <!-- Aviso de dados de exemplo -->
    <div v-if="isMockData" class="flex items-center gap-2.5 rounded-xl border border-accent/25 bg-accent/[0.06] px-4 py-3 text-body-sm text-accent">
        <ShieldAlert :size="16" class="shrink-0" />
        Não foi possível falar com o backend — exibindo desafios de exemplo, não são partidas reais.
    </div>

    <!-- Filtros -->
    <div class="sticky top-14 z-40 -mx-6 border-b border-hairline/60 bg-canvas/95 px-6 py-3 backdrop-blur-xl md:top-0 lg:-mx-20 lg:px-20">
        <div class="custom-scrollbar flex gap-2 overflow-x-auto pb-1">
            <button
                v-for="tab in filterTabs"
                :key="tab.key"
                @click="filter = tab.key"
                :class="filter === tab.key
                    ? 'border-primary/40 bg-primary/15 text-primary shadow-glow-pill'
                    : 'border-hairline-strong bg-surface-1/60 text-ink-subtle hover:bg-surface-2 hover:text-ink'"
                class="relative inline-flex shrink-0 cursor-pointer items-center gap-1.5 whitespace-nowrap rounded-full border px-4 py-2 text-body-sm font-semibold transition-all duration-200"
            >
                <component :is="tab.icon" :size="14" />
                {{ tab.label }}
                <span
                    v-if="tab.count > 0"
                    class="rounded-full bg-surface-3 px-1.5 py-0.5 text-[10px] font-bold tabular-nums text-ink-subtle"
                    :class="filter === tab.key ? 'bg-primary/20 text-primary' : ''"
                >{{ tab.count }}</span>
                <span v-if="tab.badge" class="absolute -right-1 -top-1 flex size-4 items-center justify-center rounded-full bg-semantic-error text-[9px] font-bold text-white">{{ tab.badge }}</span>
            </button>
        </div>
    </div>

    <!-- Carregando -->
    <div v-if="loading" class="flex items-center justify-center py-24">
        <svg class="h-8 w-8 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
    </div>

    <!-- Erro ao carregar -->
    <div v-else-if="loadError" class="flex flex-col items-center gap-3 py-24 text-center">
        <p class="font-semibold text-semantic-error">{{ loadError }}</p>
        <button @click="loadChallenges" class="mt-2 text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
    </div>

    <!-- Estado vazio -->
    <div v-else-if="filteredChallenges.length === 0" class="flex flex-col items-center gap-3 py-24 text-center">
        <span class="grid size-14 place-items-center rounded-2xl bg-surface-2 text-ink-tertiary">
            <SearchX :size="26" />
        </span>
        <p class="font-semibold text-ink">Arena vazia por aqui</p>
        <p class="max-w-xs text-body-sm text-ink-subtle">Ninguém abriu desafio nesse filtro. Abre o teu e deixa a galera correr atrás.</p>
        <button @click="filter = 'all'" class="mt-2 text-body-sm font-semibold text-primary hover:underline">Ver todos os desafios</button>
    </div>

    <!-- Grid de desafios -->
    <div v-else class="grid grid-cols-1 gap-5 lg:grid-cols-2 xl:grid-cols-3">
        <div
            v-for="(c, i) in filteredChallenges"
            :key="c.id"
            v-reveal="`${(i % 6) * 60}ms`"
            class="glow-border group flex flex-col gap-4 rounded-2xl border border-hairline bg-surface-1/60 p-5 backdrop-blur transition-all duration-300 hover:-translate-y-0.5 hover:border-hairline-strong"
            :class="c.status === 'completed' ? 'opacity-70' : ''"
        >
            <!-- Topo: jogo + plataforma + status -->
            <div class="flex items-start justify-between gap-3">
                <div>
                    <h3 class="font-semibold text-ink">{{ c.game }}</h3>
                    <span class="text-caption text-ink-tertiary">{{ c.platform }} · 1v1</span>
                </div>
                <span
                    class="inline-flex shrink-0 items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider"
                    :class="[getStatusMeta(c.status).bg, getStatusMeta(c.status).text]"
                >
                    <span class="relative flex size-1.5">
                        <span v-if="c.status === 'in_progress'" class="absolute inline-flex size-full animate-ping rounded-full opacity-75" :class="getStatusMeta(c.status).dot"></span>
                        <span class="relative inline-flex size-1.5 rounded-full" :class="getStatusMeta(c.status).dot"></span>
                    </span>
                    {{ getStatusMeta(c.status).label }}
                </span>
            </div>

            <!-- Confronto -->
            <div class="grid grid-cols-[1fr_auto_1fr] items-center gap-3">
                <router-link
                    :to="{ name: 'profile', params: { username: c.creator_profile.username } }"
                    class="flex flex-col items-center gap-1.5 text-center no-underline"
                >
                    <div
                        class="grid size-11 place-items-center rounded-full bg-primary/15 text-sm font-bold uppercase text-primary"
                        :style="ringStyle(c.platform)"
                    >{{ c.creator_profile.username.charAt(0) }}</div>
                    <span class="max-w-[88px] truncate text-body-sm font-medium text-ink hover:text-primary">{{ c.creator_profile.username }}</span>
                    <span class="inline-flex items-center gap-0.5 text-[10px] font-semibold text-amber-500">
                        <Star :size="10" fill="currentColor" />{{ c.creator_profile.fair_play_rating.toFixed(1) }}
                    </span>
                </router-link>

                <span class="grid size-7 shrink-0 place-items-center rounded-full border border-hairline-strong text-[10px] font-bold text-ink-tertiary">VS</span>

                <template v-if="c.opponent_profile">
                    <router-link
                        :to="{ name: 'profile', params: { username: c.opponent_profile.username } }"
                        class="flex flex-col items-center gap-1.5 text-center no-underline"
                    >
                        <div
                            class="grid size-11 place-items-center rounded-full bg-primary/15 text-sm font-bold uppercase text-primary"
                            :style="ringStyle(c.platform)"
                        >{{ c.opponent_profile.username.charAt(0) }}</div>
                        <span class="max-w-[88px] truncate text-body-sm font-medium text-ink hover:text-primary">{{ c.opponent_profile.username }}</span>
                        <span class="inline-flex items-center gap-0.5 text-[10px] font-semibold text-amber-500">
                            <Star :size="10" fill="currentColor" />{{ c.opponent_profile.fair_play_rating.toFixed(1) }}
                        </span>
                    </router-link>
                </template>
                <button
                    v-else-if="c.creator_id === MY_ID && c.status === 'open'"
                    type="button"
                    @click="handleCancel(c)"
                    :disabled="cancellingId === c.id"
                    class="group/cancel flex flex-col items-center gap-1.5 text-center disabled:cursor-wait disabled:opacity-60"
                >
                    <div class="grid size-11 place-items-center rounded-full border-2 border-dashed border-hairline-strong text-ink-tertiary transition-colors duration-200 group-hover/cancel:border-semantic-error/50 group-hover/cancel:text-semantic-error">
                        <svg v-if="cancellingId === c.id" class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                        </svg>
                        <Trash2 v-else :size="16" />
                    </div>
                    <span class="text-body-sm font-medium text-ink-tertiary transition-colors duration-200 group-hover/cancel:text-semantic-error">{{ cancellingId === c.id ? 'Cancelando...' : 'Cancelar' }}</span>
                </button>
                <div v-else-if="c.creator_id === MY_ID" class="flex flex-col items-center gap-1.5 text-center">
                    <div class="grid size-11 place-items-center rounded-full border-2 border-dashed border-hairline-strong text-ink-tertiary">
                        <UserPlus :size="18" />
                    </div>
                    <span class="text-body-sm font-medium text-ink-tertiary">Seu desafio</span>
                </div>
                <router-link
                    v-else-if="!authStore.user"
                    to="/register"
                    class="flex flex-col items-center gap-1.5 text-center no-underline"
                >
                    <div class="grid size-11 place-items-center rounded-full border-2 border-dashed border-accent/40 text-accent transition-colors duration-200 group-hover:border-accent group-hover:bg-accent/10">
                        <UserPlus :size="18" />
                    </div>
                    <span class="text-body-sm font-medium text-accent">Vaga aberta</span>
                </router-link>
                <button
                    v-else
                    type="button"
                    @click="handleAccept(c)"
                    :disabled="acceptingId === c.id"
                    class="flex flex-col items-center gap-1.5 text-center disabled:cursor-wait disabled:opacity-60"
                >
                    <div class="grid size-11 place-items-center rounded-full border-2 border-dashed border-accent/40 text-accent transition-colors duration-200 group-hover:border-accent group-hover:bg-accent/10">
                        <svg v-if="acceptingId === c.id" class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                        </svg>
                        <UserPlus v-else :size="18" />
                    </div>
                    <span class="text-body-sm font-medium text-accent">{{ acceptingId === c.id ? 'Aceitando...' : 'Aceitar desafio' }}</span>
                </button>
            </div>

            <!-- Rodapé: horário + aposta/prêmio -->
            <div class="flex items-center justify-between border-t border-hairline pt-3.5 text-body-sm">
                <span class="inline-flex items-center gap-1.5 text-ink-tertiary">
                    <CalendarDays :size="14" />
                    {{ timeAgo(c.created_at) }}
                </span>
                <div class="flex items-center gap-2">
                    <span class="text-caption text-ink-tertiary">R$ {{ c.bet_amount.toFixed(2) }}</span>
                    <span class="text-ink-tertiary">→</span>
                    <span class="font-bold" :class="c.status === 'completed' ? 'text-ink-subtle' : 'text-semantic-success'">R$ {{ totalPrize(c).toFixed(2) }}</span>
                </div>
            </div>

            <!-- Vencedor (concluído) -->
            <div v-if="c.status === 'completed'" class="flex items-center gap-2 rounded-xl border border-semantic-success/20 bg-semantic-success/5 px-3.5 py-2.5 text-body-sm">
                <Trophy :size="16" class="text-semantic-success" />
                <span class="text-ink-subtle">Vencedor:</span>
                <span class="font-bold text-semantic-success">{{ winnerName(c) }}</span>
                <span class="ml-auto font-bold text-semantic-success">+R$ {{ netProfit(c).toFixed(2) }}</span>
            </div>

            <!-- Em disputa -->
            <div v-else-if="c.status === 'disputed'" class="flex items-center gap-2 rounded-xl border border-semantic-error/20 bg-semantic-error/5 px-3.5 py-2.5 text-body-sm">
                <ShieldAlert :size="16" class="text-semantic-error" />
                <span class="text-ink-subtle">Resultados divergentes — em mediação pela ArenaX1.</span>
            </div>
        </div>
    </div>
  </div>
</template>
