<script setup lang="ts">
// Conversa de um ticket de suporte (thread). MESMA tela serve o usuário dono e
// o admin — o backend (GET /api/support/tickets/:id) autoriza os dois lados. É
// pra cá que a notificação de resposta leva direto.
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, Send, Gamepad2, ShieldCheck, CheckCircle2, RotateCcw, XCircle } from '@lucide/vue'
import { api } from '@/services/api'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'

const props = defineProps<{ id: string }>()
const router = useRouter()
const authStore = useAuthStore()
const toast = useToastStore()

interface TicketMessage { id: string; sender_id: string; from_support: boolean; body: string; created_at: string }
interface Ticket {
  id: string; user_id: string; category: string; message: string; challenge_id: string | null
  status: 'open' | 'resolved' | 'closed'; created_at: string; updated_at: string
  user_profile?: { username: string; fair_play_rating: number } | null
}

const ticket = ref<Ticket | null>(null)
const messages = ref<TicketMessage[]>([])
const loading = ref(true)
const loadError = ref('')
const reply = ref('')
const sending = ref(false)

const myId = computed(() => authStore.user?.id || null)
// "Estou como suporte" = sou admin E não sou o dono do ticket (um admin pode
// abrir o próprio ticket; aí ele fala como usuário).
const asSupport = computed(() => authStore.isAdmin && ticket.value?.user_id !== myId.value)

const CATEGORY_LABEL: Record<string, string> = {
  other: 'Assunto geral',
  badge_contest: 'Contestação de histórico de ausências',
  match: 'Problema numa partida',
  wallet: 'Carteira, saldo ou saque',
  account: 'Conta ou login',
}
const STATUS_META: Record<'open' | 'resolved' | 'closed', { label: string; cls: string }> = {
  open: { label: 'Em aberto', cls: 'border-amber-400/30 bg-amber-400/10 text-amber-400' },
  resolved: { label: 'Resolvido', cls: 'border-semantic-success/30 bg-semantic-success/10 text-semantic-success' },
  closed: { label: 'Fechado', cls: 'border-hairline-strong bg-surface-3 text-ink-tertiary' },
}

// Evita duplicar quando o realtime ecoa uma mensagem já presente (ex.: a que
// acabei de enviar e já anexei pela resposta da API).
const pushUnique = (m: TicketMessage) => {
  if (m?.id && messages.value.some((x) => x.id === m.id)) return
  messages.value.push(m)
}

const load = async () => {
  loading.value = true
  loadError.value = ''
  try {
    const data = await api.get<{ ticket: Ticket; messages: TicketMessage[] }>(`/api/support/tickets/${props.id}`)
    ticket.value = data.ticket
    messages.value = data.messages
  } catch (err: any) {
    loadError.value = err?.message || 'Não foi possível carregar a conversa.'
  } finally {
    loading.value = false
  }
}

