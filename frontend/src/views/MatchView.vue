<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
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
} from '@lucide/vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const challengeId = route.params.id as string
const challenge = ref<any>(null)
const loading = ref(true)
const reporting = ref<'win' | 'loss' | null>(null)
let realtimeSub: any = null

const fetchChallenge = async () => {
  try {
    const { data, error } = await supabase
      .from('challenges')
      .select('*, creator_profile:creator_id(username, fair_play_rating), opponent_profile:opponent_id(username, fair_play_rating)')
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

const setupRealtime = () => {
  realtimeSub = supabase
    .channel(`match-${challengeId}`)
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'challenges', filter: `id=eq.${challengeId}` },
      () => fetchChallenge()
    )
    .subscribe()
}

onMounted(() => {
  fetchChallenge()
  setupRealtime()
})

onUnmounted(() => {
  if (realtimeSub) supabase.removeChannel(realtimeSub)
})

const isCreator = computed(() => challenge.value?.creator_id === authStore.user?.id)
const isOpponent = computed(() => challenge.value?.opponent_id === authStore.user?.id)
const isParticipant = computed(() => isCreator.value || isOpponent.value)

const myResult = computed(() => isCreator.value ? challenge.value?.creator_result : challenge.value?.opponent_result)

const handleReport = async (result: 'win' | 'loss') => {
  if (!confirm(`Tem certeza que deseja reportar ${result === 'win' ? 'VITÓRIA' : 'DERROTA'}? Isso é irreversível e declarações falsas podem resultar em banimento.`)) {
    return
  }

  reporting.value = result
  try {
    const resData = await api.post<{ message: string }>('/api/challenges/report', {
      challenge_id: challengeId,
      result: result
    })
    await fetchChallenge()
    if (resData.message) alert(resData.message)
  } catch (err: any) {
    alert(err.message || 'Erro ao reportar resultado.')
  } finally {
    reporting.value = null
  }
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

/* ── Prêmio ao vencedor: mesma regra do backend (rake 10% em challenges.py),
   já usada em ChallengesView — bet_amount * 1.8. ── */
const totalPrize = computed(() => (challenge.value?.bet_amount ?? 0) * 1.8)
const netProfit = computed(() => (challenge.value?.bet_amount ?? 0) * 0.8)
const winnerName = computed(() => {
  if (!challenge.value) return ''
  if (challenge.value.winner_id === challenge.value.creator_id) return challenge.value.creator_profile?.username
  return challenge.value.opponent_profile?.username
})

type Status = 'open' | 'in_progress' | 'completed' | 'disputed' | 'cancelled'
const statusMeta: Record<Status, { label: string; icon: any; dot: string; text: string; bg: string; border: string }> = {
  open: { label: 'Aguardando oponente', icon: UserPlus, dot: 'bg-ink-tertiary', text: 'text-ink-subtle', bg: 'bg-surface-2', border: 'border-hairline' },
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

      <!-- Reportar resultado -->
      <div v-if="challenge.status === 'in_progress' && isParticipant" v-reveal="'140ms'" class="rounded-2xl border border-hairline bg-surface-1 p-6 text-center sm:p-8">
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
      </div>

      <!-- Chat entre os participantes: só depois que a aposta foi aceita -->
      <div v-if="['in_progress', 'completed'].includes(challenge.status) && isParticipant" v-reveal="'200ms'">
        <MatchChat :challenge-id="challengeId" />
      </div>

      <!-- Vencedor (concluído) -->
      <div
        v-if="challenge.status === 'completed'"
        v-reveal="'140ms'"
        class="relative overflow-hidden rounded-2xl border border-amber-400/30 bg-gradient-to-br from-surface-2 to-surface-1 p-8 text-center shadow-[0_0_60px_-16px_rgba(251,191,36,0.5)]"
      >
        <Trophy :size="36" class="mx-auto text-amber-400" fill="currentColor" />
        <p class="mt-3 text-eyebrow uppercase tracking-widest text-amber-400">Vencedor</p>
        <h2 class="mt-1 font-display text-card-title font-bold text-ink">{{ winnerName }}</h2>
        <p class="mt-2 font-display text-lg font-bold text-semantic-success">+R$ {{ netProfit.toFixed(2) }}</p>
      </div>

      <!-- Disputa -->
      <div v-if="challenge.status === 'disputed'" v-reveal="'140ms'">
        <DisputeChat :challenge-id="challengeId" />
      </div>
    </template>

  </div>
</template>
