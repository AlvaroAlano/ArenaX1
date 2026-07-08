<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { List, Calendar, History, Gamepad2, CalendarDays, Users, Trophy, SearchX, Plus, ShieldAlert } from '@lucide/vue'
import { vReveal } from '@/composables/useReveal'
import { useAuthStore } from '@/stores/auth'
import { api } from '@/services/api'

const authStore = useAuthStore()

const filter = ref('all') // 'all', 'proximos', 'concluidos'

/**
 * Formato alinhado ao contrato real do backend (ver backend/tournaments.py):
 * GET /api/tournaments/online/open devolve exatamente esta forma.
 */
type TournamentStatus = 'registration_open' | 'in_progress' | 'completed' | 'cancelled'
interface OnlineTournament {
    id: string
    title: string
    game: string
    platform: string | null
    max_players: number
    entry_fee: number
    prize_pool: number
    rake_amount: number
    status: TournamentStatus
    registration_deadline: string | null
    participant_count: number
}

const allTournaments = ref<OnlineTournament[]>([])
const loading = ref(true)
const loadError = ref('')
const isMockData = ref(false)

/* ── Dados de exemplo pra não deixar a tela vazia quando o backend (Render)
   está fora do ar ou bloqueado por CORS — some assim que a API responder. ── */
const inMs = (ms: number) => new Date(Date.now() + ms).toISOString()
const MOCK_TOURNAMENTS: OnlineTournament[] = [
    { id: 'mock-t1', title: 'Copa Arena X1 — EA FC', game: 'EA FC 26', platform: 'PS5', max_players: 8, entry_fee: 20, prize_pool: 144, rake_amount: 16, status: 'registration_open', registration_deadline: inMs(6 * 3_600_000), participant_count: 5 },
    { id: 'mock-t2', title: 'Mata-Mata eFootball Turbo', game: 'eFootball', platform: 'Crossplay', max_players: 16, entry_fee: 15, prize_pool: 216, rake_amount: 24, status: 'in_progress', registration_deadline: null, participant_count: 16 },
    { id: 'mock-t3', title: 'Liga dos Campeões da Resenha', game: 'EA FC 26', platform: 'Xbox', max_players: 4, entry_fee: 50, prize_pool: 180, rake_amount: 20, status: 'completed', registration_deadline: null, participant_count: 4 },
    { id: 'mock-t4', title: 'Torneio Relâmpago PC', game: 'eFootball', platform: 'PC', max_players: 8, entry_fee: 10, prize_pool: 72, rake_amount: 8, status: 'registration_open', registration_deadline: inMs(45 * 60_000), participant_count: 3 },
]

const loadTournaments = async () => {
    loading.value = true
    loadError.value = ''
    isMockData.value = false
    try {
        allTournaments.value = await api.get<OnlineTournament[]>('/api/tournaments/online/open')
    } catch {
        allTournaments.value = MOCK_TOURNAMENTS
        isMockData.value = true
    } finally {
        loading.value = false
    }
}
onMounted(loadTournaments)

const filterTabs = computed(() => [
    { key: 'all', label: 'Todos', icon: List, count: allTournaments.value.length },
    { key: 'proximos', label: 'Abertos/Ao vivo', icon: Calendar, count: allTournaments.value.filter(t => t.status === 'registration_open' || t.status === 'in_progress').length },
    { key: 'concluidos', label: 'Concluídos', icon: History, count: allTournaments.value.filter(t => t.status === 'completed').length },
])

const filteredTournaments = computed(() => {
    if (filter.value === 'proximos') return allTournaments.value.filter(t => t.status === 'registration_open' || t.status === 'in_progress')
    if (filter.value === 'concluidos') return allTournaments.value.filter(t => t.status === 'completed')
    return allTournaments.value.filter(t => t.status !== 'cancelled')
})

const netPrize = (t: OnlineTournament) => t.prize_pool - t.rake_amount

function deadlineLabel(iso: string | null): string {
    if (!iso) return '—'
    const diffMs = new Date(iso).getTime() - Date.now()
    if (diffMs <= 0) return 'Encerrando...'
    const hours = Math.floor(diffMs / 3_600_000)
    if (hours < 1) return `${Math.floor(diffMs / 60_000)} min`
    if (hours < 24) return `${hours}h`
    return `${Math.floor(hours / 24)} dias`
}

const onCardClick = (t: OnlineTournament, e: MouseEvent) => {
    if (t.id.startsWith('mock-')) e.preventDefault()
}