let realtimeSub: any = null
const setupRealtime = () => {
  // RLS de support_ticket_messages só devolve linhas do dono do ticket ou de
  // admin — o filtro por ticket_id + a policy garantem que só chega o relevante.
  realtimeSub = supabase
    .channel(`support-ticket-${props.id}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'support_ticket_messages', filter: `ticket_id=eq.${props.id}` },
      (payload) => pushUnique(payload.new as TicketMessage),
    )
    .subscribe()
}

onMounted(async () => {
  await load()
  setupRealtime()
})
onUnmounted(() => {
  if (realtimeSub) supabase.removeChannel(realtimeSub)
})

const canSend = computed(() => reply.value.trim().length >= 1 && !sending.value)

const send = async () => {
  if (!canSend.value) return
  sending.value = true
  try {
    const msg = await api.post<TicketMessage>(`/api/support/tickets/${props.id}/reply`, { message: reply.value.trim() })
    pushUnique(msg)
    reply.value = ''
    // Resposta do usuário reabre o ticket (espelha a regra da fn SQL).
    if (ticket.value && !asSupport.value && ticket.value.status !== 'open') ticket.value.status = 'open'
  } catch (err: any) {
    toast.push(err?.message || 'Não foi possível enviar sua mensagem.', 'error')
  } finally {
    sending.value = false
  }
}

const setStatus = async (status: 'open' | 'resolved' | 'closed') => {
  try {
    const updated = await api.post<Ticket>(`/api/admin/support/tickets/${props.id}/status`, { status })
    if (ticket.value) ticket.value.status = updated.status
    toast.push('Status atualizado.', 'success')
  } catch (err: any) {
    toast.push(err?.message || 'Não foi possível atualizar o status.', 'error')
  }
}

const fmtDateTime = (iso: string) =>
  new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })

const senderLabel = (m: TicketMessage) =>
  m.from_support ? 'Suporte' : (ticket.value?.user_profile?.username || 'Usuário')
const isMine = (m: TicketMessage) => m.sender_id === myId.value
</script>

<template>
  <div class="mx-auto flex min-h-full max-w-3xl flex-col gap-5 p-6 md:p-10">
    <!-- Voltar -->
    <button
      type="button"
      class="inline-flex w-fit items-center gap-1.5 text-body-sm font-semibold text-ink-subtle transition-colors hover:text-ink"
      @click="router.back()"
    >
      <ArrowLeft :size="16" /> Voltar
    </button>

    <!-- Loading -->
    <div v-if="loading" class="animate-pulse space-y-4">
      <div class="h-24 rounded-2xl bg-surface-2"></div>
      <div class="h-16 rounded-2xl bg-surface-2"></div>
      <div class="h-16 w-2/3 rounded-2xl bg-surface-2"></div>
    </div>

    <div v-else-if="loadError" class="rounded-2xl border border-semantic-error/30 bg-semantic-error/10 p-5 text-center text-body-sm text-semantic-error">
      {{ loadError }}
    </div>

    <template v-else-if="ticket">
      <!-- Cabeçalho do ticket -->
      <header class="space-y-3 rounded-2xl border border-hairline bg-surface-2 p-5">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h1 class="font-display text-xl font-black text-ink">{{ CATEGORY_LABEL[ticket.category] || 'Suporte' }}</h1>
          <span class="rounded-full border px-2.5 py-1 text-caption font-bold" :class="STATUS_META[ticket.status].cls">
            {{ STATUS_META[ticket.status].label }}
          </span>
        </div>
        <p class="flex flex-wrap items-center gap-x-3 gap-y-1 text-caption text-ink-tertiary">
          <span>Aberto em {{ fmtDateTime(ticket.created_at) }}</span>
          <span v-if="asSupport && ticket.user_profile" class="inline-flex items-center gap-1">
            · por <span class="font-semibold text-ink-subtle">{{ ticket.user_profile.username }}</span>
          </span>
        </p>
        <router-link
          v-if="ticket.challenge_id"
          :to="`/match/${ticket.challenge_id}`"
          class="inline-flex items-center gap-1.5 rounded-lg border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle no-underline transition-colors hover:border-hairline-strong hover:text-ink"
        >
          <Gamepad2 :size="14" /> Ver a partida relacionada
        </router-link>

        <!-- Ações de admin (só quando estou como suporte) -->
        <div v-if="asSupport" class="flex flex-wrap gap-2 border-t border-hairline pt-3">
          <button
            v-if="ticket.status !== 'resolved'"
            type="button"
            class="inline-flex items-center gap-1.5 rounded-lg border border-semantic-success/30 bg-semantic-success/10 px-3 py-1.5 text-caption font-bold text-semantic-success transition-colors hover:bg-semantic-success/20"
            @click="setStatus('resolved')"
          >
            <CheckCircle2 :size="14" /> Marcar resolvido
          </button>
          <button
            v-if="ticket.status !== 'open'"
            type="button"
            class="inline-flex items-center gap-1.5 rounded-lg border border-hairline-strong bg-surface-1 px-3 py-1.5 text-caption font-bold text-ink-subtle transition-colors hover:text-ink"
            @click="setStatus('open')"
          >
            <RotateCcw :size="14" /> Reabrir
          </button>
          <button
            v-if="ticket.status !== 'closed'"
            type="button"
            class="inline-flex items-center gap-1.5 rounded-lg border border-hairline-strong bg-surface-1 px-3 py-1.5 text-caption font-bold text-ink-subtle transition-colors hover:text-ink"
            @click="setStatus('closed')"
          >
            <XCircle :size="14" /> Fechar
          </button>
        </div>
      </header>

      <!-- Thread -->
      <div class="flex flex-1 flex-col gap-3">
        <!-- Mensagem original (abertura do ticket, sempre do usuário) -->
        <div class="flex flex-col items-start">
          <div class="max-w-[85%] rounded-2xl rounded-tl-sm border border-hairline bg-surface-1 px-4 py-3">
            <p class="whitespace-pre-wrap break-words text-body-sm text-ink">{{ ticket.message }}</p>
          </div>
          <span class="mt-1 px-1 text-[10px] text-ink-tertiary">
            {{ ticket.user_profile?.username || 'Você' }} · {{ fmtDateTime(ticket.created_at) }}
          </span>
        </div>

        <!-- Respostas -->
        <div
          v-for="m in messages"
          :key="m.id"
          class="flex flex-col"
          :class="isMine(m) ? 'items-end' : 'items-start'"
        >
          <div
            class="max-w-[85%] rounded-2xl px-4 py-3"
            :class="m.from_support
              ? 'rounded-tr-sm border border-primary/25 bg-primary/[0.08]'
              : (isMine(m) ? 'rounded-tr-sm border border-hairline-strong bg-surface-2' : 'rounded-tl-sm border border-hairline bg-surface-1')"
          >
            <p v-if="m.from_support" class="mb-1 flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider text-primary">
              <ShieldCheck :size="12" /> Suporte ArenaX1
            </p>
            <p class="whitespace-pre-wrap break-words text-body-sm text-ink">{{ m.body }}</p>
          </div>
          <span class="mt-1 px-1 text-[10px] text-ink-tertiary">{{ senderLabel(m) }} · {{ fmtDateTime(m.created_at) }}</span>
        </div>
      </div>

      <!-- Composer -->
      <form class="sticky bottom-0 flex items-end gap-2 border-t border-hairline bg-canvas/80 pt-3 backdrop-blur" @submit.prevent="send">
        <textarea
          v-model="reply"
          rows="1"
          maxlength="4000"
          :placeholder="asSupport ? 'Responder como suporte…' : 'Escreva sua resposta…'"
          class="max-h-32 min-h-[46px] flex-1 resize-y rounded-xl border border-hairline bg-surface-1 px-3.5 py-3 text-body-sm text-ink placeholder:text-ink-tertiary outline-none transition-colors focus:border-primary/50"
          @keydown.enter.exact.prevent="send"
        ></textarea>
        <button
          type="submit"
          :disabled="!canSend"
          class="grid size-[46px] shrink-0 place-items-center rounded-xl bg-primary text-canvas transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
          aria-label="Enviar"
        >
          <Send :size="18" />
        </button>
      </form>
    </template>
  </div>
</template>
