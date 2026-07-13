<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useConfirmStore } from '@/stores/confirm'
import { api } from '@/services/api'
import DisputeChat from '@/components/DisputeChat.vue'
import MatchChat from '@/components/MatchChat.vue'
import { vReveal } from '@/composables/useReveal'
import {
  ArrowLeft,
  Gamepad2,
  Star,
  Trophy,
  ShieldAlert,
  PlayCircle,
  Clock,
  Hourglass,
  UserPlus,
  XCircle,
  Check,
  X,
  Users,
  Flag,
  Lock,
  AlertTriangle,
} from '@lucide/vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const toast = useToastStore()
const confirm = useConfirmStore()

const challengeId = route.params.id as string
const challenge = ref<any>(null)
const loading = ref(true)
const reporting = ref<'win' | 'loss' | null>(null)
const markingReady = ref(false)
let realtimeSub: any = null

// "Agora" reativo pra os contadores de prazo tiquetaquearem.
const now = ref(Date.now())
let clockTimer: ReturnType<typeof setInterval> | null = null

const fetchChallenge = async () => {
  try {
    const { data, error } = await supabase
      .from('challenges')
      .select('*, creator_profile:creator_id(username, fair_play_rating), opponent_profile:opponent_id(username, fair_play_rating), join_requests:challenge_join_requests(id, requester_id, status, created_at, requester:requester_id(username, fair_play_rating))')
      .eq('id', challengeId)
      .single()

    if (error) throw error
    challenge.value = data
  } catch (err) {
    console.error('Erro ao buscar desafio:', err)
    router.push('/challenges')
  } finally {
    loading.value = false
  }
}

/* ── RLS de challenge_join_requests só devolve linhas pro criador (todas) ou
   pro próprio solicitante (a sua) — quem não é nenhum dos dois recebe uma
   lista vazia no embed acima, sem precisar filtrar nada aqui. ── */
const pendingRequests = computed(() => (challenge.value?.join_requests || []).filter((r: any) => r.status === 'pending'))

const setupRealtime = () => {
  realtimeSub = supabase
    .channel(`match-${challengeId}`)
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'challenges', filter: `id=eq.${challengeId}` },
      () => fetchChallenge()
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'challenge_join_requests', filter: `challenge_id=eq.${challengeId}` },
      () => fetchChallenge()
    )
    .subscribe()
}

onMounted(() => {
  fetchChallenge()
  setupRealtime()
  clockTimer = setInterval(() => { now.value = Date.now() }, 1000)
})

onUnmounted(() => {
  if (realtimeSub) supabase.removeChannel(realtimeSub)
  if (clockTimer) clearInterval(clockTimer)
})

const isCreator = computed(() => challenge.value?.creator_id === authStore.user?.id)
const isOpponent = computed(() => challenge.value?.opponent_id === authStore.user?.id)
const isParticipant = computed(() => isCreator.value || isOpponent.value)

const myResult = computed(() => isCreator.value ? challenge.value?.creator_result : challenge.value?.opponent_result)

/* ── Checkpoint "Iniciar partida" (status 'accepted'): os dois confirmam
   presença antes da partida virar in_progress. ── */
const myReady = computed(() => isCreator.value ? challenge.value?.creator_ready : challenge.value?.opponent_ready)
const oppReady = computed(() => isCreator.value ? challenge.value?.opponent_ready : challenge.value?.creator_ready)

// Contagem regressiva pra um prazo ISO; usa o `now` reativo. Null se sem prazo.
const countdown = (iso?: string | null): string | null => {
  if (!iso) return null
  const ms = new Date(iso).getTime() - now.value
  if (ms <= 0) return 'expirado'
  const totalMin = Math.floor(ms / 60000)
  const h = Math.floor(totalMin / 60)
  const m = totalMin % 60
  if (h >= 1) return `${h}h ${m}min`
  const s = Math.floor((ms % 60000) / 1000)
  return `${m}min ${s}s`
}
const startCountdown = computed(() => countdown(challenge.value?.start_deadline))
const reportCountdown = computed(() => countdown(challenge.value?.report_deadline))

