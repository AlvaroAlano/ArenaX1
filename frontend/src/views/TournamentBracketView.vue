<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ArrowLeft, Crown, Gamepad2, Users, Swords } from '@lucide/vue'
import { api } from '@/services/api'

const route = useRoute()
const tournamentId = route.params.id as string

interface Participant {
  id: string
  display_name: string
  team_name: string | null
  bracket_seed: number
}
interface Match {
  id: string
  round: number
  slot: number
  participant_a_id: string | null
  participant_b_id: string | null
  score_a: number | null
  score_b: number | null
  winner_participant_id: string | null
  status: 'waiting_players' | 'ready' | 'completed'
}
interface TournamentDetail {
  id: string
  title: string
  game: string
  max_players: number
  status: 'in_progress' | 'completed' | 'cancelled'
  champion_participant_id: string | null
  participants: Participant[]
  matches: Match[]
}

const tournament = ref<TournamentDetail | null>(null)
const loading = ref(true)
const loadError = ref('')

const scoreInputs = ref<Record<string, { a: number | null; b: number | null }>>({})
const submittingMatchId = ref<string | null>(null)
const submitError = ref('')

function getScoreInput(matchId: string) {
  if (!scoreInputs.value[matchId]) scoreInputs.value[matchId] = { a: null, b: null }
  return scoreInputs.value[matchId]
}

// silent=true evita o flash de tela cheia ao recarregar depois de um placar
// salvo — a chave já está na tela, só os dados precisam ser atualizados.
const loadTournament = async (silent = false) => {
  if (!silent) loading.value = true
  loadError.value = ''
  try {
    tournament.value = await api.get<TournamentDetail>(`/api/tournaments/${tournamentId}`)
  } catch (err: any) {
    loadError.value = err.message || 'Não foi possível carregar este torneio.'
  } finally {
    if (!silent) loading.value = false
  }
}
onMounted(loadTournament)

const participantById = computed(() => {
  const map = new Map<string, Participant>()
  tournament.value?.participants.forEach(p => map.set(p.id, p))
  return map
})

const totalRounds = computed(() => {
  const n = tournament.value?.max_players
  return n === 4 ? 2 : n === 8 ? 3 : n === 16 ? 4 : 0
})

const roundsGrouped = computed(() => {
  if (!tournament.value) return []
  const byRound = new Map<number, Match[]>()
  tournament.value.matches.forEach(m => {
    if (!byRound.has(m.round)) byRound.set(m.round, [])
    byRound.get(m.round)!.push(m)
  })
  return Array.from(byRound.entries())
    .sort((a, b) => a[0] - b[0])
    .map(([round, matches]) => ({
      round,
      label: roundLabel(round),
      matches: matches.sort((a, b) => a.slot - b.slot),
    }))
})

function roundLabel(round: number): string {
  const fromEnd = totalRounds.value - round
  if (fromEnd === 0) return 'Final'
  if (fromEnd === 1) return 'Semifinal'
  if (fromEnd === 2) return 'Quartas de Final'
  if (fromEnd === 3) return 'Oitavas de Final'
  return `Rodada ${round}`
}

const champion = computed(() => {
  if (!tournament.value?.champion_participant_id) return null
  return participantById.value.get(tournament.value.champion_participant_id) || null
})

const statusMeta = {
  in_progress: { label: 'Ao vivo', dot: 'bg-accent', text: 'text-accent' },
  completed: { label: 'Concluído', dot: 'bg-ink-tertiary', text: 'text-ink-tertiary' },
  cancelled: { label: 'Cancelado', dot: 'bg-semantic-error', text: 'text-semantic-error' },
} as const