const statusMeta: Record<TournamentStatus, { label: string }> = {
    registration_open: { label: 'Inscrições abertas' },
    in_progress: { label: 'Ao vivo' },
    completed: { label: 'Concluído' },
    cancelled: { label: 'Cancelado' },
}
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-8">
    <!-- Cabeçalho -->
    <div class="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
        <div>
            <span class="text-eyebrow uppercase tracking-widest text-accent">Competições oficiais</span>
            <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Torneios Online</h1>
            <p class="mt-1 text-body-sm text-ink-subtle">Mata-mata com premiação de verdade. Entra, elimina geral e leva o pote.</p>
        </div>
        <router-link
            :to="authStore.user ? '/create-tournament' : '/register'"
            class="group inline-flex w-fit items-center justify-center gap-2 rounded-xl bg-primary px-6 py-3 text-button font-semibold text-canvas no-underline shadow-glow-primary transition-all duration-200 hover:bg-primary-hover"
        >
            <Plus :size="18" class="transition-transform duration-200 group-hover:rotate-90" />
            {{ authStore.user ? 'Criar Torneio' : 'Criar conta para criar torneio' }}
        </router-link>
    </div>

    <!-- Aviso de dados de exemplo -->
    <div v-if="isMockData" class="flex items-center gap-2.5 rounded-xl border border-accent/25 bg-accent/[0.06] px-4 py-3 text-body-sm text-accent">
        <ShieldAlert :size="16" class="shrink-0" />
        Não foi possível falar com o backend — exibindo torneios de exemplo, não são inscrições reais.
    </div>

    <!-- Filtros -->
    <div class="sticky top-16 z-40 -mx-6 border-b border-hairline/60 bg-canvas/95 px-6 pb-4 pt-2 backdrop-blur-xl md:top-[76px] lg:-mx-20 lg:px-20">
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

    <!-- Erro -->
    <div v-else-if="loadError" class="flex flex-col items-center gap-3 py-24 text-center">
        <p class="font-semibold text-semantic-error">{{ loadError }}</p>
        <button @click="loadTournaments" class="text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
    </div>

    <!-- Estado vazio -->
    <div v-else-if="filteredTournaments.length === 0" class="flex flex-col items-center gap-3 py-24 text-center">
        <span class="grid size-14 place-items-center rounded-2xl bg-surface-2 text-ink-tertiary">
            <SearchX :size="26" />
        </span>
        <p class="font-semibold text-ink">Nenhum torneio nesse filtro</p>
        <p class="max-w-xs text-body-sm text-ink-subtle">Troca o filtro ou monta o teu mata-mata e chama a galera pra briga.</p>
    </div>

    <!-- Grid de torneios -->
    <div v-else class="grid grid-cols-1 gap-5 lg:grid-cols-2 xl:grid-cols-3">
        <router-link
            v-for="(t, i) in filteredTournaments"
            :key="t.id"
            :to="'/tournaments/' + t.id"
            @click="onCardClick(t, $event)"
            v-reveal="`${(i % 6) * 60}ms`"
            class="glow-border group flex flex-col overflow-hidden rounded-2xl border border-hairline bg-surface-1/60 backdrop-blur transition-all duration-300 hover:-translate-y-0.5 hover:border-hairline-strong no-underline"
            :class="t.status === 'completed' ? 'opacity-70' : ''"
        >
            <!-- Banner -->
            <div class="relative flex h-28 items-center justify-center overflow-hidden border-b border-hairline bg-surface-2 p-5">
                <Trophy :size="80" class="pointer-events-none absolute -right-4 -top-4 text-ink/[0.04]" />
                <div class="z-10 text-center">
                    <h3 class="max-w-[220px] truncate font-display text-lg font-bold text-ink">{{ t.title }}</h3>
                    <span class="mt-2 inline-flex items-center gap-1.5 rounded-full border border-accent/30 bg-accent/10 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-accent">
                        <Gamepad2 :size="12" /> {{ t.game }}
                    </span>
                </div>
            </div>

            <!-- Corpo -->
            <div class="flex flex-col gap-4 p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-caption uppercase tracking-widest text-ink-tertiary">Premiação</p>
                        <p class="text-lg font-bold" :class="t.status === 'completed' ? 'text-ink-subtle' : 'text-semantic-success'">R$ {{ netPrize(t).toFixed(2) }}</p>
                    </div>
                    <div class="text-right">
                        <p class="text-caption uppercase tracking-widest text-ink-tertiary">Inscrição</p>
                        <p class="text-body-sm font-semibold text-ink">R$ {{ t.entry_fee.toFixed(2) }}</p>
                    </div>
                </div>

                <div class="flex flex-col gap-2 rounded-xl border border-hairline bg-surface-2 p-4">
                    <div v-if="t.status === 'registration_open'" class="flex items-center justify-between text-body-sm">
                        <span class="inline-flex items-center gap-1.5 text-ink-tertiary"><CalendarDays :size="14" /> Encerra em</span>
                        <span class="font-medium text-ink">{{ deadlineLabel(t.registration_deadline) }}</span>
                    </div>
                    <div v-else class="flex items-center justify-between text-body-sm">
                        <span class="inline-flex items-center gap-1.5 text-ink-tertiary"><CalendarDays :size="14" /> Status</span>
                        <span class="font-medium text-ink">{{ statusMeta[t.status].label }}</span>
                    </div>
                    <div class="flex items-center justify-between text-body-sm">
                        <span class="inline-flex items-center gap-1.5 text-ink-tertiary"><Users :size="14" /> Vagas</span>
                        <span class="font-bold" :class="t.status === 'completed' ? 'text-ink-tertiary' : 'text-accent'">{{ t.participant_count }}/{{ t.max_players }}</span>
                    </div>
                </div>

                <div
                    class="rounded-xl py-2.5 text-center text-button font-semibold transition-colors duration-200"
                    :class="t.status === 'completed' ? 'bg-surface-3 text-ink-tertiary' : 'bg-surface-3 text-ink-subtle group-hover:bg-primary group-hover:text-canvas'"
                >
                    {{ t.status === 'registration_open' ? 'Entrar / Ver Detalhes' : t.status === 'completed' ? 'Ver Chaveamento' : 'Ver Partidas' }}
                </div>
            </div>
        </router-link>
    </div>
  </div>
</template>
