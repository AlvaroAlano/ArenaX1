<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ArrowLeft, ShieldAlert, CheckCircle2, RefreshCw, Swords, ChevronRight } from '@lucide/vue'
import { useRouter } from 'vue-router'
import { api } from '@/services/api'
import { useConfirmStore } from '@/stores/confirm'
import { useToastStore } from '@/stores/toast'

const router = useRouter()
const confirm = useConfirmStore()
const toast = useToastStore()

interface OpenDispute {
  dispute_id: string
  match_id: string
  tournament_id: string
  tournament_title: string
  round: number
  participant_a: { id: string; display_name: string; user_id: string | null } | null
  participant_b: { id: string; display_name: string; user_id: string | null } | null
  created_at: string
}

interface ChallengeDispute {
  dispute_id: string
  challenge_id: string
  status: string
  resolution: string | null
  created_at: string
  game: string
  platform: string
  bet_amount: number
  creator: { id: string; username?: string }
  opponent: { id: string; username?: string } | null
  creator_result: 'win' | 'loss' | null
  opponent_result: 'win' | 'loss' | null
  reason: string | null
}

const disputes = ref<OpenDispute[]>([])
const loading = ref(true)
const loadError = ref('')
const forbidden = ref(false)
const isMockData = ref(false)
const resolvingId = ref<string | null>(null)

const challengeDisputes = ref<ChallengeDispute[]>([])
const challengeDisputesLoading = ref(true)

// Exemplo pra visualizar a tela enquanto o backend não tem disputa real
// (ou está fora do ar) — só entra se a chamada falhar por outro motivo
// que não seja "sem permissão de admin".
const MOCK_DISPUTES: OpenDispute[] = [
  {
    dispute_id: 'mock-1',
    match_id: 'mock-match-1',
    tournament_id: 'mock-tournament-1',
    tournament_title: 'Torneio Relâmpago EA FC 26',
    round: 2,
    participant_a: { id: 'mock-pa-1', display_name: 'Lucas_Craque10', user_id: null },
    participant_b: { id: 'mock-pb-1', display_name: 'RivaldoZK', user_id: null },
    created_at: new Date(Date.now() - 45 * 60_000).toISOString(),
  },
]

const loadDisputes = async () => {
  loading.value = true
  loadError.value = ''
  forbidden.value = false
  isMockData.value = false
  try {
    disputes.value = await api.get<OpenDispute[]>('/api/admin/disputes')
  } catch (err: any) {
    if (err.message?.includes('restrito') || err.message?.includes('administrad')) {
      forbidden.value = true
    } else {
      disputes.value = MOCK_DISPUTES
      isMockData.value = true
    }
  } finally {
    loading.value = false
  }
}

const loadChallengeDisputes = async () => {
  challengeDisputesLoading.value = true
  try {
    challengeDisputes.value = await api.get<ChallengeDispute[]>('/api/admin/challenge-disputes?status=open')
  } catch {
    challengeDisputes.value = []
  } finally {
    challengeDisputesLoading.value = false
  }
}

onMounted(() => {
  loadDisputes()
  loadChallengeDisputes()
})

const openChallengeDispute = (d: ChallengeDispute) => {
  router.push(`/admin/disputes/${d.challenge_id}`)
}

const resolveDispute = async (d: OpenDispute, winner: 'a' | 'b') => {
  const winnerParticipant = winner === 'a' ? d.participant_a : d.participant_b
  if (!winnerParticipant) return
  if (!(await confirm.ask({
    title: 'Definir vencedor',
    message: `Confirmar que ${winnerParticipant.display_name} venceu de verdade essa partida? O outro lado vai perder Fair Play Rating por ter mentido.`,
    confirmText: 'Confirmar vencedor',
    tone: 'danger',
  }))) return

  if (isMockData.value) {
    disputes.value = disputes.value.filter((item) => item.dispute_id !== d.dispute_id)
    return
  }

  resolvingId.value = d.dispute_id
  try {
    await api.post('/api/admin/tournaments/resolve-dispute', {
      match_id: d.match_id,
      winner_participant_id: winnerParticipant.id,
    })
    await loadDisputes()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao resolver a disputa.', 'error')
  } finally {
    resolvingId.value = null
  }
}

