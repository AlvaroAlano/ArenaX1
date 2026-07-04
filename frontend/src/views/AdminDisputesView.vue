<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ArrowLeft, ShieldAlert, CheckCircle2, RefreshCw } from '@lucide/vue'
import { useRouter } from 'vue-router'
import { api } from '@/services/api'

const router = useRouter()

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

const disputes = ref<OpenDispute[]>([])
const loading = ref(true)
const loadError = ref('')
const forbidden = ref(false)
const resolvingId = ref<string | null>(null)

const loadDisputes = async () => {
  loading.value = true
  loadError.value = ''
  forbidden.value = false
  try {
    disputes.value = await api.get<OpenDispute[]>('/api/admin/disputes')
  } catch (err: any) {
    if (err.message?.includes('restrito') || err.message?.includes('administrad')) {
      forbidden.value = true
    } else {
      loadError.value = err.message || 'Erro ao carregar as disputas.'
    }
  } finally {
    loading.value = false
  }
}
onMounted(loadDisputes)

const resolveDispute = async (d: OpenDispute, winner: 'a' | 'b') => {
  const winnerParticipant = winner === 'a' ? d.participant_a : d.participant_b
  if (!winnerParticipant) return
  if (!confirm(`Confirmar que ${winnerParticipant.display_name} venceu de verdade essa partida? O outro lado vai perder Fair Play Rating por ter mentido.`)) return

  resolvingId.value = d.dispute_id
  try {
    await api.post('/api/admin/tournaments/resolve-dispute', {
      match_id: d.match_id,
      winner_participant_id: winnerParticipant.id,
    })
    await loadDisputes()
  } catch (err: any) {
    alert(err.message || 'Erro ao resolver a disputa.')
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
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <button @click="router.push('/admin')" class="mb-2 flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle hover:text-primary transition-colors">
          <ArrowLeft :size="14" /> Voltar à visão geral
        </button>
        <span class="text-eyebrow uppercase tracking-widest text-accent">Portal de admin</span>
        <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Disputas de Torneio</h1>
        <p class="mt-1 text-body-sm text-ink-subtle">Analisa as provas fora daqui (prints/mensagens) e decide quem realmente venceu.</p>
      </div>
      <button @click="loadDisputes" :disabled="loading" class="inline-flex w-fit items-center gap-2 rounded-xl border border-hairline-strong bg-surface-1 px-4 py-2.5 text-body-sm font-semibold text-ink-subtle transition-colors hover:bg-surface-2 disabled:opacity-60">
        <RefreshCw :size="15" :class="loading ? 'animate-spin' : ''" /> Atualizar
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-24">
      <svg class="h-8 w-8 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </div>

    <div v-else-if="forbidden" class="flex flex-col items-center gap-3 py-24 text-center">
      <span class="grid size-14 place-items-center rounded-2xl bg-semantic-error/10 text-semantic-error"><ShieldAlert :size="26" /></span>
      <p class="font-semibold text-ink">Acesso restrito a administradores</p>
    </div>

    <div v-else-if="loadError" class="flex flex-col items-center gap-3 py-24 text-center">
      <p class="font-semibold text-semantic-error">{{ loadError }}</p>
      <button @click="loadDisputes" class="text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
    </div>

    <div v-else-if="disputes.length === 0" class="flex flex-col items-center gap-3 py-24 text-center">
      <span class="grid size-14 place-items-center rounded-2xl bg-semantic-success/10 text-semantic-success"><CheckCircle2 :size="26" /></span>
      <p class="font-semibold text-ink">Nenhuma disputa aberta</p>
      <p class="max-w-xs text-body-sm text-ink-subtle">Todas as partidas de torneio online estão com resultado confirmado por consenso.</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="d in disputes" :key="d.dispute_id" class="rounded-2xl border border-semantic-error/25 bg-semantic-error/[0.03] p-5">
        <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
          <div>
            <p class="font-bold text-ink">{{ d.tournament_title }}</p>
            <p class="text-caption text-ink-tertiary">Rodada {{ d.round }}</p>
          </div>
          <span class="text-caption text-ink-tertiary">{{ timeAgo(d.created_at) }}</span>
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
  </div>
</template>
