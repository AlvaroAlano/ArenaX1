<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft, Lock, Medal, Landmark, Users, Gamepad2, CalendarClock,
  Crown, Swords, ShieldAlert, UserPlus, LogOut, CheckCircle2, XCircle, Info,
} from '@lucide/vue'
import { api } from '@/services/api'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const tournamentId = route.params.id as string

/**
 * Formato alinhado ao contrato real do backend (ver backend/tournaments.py):
 * GET /api/tournaments/online/{id} devolve exatamente esta forma.
 */
type TournamentStatus = 'registration_open' | 'in_progress' | 'completed' | 'cancelled'
type MatchStatus = 'waiting_players' | 'ready' | 'completed' | 'disputed'
interface Participant {
  id: string
  user_id: string | null
  display_name: string
  bracket_seed: number | null
}
interface Match {
  id: string
  round: number
  slot: number
  participant_a_id: string | null
  participant_b_id: string | null
  result_a: 'win' | 'loss' | null
  result_b: 'win' | 'loss' | null
  winner_participant_id: string | null
  status: MatchStatus
  is_third_place: boolean
}
interface TournamentDetail {
  id: string
  host_id: string
  title: string
  game: string
  platform: string | null
  max_players: number
  entry_fee: number
  prize_pool: number
  rake_amount: number
  status: TournamentStatus
  registration_deadline: string | null
  champion_participant_id: string | null
  runner_up_participant_id: string | null
  third_place_participant_id: string | null
  fourth_place_participant_id: string | null
  participants: Participant[]
  matches: Match[]
}

const tournament = ref<TournamentDetail | null>(null)
const loading = ref(true)
const loadError = ref('')

const loadTournament = async (silent = false) => {
  if (!silent) loading.value = true
  loadError.value = ''
  try {
    tournament.value = await api.get<TournamentDetail>(`/api/tournaments/online/${tournamentId}`)
  } catch (err: any) {
    loadError.value = err.message || 'Não foi possível carregar este torneio.'
  } finally {
    if (!silent) loading.value = false
  }
}

// Deep-link vindo de uma notificação (?match=<id>): rola até a partida
// específica na chave e destaca ela por alguns segundos — sem isso o
// usuário cai na chave inteira e precisa procurar o próprio confronto.
const highlightedMatchId = ref<string | null>(null)

onMounted(async () => {
  await loadTournament()
  const matchId = route.query.match
  if (typeof matchId === 'string' && matchId) {
    highlightedMatchId.value = matchId
    await nextTick()
    document.getElementById(`tournament-match-${matchId}`)?.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' })
    setTimeout(() => {
      if (highlightedMatchId.value === matchId) highlightedMatchId.value = null
    }, 3000)
  }
})

const participantById = computed(() => {
  const map = new Map<string, Participant>()
  tournament.value?.participants.forEach(p => map.set(p.id, p))
  return map
})

const myParticipant = computed(() => {
  if (!authStore.user) return null
  return tournament.value?.participants.find(p => p.user_id === authStore.user!.id) || null
})

const netPool = computed(() => tournament.value ? tournament.value.prize_pool - tournament.value.rake_amount : 0)

// Tabela de premiação por tamanho de chave, sempre sobre o pote líquido —
// mesma regra do backend (fn_submit_online_match_result /
// fn_resolve_online_match_dispute, ver backend/19_tiered_prize_distribution.sql).
// 4 jogadores: só o campeão leva. 8: top 3. 16: top 4.
const prizeTiers = computed(() => {
  if (!tournament.value) return []
  const pool = netPool.value
  const table = tournament.value.max_players === 4
    ? [{ label: '1º Lugar', medal: '🥇', pct: 1.00, color: 'text-semantic-success', participantId: tournament.value.champion_participant_id }]
    : tournament.value.max_players === 8
    ? [
        { label: '1º Lugar', medal: '🥇', pct: 0.55, color: 'text-semantic-success', participantId: tournament.value.champion_participant_id },
        { label: '2º Lugar', medal: '🥈', pct: 0.30, color: 'text-ink-muted', participantId: tournament.value.runner_up_participant_id },
        { label: '3º Lugar', medal: '🥉', pct: 0.15, color: 'text-accent', participantId: tournament.value.third_place_participant_id },
      ]
    : [
        { label: '1º Lugar', medal: '🥇', pct: 0.50, color: 'text-semantic-success', participantId: tournament.value.champion_participant_id },
        { label: '2º Lugar', medal: '🥈', pct: 0.25, color: 'text-ink-muted', participantId: tournament.value.runner_up_participant_id },
        { label: '3º Lugar', medal: '🥉', pct: 0.15, color: 'text-accent', participantId: tournament.value.third_place_participant_id },
        { label: '4º Lugar', medal: '🏅', pct: 0.10, color: 'text-ink', participantId: tournament.value.fourth_place_participant_id },
      ]
  return table.map(t => ({ ...t, amount: pool * t.pct }))
})