const submitScore = async (match: Match) => {
  const input = scoreInputs.value[match.id]
  if (!input || input.a === null || input.b === null) return
  if (input.a === input.b) {
    submitError.value = 'Não pode haver empate no mata-mata.'
    return
  }

  submittingMatchId.value = match.id
  submitError.value = ''
  try {
    await api.post('/api/tournaments/submit-result', {
      tournament_id: tournamentId,
      match_id: match.id,
      score_a: input.a,
      score_b: input.b,
    })
    await loadTournament(true) // refaz do zero — nunca remenda estado local, mas sem piscar a tela toda
  } catch (err: any) {
    submitError.value = err.message || 'Erro ao registrar o placar.'
  } finally {
    submittingMatchId.value = null
  }
}
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-6">
    <router-link to="/tournaments" class="inline-flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle no-underline transition-colors hover:text-primary">
      <ArrowLeft :size="14" />
      Voltar aos torneios
    </router-link>

    <div v-if="loading" class="flex items-center justify-center py-24">
      <svg class="h-8 w-8 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </div>

    <div v-else-if="loadError" class="flex flex-col items-center gap-3 py-24 text-center">
      <p class="font-semibold text-semantic-error">{{ loadError }}</p>
      <button @click="loadTournament()" class="text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
    </div>

    <template v-else-if="tournament">
      <!-- Cabeçalho -->
      <div class="relative overflow-hidden rounded-2xl border border-primary/25 bg-gradient-to-br from-primary/[0.14] via-surface-2 to-surface-1 p-8 text-ink shadow-glow-primary">
        <div class="absolute -bottom-8 -right-8 size-48 rounded-full bg-primary/10 blur-3xl"></div>
        <div class="relative z-10">
          <div class="mb-2 flex items-center gap-2">
            <span class="rounded-full border border-primary/30 bg-primary/15 px-2 py-0.5 text-[10px] font-bold uppercase text-primary inline-flex items-center gap-1.5">
              <span class="size-1.5 rounded-full" :class="statusMeta[tournament.status].dot"></span>
              {{ statusMeta[tournament.status].label }}
            </span>
          </div>
          <h1 class="font-display text-headline font-bold uppercase tracking-tight">{{ tournament.title }}</h1>
          <p class="mt-1 flex items-center gap-1.5 text-body-sm text-ink-subtle">
            <Gamepad2 :size="14" /> {{ tournament.game }}
            <span class="mx-1">·</span>
            <Users :size="14" /> {{ tournament.max_players }} jogadores
            <span class="mx-1">·</span>
            Torneio Local
          </p>
        </div>
      </div>

      <!-- Banner de campeão -->
      <div v-if="tournament.status === 'completed' && champion" class="relative overflow-hidden rounded-2xl border border-amber-400/30 bg-gradient-to-br from-surface-2 to-surface-1 p-8 text-center shadow-[0_0_60px_-16px_rgba(251,191,36,0.5)]">
        <Crown :size="40" class="mx-auto text-amber-400" fill="currentColor" />
        <p class="mt-3 text-eyebrow uppercase tracking-widest text-amber-400">Campeão do Torneio</p>
        <h2 class="mt-1 font-display text-2xl font-bold text-ink">{{ champion.display_name }}</h2>
        <p v-if="champion.team_name" class="mt-1 text-body-sm text-ink-subtle">{{ champion.team_name }}</p>
      </div>

      <p v-if="submitError" class="text-center text-body-sm font-semibold text-semantic-error">{{ submitError }}</p>

      <!-- Chave -->
      <div class="overflow-x-auto pb-4">
        <div class="flex gap-6" style="min-width: max-content">
          <div v-for="col in roundsGrouped" :key="col.round" class="flex w-64 shrink-0 flex-col gap-4">
            <h3 class="text-center text-caption font-bold uppercase tracking-widest text-ink-tertiary">{{ col.label }}</h3>

            <div v-for="match in col.matches" :key="match.id" class="flex flex-col gap-2 rounded-2xl border border-hairline bg-surface-1/60 p-4 backdrop-blur">
              <!-- Participante A -->
              <template v-if="match.participant_a_id && participantById.get(match.participant_a_id)">
                <div class="flex items-center justify-between gap-2 rounded-lg px-2 py-1.5" :class="match.winner_participant_id === match.participant_a_id ? 'bg-semantic-success/10' : ''">
                  <div class="min-w-0">
                    <p class="truncate text-body-sm font-semibold" :class="match.winner_participant_id === match.participant_a_id ? 'text-semantic-success' : 'text-ink'">
                      <Crown v-if="match.winner_participant_id === match.participant_a_id" :size="12" class="mr-1 inline" fill="currentColor" />
                      {{ participantById.get(match.participant_a_id)!.display_name }}
                    </p>
                    <p v-if="participantById.get(match.participant_a_id)!.team_name" class="truncate text-caption text-ink-tertiary">{{ participantById.get(match.participant_a_id)!.team_name }}</p>
                  </div>
                  <span v-if="match.score_a !== null" class="shrink-0 font-bold tabular-nums text-ink">{{ match.score_a }}</span>
                </div>
              </template>
              <div v-else class="rounded-lg border-2 border-dashed border-hairline-strong px-2 py-2.5 text-center text-caption text-ink-tertiary">
                Aguardando classificado
              </div>

              <div class="flex items-center gap-2">
                <div class="h-px flex-1 bg-hairline"></div>
                <Swords :size="12" class="text-ink-tertiary" />
                <div class="h-px flex-1 bg-hairline"></div>
              </div>

              <!-- Participante B -->
              <template v-if="match.participant_b_id && participantById.get(match.participant_b_id)">
                <div class="flex items-center justify-between gap-2 rounded-lg px-2 py-1.5" :class="match.winner_participant_id === match.participant_b_id ? 'bg-semantic-success/10' : ''">
                  <div class="min-w-0">
                    <p class="truncate text-body-sm font-semibold" :class="match.winner_participant_id === match.participant_b_id ? 'text-semantic-success' : 'text-ink'">
                      <Crown v-if="match.winner_participant_id === match.participant_b_id" :size="12" class="mr-1 inline" fill="currentColor" />
                      {{ participantById.get(match.participant_b_id)!.display_name }}
                    </p>
                    <p v-if="participantById.get(match.participant_b_id)!.team_name" class="truncate text-caption text-ink-tertiary">{{ participantById.get(match.participant_b_id)!.team_name }}</p>
                  </div>
                  <span v-if="match.score_b !== null" class="shrink-0 font-bold tabular-nums text-ink">{{ match.score_b }}</span>
                </div>
              </template>
              <div v-else class="rounded-lg border-2 border-dashed border-hairline-strong px-2 py-2.5 text-center text-caption text-ink-tertiary">
                Aguardando classificado
              </div>

              <!-- Entrada de placar -->
              <div v-if="match.status === 'ready'" class="mt-1 flex items-center gap-2 border-t border-hairline pt-3">
                <input
                  v-model.number="getScoreInput(match.id).a"
                  type="number" min="0" placeholder="0"
                  class="w-full rounded-lg border border-hairline bg-surface-2 px-2 py-1.5 text-center text-body-sm text-ink outline-none focus:ring-2 focus:ring-primary"
                />
                <span class="text-ink-tertiary">×</span>
                <input
                  v-model.number="getScoreInput(match.id).b"
                  type="number" min="0" placeholder="0"
                  class="w-full rounded-lg border border-hairline bg-surface-2 px-2 py-1.5 text-center text-body-sm text-ink outline-none focus:ring-2 focus:ring-primary"
                />
                <button
                  type="button"
                  @click="submitScore(match)"
                  :disabled="submittingMatchId === match.id"
                  class="shrink-0 rounded-lg bg-primary px-3 py-1.5 text-caption font-bold text-canvas transition-colors hover:bg-primary-hover disabled:cursor-wait disabled:opacity-60"
                >
                  {{ submittingMatchId === match.id ? '...' : 'Salvar' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