const handleMarkReady = async () => {
  markingReady.value = true
  try {
    await api.post('/api/challenges/mark-ready', { challenge_id: challengeId })
    await fetchChallenge()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao confirmar presença.', 'error')
  } finally {
    markingReady.value = false
  }
}

/* ── Retenção do prêmio + contestação reativa. Quando o resultado é aceito por
   timeout, o prêmio fica retido 3 dias (settlement_release_at) e o perdedor
   pode contestar nesse prazo. ── */
const iWon = computed(() => challenge.value?.winner_id === authStore.user?.id)
const isHeld = computed(() =>
  challenge.value?.status === 'completed'
  && challenge.value?.settlement_release_at
  && new Date(challenge.value.settlement_release_at).getTime() > now.value
)
const holdCountdown = computed(() => countdown(challenge.value?.settlement_release_at))
const canContest = computed(() => isHeld.value && isParticipant.value && !iWon.value)

/* Motivos estruturados (item 5). Roteamento no backend: má conduta/trapaça/
   outro → mediação de admin; o resto entra como contestação/registro. */
const DISPUTE_REASONS = [
  'Resultado reportado incorretamente / trapaça',
  'Não iniciou a partida / não apareceu',
  'Abandonou no meio da partida',
  'Comportamento inadequado (xingamento/assédio)',
  'Outro',
]
const showDisputeModal = ref(false)
const disputeReason = ref(DISPUTE_REASONS[0])
const disputeDetails = ref('')
const disputing = ref(false)
const disputeError = ref('')

const openDispute = (presetReason?: string) => {
  disputeReason.value = presetReason || DISPUTE_REASONS[0]
  disputeDetails.value = ''
  disputeError.value = ''
  showDisputeModal.value = true
}

const submitDispute = async () => {
  if (disputing.value) return
  disputing.value = true
  disputeError.value = ''
  try {
    await api.post('/api/challenges/open-dispute', {
      challenge_id: challengeId,
      reason: disputeReason.value,
      details: disputeDetails.value.trim() || null,
    })
    showDisputeModal.value = false
    await fetchChallenge()
  } catch (err: any) {
    disputeError.value = err.message || 'Não foi possível abrir a contestação.'
  } finally {
    disputing.value = false
  }
}

const handleReport = async (result: 'win' | 'loss') => {
  if (!(await confirm.ask({
    title: `Reportar ${result === 'win' ? 'vitória' : 'derrota'}`,
    message: `Tem certeza que deseja reportar ${result === 'win' ? 'VITÓRIA' : 'DERROTA'}? Isso é irreversível e declarações falsas podem resultar em banimento.`,
    confirmText: result === 'win' ? 'Reportar vitória' : 'Reportar derrota',
    tone: 'danger',
  }))) {
    return
  }

  reporting.value = result
  try {
    const resData = await api.post<{ message: string }>('/api/challenges/report', {
      challenge_id: challengeId,
      result: result
    })
    await fetchChallenge()
    if (resData.message) toast.push(resData.message, 'success')
  } catch (err: any) {
    toast.push(err.message || 'Erro ao reportar resultado.', 'error')
  } finally {
    reporting.value = null
  }
}

const respondingRequestId = ref<string | null>(null)

const handleAcceptRequest = async (r: any) => {
  if (!(await confirm.ask({
    title: 'Aceitar oponente',
    message: `Aceitar ${r.requester?.username} pra esse desafio de R$ ${challenge.value?.bet_amount.toFixed(2)}?`,
    confirmText: 'Aceitar',
  }))) return

  respondingRequestId.value = r.id
  try {
    await api.post('/api/challenges/accept-join-request', { request_id: r.id })
    await fetchChallenge()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao aceitar solicitação.', 'error')
  } finally {
    respondingRequestId.value = null
  }
}