function timeAgo(iso: string): string {
  const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60_000)
  if (mins < 1) return 'Agora mesmo'
  if (mins < 60) return `Há ${mins} min`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return hours === 1 ? 'Há 1 hora' : `Há ${hours} horas`
  const days = Math.floor(hours / 24)
  return days === 1 ? 'Ontem' : `Há ${days} dias`
}

const fmtDateTime = (iso: string) => new Date(iso).toLocaleString('pt-BR', {
  day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
})

const resultLabel = (r: 'win' | 'loss' | null) => r === 'win' ? 'Reportou vitória' : r === 'loss' ? 'Reportou derrota' : 'Não reportou'
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-10">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <button @click="router.push('/admin')" class="mb-2 flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle hover:text-primary transition-colors">
          <ArrowLeft :size="14" /> Voltar à visão geral
        </button>
        <span class="text-eyebrow uppercase tracking-widest text-accent">Portal de admin</span>
        <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Disputas</h1>
        <p class="mt-1 text-body-sm text-ink-subtle">Desafios 1v1 e partidas de torneio com resultado divergente — clique numa disputa pra analisar as provas e decidir.</p>
      </div>
      <button @click="loadDisputes(); loadChallengeDisputes()" :disabled="loading || challengeDisputesLoading" class="inline-flex w-fit items-center gap-2 rounded-xl border border-hairline-strong bg-surface-1 px-4 py-2.5 text-body-sm font-semibold text-ink-subtle transition-colors hover:bg-surface-2 disabled:opacity-60">
        <RefreshCw :size="15" :class="(loading || challengeDisputesLoading) ? 'animate-spin' : ''" /> Atualizar
      </button>
    </div>

    <!-- ══════ Desafios 1v1 ══════ -->
    <section class="space-y-4">
      <h2 class="flex items-center gap-2 font-display text-card-title font-bold text-ink">
        <Swords :size="18" class="text-primary" /> Desafios 1v1
      </h2>

      <div v-if="challengeDisputesLoading" class="flex items-center justify-center py-12">
        <svg class="h-6 w-6 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>

      <div v-else-if="challengeDisputes.length === 0" class="flex flex-col items-center gap-2 rounded-2xl border border-dashed border-hairline-strong bg-surface-1/60 py-12 text-center">
        <CheckCircle2 :size="24" class="text-semantic-success" />
        <p class="text-body-sm font-semibold text-ink">Nenhuma disputa de desafio aberta</p>
      </div>

      <div v-else class="space-y-3">
        <button
          v-for="d in challengeDisputes"
          :key="d.dispute_id"
          type="button"
          @click="openChallengeDispute(d)"
          class="group w-full rounded-2xl border border-semantic-error/25 bg-semantic-error/[0.03] p-5 text-left transition-colors hover:bg-semantic-error/[0.07]"
        >
          <div class="mb-3 flex flex-wrap items-start justify-between gap-2">
            <div>
              <p class="font-bold text-ink">{{ d.game }} · {{ d.platform }} · R$ {{ Number(d.bet_amount).toFixed(2) }}</p>
              <p class="text-caption text-ink-tertiary">{{ d.creator.username || '?' }} vs {{ d.opponent?.username || '?' }}</p>
            </div>
            <div class="flex items-center gap-2 text-right">
              <div>
                <p class="text-caption font-semibold text-ink-subtle">{{ fmtDateTime(d.created_at) }}</p>
                <p class="text-caption text-ink-tertiary">{{ timeAgo(d.created_at) }}</p>
              </div>
              <ChevronRight :size="18" class="shrink-0 text-ink-tertiary transition-transform group-hover:translate-x-0.5" />
            </div>
          </div>

          <div class="mb-3 grid gap-2 sm:grid-cols-2">
            <div class="rounded-lg border border-hairline bg-surface-2 px-3 py-2 text-body-sm">
              <span class="font-semibold text-ink">{{ d.creator.username || '?' }}</span>
              <span class="ml-2 text-caption" :class="d.creator_result === 'win' ? 'text-semantic-success' : 'text-ink-tertiary'">{{ resultLabel(d.creator_result) }}</span>
            </div>
            <div class="rounded-lg border border-hairline bg-surface-2 px-3 py-2 text-body-sm">
              <span class="font-semibold text-ink">{{ d.opponent?.username || '?' }}</span>
              <span class="ml-2 text-caption" :class="d.opponent_result === 'win' ? 'text-semantic-success' : 'text-ink-tertiary'">{{ resultLabel(d.opponent_result) }}</span>
            </div>
          </div>

          <p v-if="d.reason" class="line-clamp-2 rounded-lg bg-surface-2 px-3 py-2.5 text-body-sm text-ink-subtle">
            <span class="font-semibold text-ink-tertiary">Motivo relatado: </span>{{ d.reason }}
          </p>

          <span class="mt-3 inline-flex items-center gap-1.5 text-caption font-bold uppercase tracking-wide text-primary">
            Analisar disputa <ChevronRight :size="13" />
          </span>
        </button>
      </div>
    </section>

    <!-- ══════ Torneios ══════ -->
    <section class="space-y-4">
      <h2 class="flex items-center gap-2 font-display text-card-title font-bold text-ink">
        <ShieldAlert :size="18" class="text-primary" /> Torneios
      </h2>

      <div v-if="loading" class="flex items-center justify-center py-12">
        <svg class="h-6 w-6 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>

      <div v-else-if="forbidden" class="flex flex-col items-center gap-3 py-24 text-center">
        <span class="grid size-14 place-items-center rounded-2xl bg-semantic-error/10 text-semantic-error"><ShieldAlert :size="26" /></span>
        <p class="font-semibold text-ink">Acesso restrito a administradores</p>
      </div>

      <div v-else-if="loadError" class="flex flex-col items-center gap-3 py-12 text-center">
        <p class="font-semibold text-semantic-error">{{ loadError }}</p>
        <button @click="loadDisputes" class="text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
      </div>

      <div v-else-if="disputes.length === 0" class="flex flex-col items-center gap-2 rounded-2xl border border-dashed border-hairline-strong bg-surface-1/60 py-12 text-center">
        <CheckCircle2 :size="24" class="text-semantic-success" />
        <p class="text-body-sm font-semibold text-ink">Nenhuma disputa de torneio aberta</p>
      </div>

      <div v-else class="space-y-3">
        <div v-if="isMockData" class="flex items-center gap-2.5 rounded-xl border border-accent/25 bg-accent/[0.06] px-4 py-3 text-body-sm text-accent">
          <ShieldAlert :size="16" class="shrink-0" />
          Não foi possível falar com o backend — exibindo uma disputa de exemplo, não é real.
        </div>
        <div v-for="d in disputes" :key="d.dispute_id" class="rounded-2xl border border-semantic-error/25 bg-semantic-error/[0.03] p-5">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
            <div>
              <p class="font-bold text-ink">{{ d.tournament_title }}</p>
              <p class="text-caption text-ink-tertiary">Rodada {{ d.round }}</p>
            </div>
            <div class="text-right">
              <p class="text-caption font-semibold text-ink-subtle">{{ fmtDateTime(d.created_at) }}</p>
              <p class="text-caption text-ink-tertiary">{{ timeAgo(d.created_at) }}</p>
            </div>
          </div>
          <div class="flex flex-col gap-2 sm:flex-row">
            <button
              type="button"
              @click="resolveDispute(d, 'a')"
              :disabled="resolvingId === d.dispute_id || !d.participant_a"
              class="flex-1 rounded-lg border border-semantic-success/30 bg-semantic-success/10 px-3 py-3 text-body-sm font-semibold text-semantic-success transition-colors hover:bg-semantic-success/20 disabled:cursor-wait disabled:opacity-60"
            >
              {{ d.participant_a?.display_name || '—' }} venceu de verdade
            </button>
            <button
              type="button"
              @click="resolveDispute(d, 'b')"
              :disabled="resolvingId === d.dispute_id || !d.participant_b"
              class="flex-1 rounded-lg border border-semantic-success/30 bg-semantic-success/10 px-3 py-3 text-body-sm font-semibold text-semantic-success transition-colors hover:bg-semantic-success/20 disabled:cursor-wait disabled:opacity-60"
            >
              {{ d.participant_b?.display_name || '—' }} venceu de verdade
            </button>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