// Mesmo corte de 30min aplicado em fn_leave_online_tournament — mostrado
// proativamente pra não deixar o usuário tentar e só descobrir pelo erro.
const canLeave = computed(() => {
  if (!tournament.value?.registration_deadline) return true
  return new Date(tournament.value.registration_deadline).getTime() - Date.now() > 30 * 60_000
})

const totalRounds = computed(() => {
  const n = tournament.value?.max_players
  return n === 4 ? 2 : n === 8 ? 3 : n === 16 ? 4 : 0
})

function roundLabel(round: number): string {
  const fromEnd = totalRounds.value - round
  if (fromEnd === 0) return 'Final'
  if (fromEnd === 1) return 'Semifinal'
  if (fromEnd === 2) return 'Quartas de Final'
  if (fromEnd === 3) return 'Oitavas de Final'
  return `Rodada ${round}`
}

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

function deadlineLabel(iso: string | null): string {
  if (!iso) return '—'
  const diffMs = new Date(iso).getTime() - Date.now()
  if (diffMs <= 0) return 'Encerrando...'
  const hours = Math.floor(diffMs / 3_600_000)
  if (hours < 1) return `${Math.floor(diffMs / 60_000)} min`
  if (hours < 24) return `${hours}h ${Math.floor((diffMs % 3_600_000) / 60_000)}min`
  return `${Math.floor(hours / 24)} dias`
}

const statusMeta: Record<TournamentStatus, { label: string; dot: string; text: string }> = {
  registration_open: { label: 'Inscrições abertas', dot: 'bg-semantic-success', text: 'text-semantic-success' },
  in_progress: { label: 'Ao vivo', dot: 'bg-accent', text: 'text-accent' },
  completed: { label: 'Concluído', dot: 'bg-ink-tertiary', text: 'text-ink-tertiary' },
  cancelled: { label: 'Cancelado', dot: 'bg-semantic-error', text: 'text-semantic-error' },
}

/* ── Inscrição / desistência ── */
const joining = ref(false)
const leaving = ref(false)
const actionError = ref('')

const handleJoin = async () => {
  if (!authStore.user) {
    router.push('/register')
    return
  }
  if (!confirm(`Confirmar inscrição de R$ ${tournament.value!.entry_fee.toFixed(2)} neste torneio?`)) return

  joining.value = true
  actionError.value = ''
  try {
    await api.post('/api/tournaments/online/join', { tournament_id: tournamentId })
    await loadTournament(true)
  } catch (err: any) {
    actionError.value = err.message || 'Erro ao se inscrever no torneio.'
  } finally {
    joining.value = false
  }
}

const handleLeave = async () => {
  if (!confirm('Cancelar sua inscrição? O valor será estornado para sua carteira.')) return

  leaving.value = true
  actionError.value = ''
  try {
    await api.post('/api/tournaments/online/leave', { tournament_id: tournamentId })
    await loadTournament(true)
  } catch (err: any) {
    actionError.value = err.message || 'Erro ao cancelar a inscrição.'
  } finally {
    leaving.value = false
  }
}

/* ── Reporte de resultado (consenso win/loss, mesmo padrão de MatchView.vue) ── */
const reportingMatchId = ref<string | null>(null)

function mySide(match: Match): 'a' | 'b' | null {
  if (!myParticipant.value) return null
  if (match.participant_a_id === myParticipant.value.id) return 'a'
  if (match.participant_b_id === myParticipant.value.id) return 'b'
  return null
}
function myResult(match: Match): 'win' | 'loss' | null {
  const side = mySide(match)
  if (!side) return null
  return side === 'a' ? match.result_a : match.result_b
}