const handleRejectRequest = async (r: any) => {
  respondingRequestId.value = r.id
  try {
    await api.post('/api/challenges/reject-join-request', { request_id: r.id })
    await fetchChallenge()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao recusar solicitação.', 'error')
  } finally {
    respondingRequestId.value = null
  }
}

/* ── Mesmo cálculo usado em ChallengesView pra tempo relativo — duplicado
   de propósito (mesma decisão já tomada pro mapeamento de cor por
   plataforma logo abaixo: componente pequeno, não vale criar um util só
   pra isso). ── */
const timeAgo = (iso: string): string => {
  const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60_000)
  if (mins < 1) return 'Agora mesmo'
  if (mins < 60) return `Há ${mins} min`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return hours === 1 ? 'Há 1 hora' : `Há ${hours} horas`
  const days = Math.floor(hours / 24)
  return days === 1 ? 'Ontem' : `Há ${days} dias`
}

/* ── Mesmo mapeamento de cor por plataforma usado em ChallengesView, pra
   o avatar do jogador ter o mesmo anel de cor em qualquer tela. ── */
const platformColor: Record<string, string> = {
  PS5: '#00439C', Xbox: '#107C10', PC: '#52525b', Crossplay: '#8b5cf6',
}
const ringStyle = computed(() => ({
  boxShadow: `0 0 0 3px var(--canvas), 0 0 0 5px ${platformColor[challenge.value?.platform] || '#52525b'}`,
}))
const initials = (name?: string) => (name || '??').substring(0, 2).toUpperCase()

/* ── Prêmio ao vencedor: mesma regra do backend (rake 8% no desafio 1v1,
   ver 18_rake_minimums_and_wording.sql), já usada em ChallengesView —
   bet_amount * 1.84. ── */
const totalPrize = computed(() => (challenge.value?.bet_amount ?? 0) * 1.84)
const netProfit = computed(() => (challenge.value?.bet_amount ?? 0) * 0.84)
const winnerName = computed(() => {
  if (!challenge.value) return ''
  if (challenge.value.winner_id === challenge.value.creator_id) return challenge.value.creator_profile?.username
  return challenge.value.opponent_profile?.username
})

type Status = 'open' | 'accepted' | 'in_progress' | 'completed' | 'disputed' | 'cancelled'
const statusMeta: Record<Status, { label: string; icon: any; dot: string; text: string; bg: string; border: string }> = {
  open: { label: 'Aguardando oponente', icon: UserPlus, dot: 'bg-ink-tertiary', text: 'text-ink-subtle', bg: 'bg-surface-2', border: 'border-hairline' },
  accepted: { label: 'Confirmação de presença', icon: Hourglass, dot: 'bg-amber-400', text: 'text-amber-400', bg: 'bg-amber-400/10', border: 'border-amber-400/25' },
  in_progress: { label: 'Partida em andamento', icon: PlayCircle, dot: 'bg-accent', text: 'text-accent', bg: 'bg-accent/10', border: 'border-accent/25' },
  completed: { label: 'Partida concluída', icon: Trophy, dot: 'bg-semantic-success', text: 'text-semantic-success', bg: 'bg-semantic-success/10', border: 'border-semantic-success/25' },
  disputed: { label: 'Em disputa — mediação necessária', icon: ShieldAlert, dot: 'bg-semantic-error', text: 'text-semantic-error', bg: 'bg-semantic-error/10', border: 'border-semantic-error/25' },
  cancelled: { label: 'Desafio cancelado', icon: XCircle, dot: 'bg-ink-tertiary', text: 'text-ink-subtle', bg: 'bg-surface-2', border: 'border-hairline' },
}
const currentStatus = computed(() => statusMeta[challenge.value?.status as Status] ?? statusMeta.open)
</script>

<template>
  <div class="mx-auto w-full max-w-3xl space-y-6 px-6 py-8 lg:px-10">

    <div v-if="loading" class="flex items-center justify-center py-24">
      <svg class="h-8 w-8 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </div>

    <template v-else-if="challenge">
      <router-link to="/challenges" class="inline-flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle no-underline transition-colors hover:text-primary">
        <ArrowLeft :size="14" />
        Voltar aos desafios
      </router-link>

      <!-- Hero: status + jogo + pote -->
      <div
        v-reveal
        class="relative overflow-hidden rounded-2xl border p-6 sm:p-8"
        :class="challenge.status === 'in_progress' ? 'border-primary/25 bg-gradient-to-br from-primary/[0.14] via-surface-2 to-surface-1 shadow-glow-primary' : 'border-hairline bg-surface-1'"
      >
        <div class="pointer-events-none absolute -bottom-8 -right-8 size-48 rounded-full bg-primary/10 blur-3xl"></div>
        <div class="relative z-10 flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <span
              class="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider"
              :class="[currentStatus.bg, currentStatus.text, currentStatus.border]"
            >
              <span class="relative flex size-1.5">
                <span v-if="challenge.status === 'in_progress'" class="absolute inline-flex size-full animate-ping rounded-full opacity-75" :class="currentStatus.dot"></span>
                <span class="relative inline-flex size-1.5 rounded-full" :class="currentStatus.dot"></span>
              </span>
              {{ currentStatus.label }}
            </span>
            <h1 class="mt-2.5 font-display text-headline font-black uppercase tracking-tight text-ink">{{ challenge.game }}</h1>
            <p class="mt-1 flex items-center gap-1.5 text-body-sm text-ink-subtle">
              <Gamepad2 :size="14" /> {{ challenge.platform }} · 1v1
            </p>
          </div>
          <div class="flex shrink-0 flex-col items-center rounded-xl border border-hairline bg-surface-2 px-6 py-4 backdrop-blur">
            <span class="font-display text-2xl font-black tabular-nums text-primary">R$ {{ totalPrize.toFixed(2) }}</span>
            <span class="mt-1 text-[10px] uppercase tracking-wider text-ink-subtle">Prêmio ao vencedor</span>
          </div>
        </div>
      </div>

      <!-- Confronto -->
      <div v-reveal="'80ms'" class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur sm:p-8">
        <div class="grid grid-cols-[1fr_auto_1fr] items-start gap-3 sm:gap-6">
          <!-- Criador -->
          <div class="flex flex-col items-center gap-2 text-center">
            <div
              class="grid size-16 place-items-center rounded-full bg-primary/15 text-xl font-bold uppercase text-primary sm:size-20 sm:text-2xl"
              :style="ringStyle"
            >{{ initials(challenge.creator_profile?.username) }}</div>
            <div class="min-w-0">
              <h2 class="truncate font-display text-body-lg font-bold text-ink">{{ challenge.creator_profile?.username }}</h2>
              <span class="inline-flex items-center gap-0.5 text-[11px] font-semibold text-amber-500">
                <Star :size="11" fill="currentColor" />{{ (challenge.creator_profile?.fair_play_rating ?? 5).toFixed(1) }}
              </span>
            </div>
            <span
              v-if="challenge.creator_result"
              class="rounded-full border px-2.5 py-1 text-[10px] font-bold uppercase tracking-wide"
              :class="challenge.creator_result === 'win' ? 'border-semantic-success/25 bg-semantic-success/10 text-semantic-success' : 'border-hairline-strong bg-surface-2 text-ink-tertiary'"
            >
              Reportou {{ challenge.creator_result === 'win' ? 'vitória' : 'derrota' }}
            </span>
          </div>

          <span class="mt-5 grid size-9 shrink-0 place-items-center rounded-full border border-hairline-strong bg-surface-2 text-[11px] font-black text-ink-tertiary sm:mt-7">VS</span>

          <!-- Oponente -->
          <div v-if="challenge.opponent_profile" class="flex flex-col items-center gap-2 text-center">
            <div
              class="grid size-16 place-items-center rounded-full bg-primary/15 text-xl font-bold uppercase text-primary sm:size-20 sm:text-2xl"
              :style="ringStyle"
            >{{ initials(challenge.opponent_profile?.username) }}</div>
            <div class="min-w-0">
              <h2 class="truncate font-display text-body-lg font-bold text-ink">{{ challenge.opponent_profile?.username }}</h2>
              <span class="inline-flex items-center gap-0.5 text-[11px] font-semibold text-amber-500">
                <Star :size="11" fill="currentColor" />{{ (challenge.opponent_profile?.fair_play_rating ?? 5).toFixed(1) }}
              </span>
            </div>
            <span
              v-if="challenge.opponent_result"
              class="rounded-full border px-2.5 py-1 text-[10px] font-bold uppercase tracking-wide"
              :class="challenge.opponent_result === 'win' ? 'border-semantic-success/25 bg-semantic-success/10 text-semantic-success' : 'border-hairline-strong bg-surface-2 text-ink-tertiary'"
            >
              Reportou {{ challenge.opponent_result === 'win' ? 'vitória' : 'derrota' }}
            </span>
          </div>
          <div v-else class="flex flex-col items-center gap-2 text-center text-ink-tertiary">
            <div class="grid size-16 place-items-center rounded-full border-2 border-dashed border-hairline-strong sm:size-20">
              <UserPlus :size="22" />
            </div>
            <span class="text-body-sm font-medium">Aguardando...</span>
          </div>
        </div>
      </div>

      <!-- Solicitações pra entrar: só o criador vê e decide (RLS já garante
           que pendingRequests só vem populado pra ele, mas o v-if evita
           mostrar a seção vazia pra qualquer outro visitante). -->
      <div
        v-if="isCreator && challenge.status === 'open' && pendingRequests.length > 0"
        v-reveal="'100ms'"
        class="rounded-2xl border border-hairline bg-surface-1 p-6 sm:p-8"
      >
        <h3 class="flex items-center gap-2 font-display text-card-title font-bold uppercase tracking-tight text-ink">
          <Users :size="18" class="text-accent" />
          Quem quer jogar
        </h3>
        <p class="mt-1 text-body-sm text-ink-subtle">Escolha um adversário — os outros pedidos são recusados automaticamente.</p>

        <ul class="mt-5 space-y-2">
          <li
            v-for="r in pendingRequests"
            :key="r.id"
            class="flex items-center justify-between gap-3 rounded-xl border border-hairline bg-surface-2 p-3"
          >
            <router-link
              :to="{ name: 'profile', params: { username: r.requester?.username } }"
              class="flex min-w-0 items-center gap-3 text-left no-underline"
            >
              <div class="grid size-10 shrink-0 place-items-center rounded-full bg-primary/15 text-sm font-bold uppercase text-primary">
                {{ initials(r.requester?.username) }}
              </div>
              <div class="min-w-0">
                <p class="truncate text-body-sm font-semibold text-ink hover:text-primary">{{ r.requester?.username }}</p>
                <p class="flex items-center gap-2 text-caption text-ink-tertiary">
                  <span class="inline-flex items-center gap-0.5 font-semibold text-amber-500">
                    <Star :size="10" fill="currentColor" />{{ (r.requester?.fair_play_rating ?? 5).toFixed(1) }}
                  </span>
                  · {{ timeAgo(r.created_at) }}
                </p>
              </div>
            </router-link>
            <div class="flex shrink-0 items-center gap-2">
              <button
                type="button"
                @click="handleRejectRequest(r)"
                :disabled="respondingRequestId === r.id"
                class="grid size-9 place-items-center rounded-lg border border-hairline-strong text-ink-tertiary transition-colors hover:border-semantic-error/40 hover:bg-semantic-error/10 hover:text-semantic-error disabled:cursor-wait disabled:opacity-60"
                title="Recusar"
              >
                <X :size="16" />
              </button>
              <button
                type="button"
                @click="handleAcceptRequest(r)"
                :disabled="respondingRequestId === r.id"
                class="grid size-9 place-items-center rounded-lg bg-accent text-canvas transition-colors hover:brightness-110 disabled:cursor-wait disabled:opacity-60"
                title="Aceitar"
              >
                <svg v-if="respondingRequestId === r.id" class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                </svg>
                <Check v-else :size="16" />
              </button>
            </div>
          </li>
        </ul>
      </div>

      <!-- Confirmar presença ("Iniciar partida") -->
      <div v-if="challenge.status === 'accepted' && isParticipant" v-reveal="'140ms'" class="rounded-2xl border border-amber-400/25 bg-amber-400/[0.06] p-6 text-center sm:p-8">
        <Hourglass :size="28" class="mx-auto text-amber-400" />
        <h3 class="mt-3 font-display text-card-title font-bold uppercase tracking-tight text-ink">Confirmem presença</h3>
        <p class="mx-auto mt-1.5 max-w-md text-body-sm text-ink-subtle">
          Os dois precisam confirmar que estão prontos pra começar. Se ninguém confirmar
          <span v-if="startCountdown && startCountdown !== 'expirado'"> em <strong class="text-amber-400">{{ startCountdown }}</strong></span>
          <span v-else> a tempo</span>, a partida é cancelada e o saldo devolvido aos dois.
        </p>

        <div class="mx-auto mt-5 flex max-w-xs flex-col gap-3">
          <div class="flex items-center justify-between rounded-lg border border-hairline bg-surface-2 px-4 py-2.5 text-body-sm">
            <span class="text-ink-subtle">Você</span>
            <span v-if="myReady" class="inline-flex items-center gap-1 font-bold text-semantic-success"><Check :size="14" /> Pronto</span>
            <span v-else class="font-semibold text-ink-tertiary">Aguardando</span>
          </div>
          <div class="flex items-center justify-between rounded-lg border border-hairline bg-surface-2 px-4 py-2.5 text-body-sm">
            <span class="text-ink-subtle">Oponente</span>
            <span v-if="oppReady" class="inline-flex items-center gap-1 font-bold text-semantic-success"><Check :size="14" /> Pronto</span>
            <span v-else class="font-semibold text-ink-tertiary">Aguardando</span>
          </div>
        </div>

        <button
          v-if="!myReady"
          type="button"
          @click="handleMarkReady"
          :disabled="markingReady"
          class="mx-auto mt-6 flex items-center justify-center gap-2 rounded-xl bg-accent px-8 py-4 text-button font-bold text-canvas transition-all hover:brightness-110 disabled:cursor-wait disabled:opacity-60"
        >
          <svg v-if="markingReady" class="h-5 w-5 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
          </svg>
          <PlayCircle v-else :size="18" />
          Iniciar partida
        </button>
        <p v-else class="mt-6 text-body-sm font-medium text-ink-subtle">Você já confirmou. Aguardando o oponente...</p>
      </div>

      <!-- Reportar resultado -->
      <div v-if="challenge.status === 'in_progress' && isParticipant" v-reveal="'140ms'" class="rounded-2xl border border-hairline bg-surface-1 p-6 text-center sm:p-8">
        <p v-if="reportCountdown && !myResult" class="mb-4 inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-2 px-3 py-1 text-caption font-semibold text-ink-subtle">
          <Clock :size="13" /> Prazo pra reportar: <span class="text-ink">{{ reportCountdown }}</span>
        </p>
        <template v-if="myResult">
          <Hourglass :size="28" class="mx-auto text-accent" />
          <h3 class="mt-3 text-body-lg font-bold text-ink">Resultado registrado!</h3>
          <p class="mt-1 text-body-sm text-ink-subtle">Aguardando o oponente confirmar pra liberar o pote.</p>
        </template>
        <template v-else>
          <h3 class="font-display text-card-title font-bold uppercase tracking-tight text-ink">Reportar resultado</h3>
          <p class="mx-auto mt-1.5 max-w-md text-body-sm text-ink-subtle">
            A partida terminou? Seja honesto — reportes falsos reduzem seu Fair Play e levam ao banimento.
          </p>
          <div class="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
            <button
              type="button"
              @click="handleReport('win')"
              :disabled="reporting !== null"
              class="flex flex-1 items-center justify-center gap-2 rounded-xl bg-semantic-success py-4 text-button font-bold text-white transition-all hover:brightness-110 disabled:cursor-wait disabled:opacity-60 sm:max-w-[220px]"
            >
              <svg v-if="reporting === 'win'" class="h-5 w-5 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
              </svg>
              <Trophy v-else :size="18" />
              Eu venci
            </button>
            <button
              type="button"
              @click="handleReport('loss')"
              :disabled="reporting !== null"
              class="flex flex-1 items-center justify-center gap-2 rounded-xl border border-hairline-strong bg-surface-2 py-4 text-button font-bold text-ink-subtle transition-all hover:border-semantic-error/40 hover:bg-semantic-error/10 hover:text-semantic-error disabled:cursor-wait disabled:opacity-60 sm:max-w-[220px]"
            >
              <svg v-if="reporting === 'loss'" class="h-5 w-5 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
              </svg>
              <XCircle v-else :size="18" />
              Eu perdi
            </button>
          </div>
        </template>

        <!-- Reportar problema (má conduta, trapaça, no-show) -->
        <button
          type="button"
          @click="openDispute()"
          class="mx-auto mt-5 inline-flex items-center gap-1.5 text-caption font-semibold text-ink-tertiary transition-colors hover:text-semantic-error"
        >
          <Flag :size="13" /> Reportar um problema
        </button>
      </div>

      <!-- Prêmio retido / contestação (resultado aceito automático) -->
      <div v-if="isHeld" v-reveal="'140ms'" class="rounded-2xl border p-6 text-center sm:p-8" :class="iWon ? 'border-amber-400/25 bg-amber-400/[0.06]' : 'border-hairline bg-surface-1'">
        <Lock :size="26" class="mx-auto" :class="iWon ? 'text-amber-400' : 'text-ink-subtle'" />
        <template v-if="iWon">
          <h3 class="mt-3 text-body-lg font-bold text-ink">Prêmio retido</h3>
          <p class="mx-auto mt-1.5 max-w-md text-body-sm text-ink-subtle">
            Seu resultado foi aceito porque o oponente não respondeu. O prêmio de
            <strong class="text-ink">R$ {{ netProfit.toFixed(2) }}</strong> libera pra saque em
            <strong class="text-amber-400">{{ holdCountdown }}</strong> — a janela pra ele contestar.
          </p>
        </template>
        <template v-else>
          <h3 class="mt-3 text-body-lg font-bold text-ink">Resultado aceito</h3>
          <p class="mx-auto mt-1.5 max-w-md text-body-sm text-ink-subtle">
            O resultado do seu oponente foi aceito porque o prazo pra você confirmar venceu. Se você
            <strong class="text-ink">ganhou de verdade</strong>, dá pra contestar até <strong class="text-ink">{{ holdCountdown }}</strong> — a moderação analisa e reverte se for o caso.
          </p>
          <button
            type="button"
            @click="openDispute('Resultado reportado incorretamente / trapaça')"
            class="mx-auto mt-5 inline-flex items-center gap-2 rounded-xl border border-semantic-error/30 bg-semantic-error/10 px-6 py-3 text-button font-bold text-semantic-error transition-colors hover:bg-semantic-error/20"
          >
            <Flag :size="16" /> Contestar resultado
          </button>
        </template>
      </div>

      <!-- Chat entre os participantes: já a partir do aceite, pra combinarem sala -->
      <div v-if="['accepted', 'in_progress', 'completed'].includes(challenge.status) && isParticipant" v-reveal="'200ms'">
        <MatchChat :challenge-id="challengeId" />
      </div>

      <!-- Vencedor (concluído e já pago — consenso ou pós-liberação; o caso
           retido tem seu próprio bloco acima). -->
      <div
        v-if="challenge.status === 'completed' && !isHeld"
        v-reveal="'140ms'"
        class="relative overflow-hidden rounded-2xl border border-amber-400/30 bg-gradient-to-br from-surface-2 to-surface-1 p-8 text-center shadow-[0_0_60px_-16px_rgba(251,191,36,0.5)]"
      >
        <Trophy :size="36" class="mx-auto text-amber-400" fill="currentColor" />
        <p class="mt-3 text-eyebrow uppercase tracking-widest text-amber-400">Vencedor</p>
        <h2 class="mt-1 font-display text-card-title font-bold text-ink">{{ winnerName }}</h2>
        <p class="mt-2 font-display text-lg font-bold text-semantic-success">+R$ {{ netProfit.toFixed(2) }}</p>
        <span class="mt-3 inline-flex items-center gap-1.5 rounded-full border border-semantic-success/25 bg-semantic-success/10 px-3 py-1 text-caption font-semibold text-semantic-success">
          <Check :size="12" /> Confirmado · prêmio pago
        </span>
      </div>

      <!-- Disputa -->
      <div v-if="challenge.status === 'disputed'" v-reveal="'140ms'">
        <DisputeChat :challenge-id="challengeId" />
      </div>
    </template>

    <!-- Modal de reportar problema / contestar resultado -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="showDisputeModal" class="fixed inset-0 z-[9995] flex items-end justify-center p-0 sm:items-center sm:p-4">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="!disputing && (showDisputeModal = false)"></div>
          <div class="relative w-full max-h-[92vh] overflow-y-auto rounded-t-2xl border border-hairline bg-surface-1 shadow-card-premium custom-scrollbar sm:max-w-lg sm:rounded-2xl">
            <div class="flex items-start justify-between gap-4 border-b border-hairline p-5">
              <div class="flex items-center gap-3">
                <div class="grid size-10 shrink-0 place-items-center rounded-xl bg-semantic-error/10 text-semantic-error">
                  <AlertTriangle :size="20" />
                </div>
                <h3 class="text-lg font-bold text-ink">Reportar / contestar</h3>
              </div>
              <button @click="showDisputeModal = false" :disabled="disputing" class="text-ink-subtle transition-colors hover:text-ink disabled:opacity-40">
                <X :size="20" />
              </button>
            </div>
            <div class="space-y-4 p-5">
              <p class="text-body-sm text-ink-subtle">Conte o que aconteceu. Casos de trapaça ou má conduta vão pra moderação da ArenaX1 — anexe provas no chat da disputa depois.</p>
              <div>
                <label class="mb-1.5 block text-caption font-semibold text-ink">Motivo</label>
                <select v-model="disputeReason" class="h-11 w-full rounded-lg border border-hairline bg-surface-2 px-3 text-body-sm text-ink outline-none transition-colors focus:border-primary focus:ring-2 focus:ring-primary/50">
                  <option v-for="r in DISPUTE_REASONS" :key="r" :value="r">{{ r }}</option>
                </select>
              </div>
              <div>
                <label class="mb-1.5 block text-caption font-semibold text-ink">Detalhes <span class="font-normal text-ink-tertiary">(opcional)</span></label>
                <textarea v-model="disputeDetails" rows="3" maxlength="500" placeholder="O que rolou?" class="w-full resize-none rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-body-sm text-ink outline-none transition-colors focus:border-primary focus:ring-2 focus:ring-primary/50"></textarea>
              </div>
              <p v-if="disputeError" class="text-body-sm font-semibold text-semantic-error">{{ disputeError }}</p>
            </div>
            <div class="flex flex-col-reverse gap-2 border-t border-hairline p-5 sm:flex-row sm:justify-end">
              <button @click="showDisputeModal = false" :disabled="disputing" class="rounded-lg border border-hairline bg-surface-2 px-5 py-2.5 text-body-sm font-bold text-ink transition-colors hover:bg-surface-3 disabled:opacity-50">
                Cancelar
              </button>
              <button @click="submitDispute" :disabled="disputing" class="flex items-center justify-center gap-2 rounded-lg bg-semantic-error px-5 py-2.5 text-body-sm font-bold text-white transition-colors hover:bg-semantic-error/90 disabled:opacity-50">
                <svg v-if="disputing" class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                </svg>
                Enviar
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