const handleReport = async (match: Match, result: 'win' | 'loss') => {
  if (!confirm(`Confirma que você ${result === 'win' ? 'VENCEU' : 'PERDEU'} esta partida? Reportes falsos levam ao banimento.`)) return

  reportingMatchId.value = match.id
  actionError.value = ''
  try {
    await api.post('/api/tournaments/online/submit-result', {
      tournament_id: tournamentId,
      match_id: match.id,
      result,
    })
    await loadTournament(true)
  } catch (err: any) {
    actionError.value = err.message || 'Erro ao registrar o resultado.'
  } finally {
    reportingMatchId.value = null
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
      <!-- Cabeçalho do Torneio -->
      <div class="relative overflow-hidden rounded-2xl border border-primary/25 bg-gradient-to-br from-primary/[0.14] via-surface-2 to-surface-1 p-8 text-ink shadow-glow-primary">
        <div class="absolute -bottom-8 -right-8 size-48 rounded-full bg-primary/10 blur-3xl"></div>
        <div class="relative z-10">
          <div class="mb-4 flex items-start justify-between gap-4">
            <div>
              <div class="mb-2 flex items-center gap-2">
                <span class="rounded-full border border-primary/30 bg-primary/15 px-2 py-0.5 text-[10px] font-bold uppercase text-primary inline-flex items-center gap-1.5">
                  <span class="size-1.5 rounded-full" :class="statusMeta[tournament.status].dot"></span>
                  {{ statusMeta[tournament.status].label }}
                </span>
              </div>
              <h1 class="font-display text-headline font-bold uppercase tracking-tight">{{ tournament.title }}</h1>
              <p class="mt-1 flex flex-wrap items-center gap-1.5 text-body-sm text-ink-subtle">
                <Gamepad2 :size="14" /> {{ tournament.game }}
                <span v-if="tournament.platform" class="mx-1">·</span>
                <span v-if="tournament.platform">{{ tournament.platform }}</span>
                <span class="mx-1">·</span>
                Torneio Online Pago
              </p>
            </div>
            <div class="hidden flex-col items-center rounded-xl border border-hairline bg-surface-2 px-6 py-4 backdrop-blur md:flex">
              <span class="font-display text-2xl font-black text-primary">R$ {{ netPool.toFixed(2) }}</span>
              <span class="mt-1 text-[10px] uppercase tracking-wider text-ink-subtle">Premiação líquida</span>
            </div>
          </div>

          <div class="mt-8 flex flex-wrap gap-6">
            <div class="flex flex-col">
              <span class="text-[10px] uppercase tracking-widest text-ink-tertiary">Taxa de inscrição</span>
              <span class="text-lg font-bold text-ink">R$ {{ tournament.entry_fee.toFixed(2) }}</span>
            </div>
            <div class="w-px self-stretch bg-hairline"></div>
            <div class="flex flex-col">
              <span class="text-[10px] uppercase tracking-widest text-ink-tertiary">Jogadores</span>
              <span class="text-lg font-bold text-ink">{{ tournament.participants.length }}/{{ tournament.max_players }}</span>
            </div>
            <div class="w-px self-stretch bg-hairline"></div>
            <div v-if="tournament.status === 'registration_open'" class="flex flex-col">
              <span class="text-[10px] uppercase tracking-widest text-ink-tertiary">Inscrições encerram em</span>
              <span class="text-lg font-bold text-ink flex items-center gap-1.5"><CalendarClock :size="16" />{{ deadlineLabel(tournament.registration_deadline) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Cancelado -->
      <div v-if="tournament.status === 'cancelled'" class="rounded-2xl border border-semantic-error/20 bg-semantic-error/5 p-6 text-center">
        <p class="font-semibold text-semantic-error">Torneio cancelado — as vagas não completaram no prazo.</p>
        <p class="mt-1 text-body-sm text-ink-subtle">Todos os inscritos foram reembolsados automaticamente.</p>
      </div>

      <p v-if="actionError" class="text-center text-body-sm font-semibold text-semantic-error">{{ actionError }}</p>

      <!-- Layout Dividido -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- Coluna Esquerda -->
        <div class="space-y-6 lg:col-span-2">
          <!-- Prêmios -->
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
            <h3 class="mb-4 flex items-center gap-2 text-lg font-bold text-ink">
              <Medal :size="22" class="text-primary" />
              Prêmios
            </h3>
            <div class="grid gap-4" :class="prizeTiers.length >= 4 ? 'grid-cols-2 sm:grid-cols-4' : 'grid-cols-3'">
              <div v-for="tier in prizeTiers" :key="tier.label" class="rounded-xl border border-hairline bg-surface-2 p-4 text-center">
                <span class="text-2xl drop-shadow-md">{{ tier.medal }}</span>
                <p class="mt-2 text-lg font-bold" :class="tier.color">R$ {{ tier.amount.toFixed(2) }}</p>
                <p class="mt-1 text-caption font-bold uppercase tracking-widest text-ink-tertiary">{{ tier.label }} <span class="text-ink-tertiary">({{ (tier.pct * 100).toFixed(0) }}%)</span></p>
                <p v-if="tier.participantId" class="mt-1 truncate text-caption text-ink-subtle">{{ participantById.get(tier.participantId)?.display_name }}</p>
              </div>
            </div>
            <p class="mt-4 text-[11px] text-ink-tertiary">
              <template v-if="tournament.max_players === 4">Chave de 4: o campeão leva 100% da premiação líquida.</template>
              <template v-else-if="tournament.max_players === 8">Chave de 8: dividida 55% / 30% / 15% entre 1º, 2º e 3º lugar.</template>
              <template v-else>Chave de 16: dividida 50% / 25% / 15% / 10% entre 1º, 2º, 3º e 4º lugar.</template>
            </p>
          </div>

          <!-- Banner de campeão -->
          <div v-if="tournament.status === 'completed' && tournament.champion_participant_id" class="relative overflow-hidden rounded-2xl border border-amber-400/30 bg-gradient-to-br from-surface-2 to-surface-1 p-8 text-center shadow-[0_0_60px_-16px_rgba(251,191,36,0.5)]">
            <Crown :size="40" class="mx-auto text-amber-400" fill="currentColor" />
            <p class="mt-3 text-eyebrow uppercase tracking-widest text-amber-400">Campeão do Torneio</p>
            <h2 class="mt-1 font-display text-2xl font-bold text-ink">{{ participantById.get(tournament.champion_participant_id)?.display_name }}</h2>
          </div>

          <!-- Lista de inscritos (inscrições abertas) -->
          <div v-if="tournament.status === 'registration_open'" class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
            <h3 class="mb-4 flex items-center gap-2 text-lg font-bold text-ink">
              <Users :size="22" class="text-primary" />
              Inscritos ({{ tournament.participants.length }}/{{ tournament.max_players }})
            </h3>
            <div v-if="tournament.participants.length === 0" class="py-6 text-center text-body-sm text-ink-subtle">Ninguém se inscreveu ainda — seja o primeiro.</div>
            <div v-else class="grid grid-cols-2 sm:grid-cols-3 gap-3">
              <div v-for="p in tournament.participants" :key="p.id" class="flex items-center gap-2 rounded-xl border border-hairline bg-surface-2 px-3 py-2.5">
                <div class="grid size-8 shrink-0 place-items-center rounded-full bg-primary/15 text-xs font-bold uppercase text-primary">{{ p.display_name.charAt(0) }}</div>
                <span class="truncate text-body-sm font-medium text-ink">{{ p.display_name }}</span>
              </div>
            </div>
          </div>

          <!-- Chave (em andamento ou concluído) -->
          <div v-else class="overflow-x-auto pb-4">
            <div class="flex gap-6" style="min-width: max-content">
              <div v-for="col in roundsGrouped" :key="col.round" class="flex w-64 shrink-0 flex-col gap-4">
                <h3 class="text-center text-caption font-bold uppercase tracking-widest text-ink-tertiary">{{ col.label }}</h3>

                <div
                  v-for="match in col.matches"
                  :key="match.id"
                  :id="`tournament-match-${match.id}`"
                  class="flex flex-col gap-2 rounded-2xl border border-hairline bg-surface-1/60 p-4 backdrop-blur transition-shadow duration-500"
                  :class="highlightedMatchId === match.id ? 'ring-2 ring-primary shadow-glow-primary' : ''"
                >
                  <p v-if="match.is_third_place" class="text-center text-[10px] font-bold uppercase tracking-widest text-amber-500">Disputa de 3º Lugar</p>

                  <!-- Participante A -->
                  <template v-if="match.participant_a_id && participantById.get(match.participant_a_id)">
                    <div class="flex items-center justify-between gap-2 rounded-lg px-2 py-1.5" :class="match.winner_participant_id === match.participant_a_id ? 'bg-semantic-success/10' : ''">
                      <p class="truncate text-body-sm font-semibold" :class="match.winner_participant_id === match.participant_a_id ? 'text-semantic-success' : 'text-ink'">
                        <Crown v-if="match.winner_participant_id === match.participant_a_id" :size="12" class="mr-1 inline" fill="currentColor" />
                        {{ participantById.get(match.participant_a_id)!.display_name }}
                      </p>
                      <CheckCircle2 v-if="match.result_a" :size="14" class="shrink-0 text-ink-tertiary" />
                    </div>
                  </template>
                  <div v-else class="rounded-lg border-2 border-dashed border-hairline-strong px-2 py-2.5 text-center text-caption text-ink-tertiary">Aguardando classificado</div>

                  <div class="flex items-center gap-2">
                    <div class="h-px flex-1 bg-hairline"></div>
                    <Swords :size="12" class="text-ink-tertiary" />
                    <div class="h-px flex-1 bg-hairline"></div>
                  </div>

                  <!-- Participante B -->
                  <template v-if="match.participant_b_id && participantById.get(match.participant_b_id)">
                    <div class="flex items-center justify-between gap-2 rounded-lg px-2 py-1.5" :class="match.winner_participant_id === match.participant_b_id ? 'bg-semantic-success/10' : ''">
                      <p class="truncate text-body-sm font-semibold" :class="match.winner_participant_id === match.participant_b_id ? 'text-semantic-success' : 'text-ink'">
                        <Crown v-if="match.winner_participant_id === match.participant_b_id" :size="12" class="mr-1 inline" fill="currentColor" />
                        {{ participantById.get(match.participant_b_id)!.display_name }}
                      </p>
                      <CheckCircle2 v-if="match.result_b" :size="14" class="shrink-0 text-ink-tertiary" />
                    </div>
                  </template>
                  <div v-else class="rounded-lg border-2 border-dashed border-hairline-strong px-2 py-2.5 text-center text-caption text-ink-tertiary">Aguardando classificado</div>

                  <!-- Disputa -->
                  <div v-if="match.status === 'disputed'" class="mt-1 flex items-center gap-1.5 rounded-lg border border-semantic-error/20 bg-semantic-error/5 px-2.5 py-2 text-[11px] text-ink-subtle">
                    <ShieldAlert :size="13" class="shrink-0 text-semantic-error" />
                    Resultados divergentes — em mediação pela ArenaX1.
                  </div>

                  <!-- Reportar resultado -->
                  <div v-else-if="match.status === 'ready' && mySide(match) && !myResult(match)" class="mt-1 flex gap-2 border-t border-hairline pt-3">
                    <button
                      type="button"
                      @click="handleReport(match, 'win')"
                      :disabled="reportingMatchId === match.id"
                      class="flex-1 rounded-lg bg-semantic-success/15 px-2 py-2 text-caption font-bold text-semantic-success transition-colors hover:bg-semantic-success/25 disabled:cursor-wait disabled:opacity-60 flex items-center justify-center gap-1"
                    >
                      <CheckCircle2 :size="14" /> Eu venci
                    </button>
                    <button
                      type="button"
                      @click="handleReport(match, 'loss')"
                      :disabled="reportingMatchId === match.id"
                      class="flex-1 rounded-lg bg-surface-3 px-2 py-2 text-caption font-bold text-ink-subtle transition-colors hover:bg-surface-2 disabled:cursor-wait disabled:opacity-60 flex items-center justify-center gap-1"
                    >
                      <XCircle :size="14" /> Eu perdi
                    </button>
                  </div>
                  <p v-else-if="match.status === 'ready' && mySide(match) && myResult(match)" class="mt-1 border-t border-hairline pt-3 text-center text-caption text-ink-subtle">
                    Aguardando o oponente confirmar...
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Coluna Direita -->
        <div class="space-y-6">
          <!-- Detalhes de Pagamento -->
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
            <h3 class="mb-4 flex items-center gap-2 text-body-sm font-bold text-ink">
              <Landmark :size="16" class="text-primary" />
              Detalhes Financeiros
            </h3>
            <div class="space-y-3">
              <div class="flex items-center justify-between text-body-sm">
                <span class="text-ink-subtle">Taxa de inscrição</span>
                <span class="font-bold text-ink">R$ {{ tournament.entry_fee.toFixed(2) }}</span>
              </div>
              <div class="flex items-center justify-between text-body-sm">
                <span class="text-ink-subtle">Arrecadação total</span>
                <span class="font-medium text-ink">{{ tournament.max_players }} × R$ {{ tournament.entry_fee.toFixed(2) }}</span>
              </div>
              <hr class="border-hairline">
              <div class="flex items-center justify-between text-body-sm">
                <span class="text-ink-subtle">Premiação em jogo (após 10% de comissão da ArenaX1)</span>
                <span class="font-bold text-semantic-success">R$ {{ netPool.toFixed(2) }}</span>
              </div>
            </div>
            <div class="mt-4 rounded-lg border border-accent/20 bg-accent/10 p-3">
              <div class="flex items-start gap-2">
                <Lock :size="14" class="mt-0.5 text-accent" />
                <div>
                  <p class="text-caption font-bold text-accent">Custódia ArenaX1</p>
                  <p class="mt-1 text-[11px] leading-relaxed text-ink-subtle">As inscrições ficam retidas na sua carteira (saldo bloqueado) até o encerramento do torneio. Você pode desistir e reaver o valor a qualquer momento — <strong class="text-ink-subtle">exceto nos últimos 30 minutos antes do prazo de inscrição</strong>, quando a desistência é bloqueada pra ninguém sumir em cima da hora e travar o fechamento da chave pros outros.</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Ação -->
          <div v-if="tournament.status === 'registration_open'" class="rounded-2xl border border-hairline bg-surface-1/60 p-6 text-center backdrop-blur">
            <div class="mb-4 flex items-start gap-2 rounded-lg border border-hairline bg-surface-2 p-3 text-left">
              <Info :size="14" class="mt-0.5 shrink-0 text-accent" />
              <p class="text-[11px] leading-relaxed text-ink-subtle">Depois de entrar, você pode desistir e reaver o valor quando quiser — <strong class="text-ink-subtle">exceto nos últimos 30 minutos antes do prazo de inscrição</strong>, quando a desistência fica bloqueada pra ninguém sumir em cima da hora do fechamento da chave.</p>
            </div>
            <template v-if="!authStore.user">
              <router-link to="/register" class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 font-bold text-canvas shadow-glow-primary transition-all hover:bg-primary-hover no-underline">
                <UserPlus :size="20" />
                Criar conta para participar
              </router-link>
            </template>
            <template v-else-if="myParticipant">
              <p class="mb-3 flex items-center justify-center gap-1.5 text-body-sm font-semibold text-semantic-success"><CheckCircle2 :size="16" /> Você está inscrito</p>
              <button
                v-if="canLeave"
                type="button"
                @click="handleLeave"
                :disabled="leaving"
                class="flex w-full items-center justify-center gap-2 rounded-xl border border-hairline-strong bg-surface-2 px-4 py-3 font-bold text-ink-subtle transition-all hover:bg-surface-3 disabled:cursor-wait disabled:opacity-60"
              >
                <LogOut :size="18" />
                {{ leaving ? 'Cancelando...' : 'Cancelar inscrição (reembolso)' }}
              </button>
              <p v-else class="text-caption text-ink-tertiary">Faltam menos de 30 minutos para o fechamento — não é mais possível desistir com reembolso.</p>
            </template>
            <template v-else-if="tournament.participants.length >= tournament.max_players">
              <p class="text-body-sm font-semibold text-ink-subtle">Vagas esgotadas.</p>
            </template>
            <template v-else>
              <button
                type="button"
                @click="handleJoin"
                :disabled="joining"
                class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 font-bold text-canvas shadow-glow-primary transition-all hover:bg-primary-hover disabled:cursor-wait disabled:opacity-60"
              >
                <UserPlus :size="20" />
                {{ joining ? 'Inscrevendo...' : `Entrar (R$ ${tournament.entry_fee.toFixed(2)})` }}
              </button>
              <p class="mt-3 text-[10px] text-ink-tertiary">O valor é bloqueado na sua carteira agora.</p>
            </template>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
