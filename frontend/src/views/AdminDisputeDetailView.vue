<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  ArrowLeft, ShieldAlert, Gamepad2, Star, MessageSquare,
  Clock, Paperclip, CheckCircle2, X,
} from '@lucide/vue'
import { api } from '@/services/api'
import { useConfirmStore } from '@/stores/confirm'
import { useToastStore } from '@/stores/toast'

const props = defineProps<{ challengeId: string }>()

const router = useRouter()
const confirm = useConfirmStore()
const toast = useToastStore()

interface Profile { id: string; username: string | null; fair_play_rating: number | null }
interface TimelineEvent { key: string; label: string; at: string; actor: string | null }
interface ChatMsg { id: string; sender_id: string; message: string; created_at: string; sender_username: string; attachment_url?: string | null }
interface DisputeDetail {
  challenge: {
    id: string; game: string; platform: string; bet_amount: number; status: string
    creator_result: 'win' | 'loss' | null; opponent_result: 'win' | 'loss' | null
    created_at: string; updated_at: string
  }
  creator: Profile | null
  opponent: Profile | null
  dispute: { id: string; status: string; resolution: string | null; created_at: string } | null
  timeline: TimelineEvent[]
  match_messages: ChatMsg[]
  dispute_messages: ChatMsg[]
}

const detail = ref<DisputeDetail | null>(null)
const loading = ref(true)
const loadError = ref('')
const forbidden = ref(false)
const acting = ref(false)
const canceling = ref(false)
const cancelReason = ref('')

const load = async () => {
  loading.value = true
  loadError.value = ''
  forbidden.value = false
  try {
    detail.value = await api.get<DisputeDetail>(`/api/admin/challenge-disputes/${props.challengeId}`)
  } catch (err: any) {
    if (err.message?.includes('restrito') || err.message?.includes('administrad')) {
      forbidden.value = true
    } else {
      loadError.value = err.message || 'Não foi possível carregar a disputa.'
    }
  } finally {
    loading.value = false
  }
}
onMounted(load)

const totalPot = computed(() => detail.value ? Number(detail.value.challenge.bet_amount) * 2 : 0)
const isOpen = computed(() => detail.value?.dispute?.status === 'open')

const initials = (name?: string | null) => (name || '?').slice(0, 2).toUpperCase()
const fmtDateTime = (iso: string) => new Date(iso).toLocaleString('pt-BR', {
  day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
})
const fmtTime = (iso: string) => new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
const resultLabel = (r: 'win' | 'loss' | null) => r === 'win' ? 'Reportou vitória' : r === 'loss' ? 'Reportou derrota' : 'Não reportou'
const isImage = (url?: string | null) => !!url && /\.(jpeg|jpg|gif|png|webp)$/i.test(url)

// Alinha e colore as bolhas de chat pelo lado: criador à esquerda, oponente à
// direita (o admin não é participante, então usamos os papéis pra orientar).
const sideOf = (senderId: string) => senderId === detail.value?.creator?.id ? 'creator' : 'opponent'

const resolve = async (winner: 'creator' | 'opponent') => {
  const d = detail.value
  if (!d) return
  const winnerProfile = winner === 'creator' ? d.creator : d.opponent
  if (!winnerProfile) return
  if (!(await confirm.ask({
    title: 'Definir vencedor',
    message: `Confirmar que ${winnerProfile.username || 'esse jogador'} venceu de verdade o desafio de ${d.challenge.game}? O prêmio de R$ ${totalPot.value.toFixed(2)} vai pra ele e o outro lado perde Fair Play se tiver reportado vitória falsa.`,
    confirmText: 'Confirmar vencedor',
    tone: 'danger',
  }))) return

  acting.value = true
  try {
    await api.post(`/api/admin/challenge-disputes/${props.challengeId}/resolve`, { winner_id: winnerProfile.id })
    toast.push('Disputa resolvida — prêmio pago ao vencedor.', 'success')
    router.push('/admin/disputes')
  } catch (err: any) {
    toast.push(err.message || 'Erro ao resolver a disputa.', 'error')
  } finally {
    acting.value = false
  }
}

const startCancel = () => { canceling.value = true; cancelReason.value = '' }
const closeCancel = () => { canceling.value = false; cancelReason.value = '' }

const submitCancel = async () => {
  const d = detail.value
  if (!d) return
  if (!cancelReason.value.trim()) {
    toast.push('Descreva o motivo de anular a disputa.', 'error')
    return
  }
  if (!(await confirm.ask({
    title: 'Anular disputa',
    message: `O valor apostado por ${d.creator?.username || 'criador'} e ${d.opponent?.username || 'oponente'} volta pra carteira dos dois, sem vencedor e sem penalidade de Fair Play. Confirma?`,
    confirmText: 'Anular e devolver aos dois',
    tone: 'danger',
  }))) return

  acting.value = true
  try {
    await api.post(`/api/admin/challenge-disputes/${props.challengeId}/cancel`, { reason: cancelReason.value.trim() })
    toast.push('Disputa anulada e valor devolvido aos dois.', 'success')
    router.push('/admin/disputes')
  } catch (err: any) {
    toast.push(err.message || 'Erro ao anular a disputa.', 'error')
  } finally {
    acting.value = false
  }
}
</script>

<template>
  <div class="px-6 lg:px-20 py-8">
    <button @click="router.push('/admin/disputes')" class="mb-4 flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle transition-colors hover:text-primary">
      <ArrowLeft :size="14" /> Voltar às disputas
    </button>

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
      <button @click="load" class="text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
    </div>

    <template v-else-if="detail">
      <div class="mb-6 flex flex-col gap-1">
        <span class="text-eyebrow uppercase tracking-widest text-accent">Portal de admin · Análise de disputa</span>
        <h1 class="font-display text-headline font-black uppercase tracking-tight text-ink">{{ detail.challenge.game }}</h1>
        <p class="flex items-center gap-1.5 text-body-sm text-ink-subtle">
          <Gamepad2 :size="14" /> {{ detail.challenge.platform }} · 1v1 · Pote R$ {{ totalPot.toFixed(2) }}
        </p>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] lg:items-start">
        <!-- ══════ Coluna esquerda: dados + linha do tempo + ações ══════ -->
        <div class="space-y-6">
          <!-- Confronto -->
          <div class="rounded-2xl border border-hairline bg-surface-1 p-6">
            <div class="grid grid-cols-[1fr_auto_1fr] items-start gap-3">
              <div class="flex flex-col items-center gap-2 text-center">
                <div class="grid size-16 place-items-center rounded-full bg-primary/15 text-xl font-bold uppercase text-primary">{{ initials(detail.creator?.username) }}</div>
                <div class="min-w-0">
                  <h2 class="truncate font-display text-body-lg font-bold text-ink">{{ detail.creator?.username || '?' }}</h2>
                  <span class="inline-flex items-center gap-0.5 text-[11px] font-semibold text-amber-500">
                    <Star :size="11" fill="currentColor" />{{ (detail.creator?.fair_play_rating ?? 5).toFixed(1) }}
                  </span>
                  <p class="text-caption text-ink-tertiary">Criador</p>
                </div>
                <span class="rounded-full border px-2.5 py-1 text-[10px] font-bold uppercase tracking-wide"
                  :class="detail.challenge.creator_result === 'win' ? 'border-semantic-success/25 bg-semantic-success/10 text-semantic-success' : 'border-hairline-strong bg-surface-2 text-ink-tertiary'">
                  {{ resultLabel(detail.challenge.creator_result) }}
                </span>
              </div>

              <span class="mt-5 grid size-9 shrink-0 place-items-center rounded-full border border-hairline-strong bg-surface-2 text-[11px] font-black text-ink-tertiary">VS</span>

              <div class="flex flex-col items-center gap-2 text-center">
                <div class="grid size-16 place-items-center rounded-full bg-primary/15 text-xl font-bold uppercase text-primary">{{ initials(detail.opponent?.username) }}</div>
                <div class="min-w-0">
                  <h2 class="truncate font-display text-body-lg font-bold text-ink">{{ detail.opponent?.username || '?' }}</h2>
                  <span class="inline-flex items-center gap-0.5 text-[11px] font-semibold text-amber-500">
                    <Star :size="11" fill="currentColor" />{{ (detail.opponent?.fair_play_rating ?? 5).toFixed(1) }}
                  </span>
                  <p class="text-caption text-ink-tertiary">Oponente</p>
                </div>
                <span class="rounded-full border px-2.5 py-1 text-[10px] font-bold uppercase tracking-wide"
                  :class="detail.challenge.opponent_result === 'win' ? 'border-semantic-success/25 bg-semantic-success/10 text-semantic-success' : 'border-hairline-strong bg-surface-2 text-ink-tertiary'">
                  {{ resultLabel(detail.challenge.opponent_result) }}
                </span>
              </div>
            </div>
          </div>

          <!-- Linha do tempo -->
          <div class="rounded-2xl border border-hairline bg-surface-1 p-6">
            <h3 class="mb-4 flex items-center gap-2 font-display text-card-title font-bold text-ink">
              <Clock :size="18" class="text-primary" /> Linha do tempo
            </h3>
            <ol class="relative space-y-4 border-l border-hairline pl-5">
              <li v-for="ev in detail.timeline" :key="ev.key + ev.at" class="relative">
                <span class="absolute -left-[26px] top-0.5 grid size-3.5 place-items-center rounded-full border-2 border-surface-1"
                  :class="ev.key === 'disputed' ? 'bg-semantic-error' : 'bg-primary'"></span>
                <p class="text-body-sm font-semibold text-ink">{{ ev.label }}</p>
                <p class="text-caption text-ink-tertiary">
                  {{ fmtDateTime(ev.at) }}<span v-if="ev.actor"> · {{ ev.actor }}</span>
                </p>
              </li>
            </ol>
          </div>

          <!-- Ações de decisão -->
          <div class="rounded-2xl border p-6" :class="isOpen ? 'border-semantic-error/25 bg-semantic-error/[0.03]' : 'border-hairline bg-surface-1'">
            <h3 class="mb-1 flex items-center gap-2 font-display text-card-title font-bold text-ink">
              <ShieldAlert :size="18" class="text-semantic-error" /> Decisão da moderação
            </h3>

            <template v-if="isOpen">
              <p class="mb-4 text-body-sm text-ink-subtle">Analise os dois chats ao lado antes de decidir. Toda ação pede confirmação.</p>
              <div class="space-y-2">
                <button type="button" @click="resolve('creator')" :disabled="acting || !detail.creator"
                  class="w-full rounded-lg border border-semantic-success/30 bg-semantic-success/10 px-3 py-3 text-body-sm font-semibold text-semantic-success transition-colors hover:bg-semantic-success/20 disabled:cursor-wait disabled:opacity-60">
                  {{ detail.creator?.username || '—' }} venceu de verdade
                </button>
                <button type="button" @click="resolve('opponent')" :disabled="acting || !detail.opponent"
                  class="w-full rounded-lg border border-semantic-success/30 bg-semantic-success/10 px-3 py-3 text-body-sm font-semibold text-semantic-success transition-colors hover:bg-semantic-success/20 disabled:cursor-wait disabled:opacity-60">
                  {{ detail.opponent?.username || '—' }} venceu de verdade
                </button>

                <button v-if="!canceling" type="button" @click="startCancel" :disabled="acting"
                  class="w-full rounded-lg border border-hairline-strong bg-surface-2 px-3 py-3 text-body-sm font-semibold text-ink-subtle transition-colors hover:bg-surface-3 disabled:cursor-wait disabled:opacity-60">
                  Anular disputa (devolver aos dois)
                </button>

                <div v-else class="space-y-2 rounded-lg border border-hairline bg-surface-2 p-3">
                  <label class="block text-caption font-semibold uppercase tracking-wider text-ink-subtle">Motivo de anular</label>
                  <textarea v-model="cancelReason" rows="2" placeholder="Ex.: nenhum dos dois enviou prova do placar, impossível decidir com segurança."
                    class="w-full rounded-lg border border-hairline-strong bg-canvas px-3.5 py-2.5 text-body-sm text-ink placeholder:text-ink-tertiary focus:border-primary focus:outline-none"></textarea>
                  <div class="flex gap-2">
                    <button type="button" @click="submitCancel" :disabled="acting"
                      class="rounded-lg bg-semantic-error px-4 py-2 text-body-sm font-bold text-canvas transition-colors hover:bg-semantic-error/90 disabled:opacity-50">
                      Confirmar anulação
                    </button>
                    <button type="button" @click="closeCancel" class="inline-flex items-center gap-1.5 rounded-lg border border-hairline-strong px-4 py-2 text-body-sm font-semibold text-ink-subtle hover:bg-surface-3">
                      <X :size="14" /> Cancelar
                    </button>
                  </div>
                </div>
              </div>
            </template>

            <template v-else>
              <p class="mt-2 inline-flex items-center gap-2 rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-body-sm text-ink-subtle">
                <CheckCircle2 :size="16" class="text-semantic-success" />
                Esta disputa já foi <strong class="text-ink">{{ detail.dispute?.status === 'cancelled' ? 'anulada' : 'resolvida' }}</strong>.
              </p>
              <p v-if="detail.dispute?.resolution" class="mt-2 text-caption text-ink-tertiary">Motivo/registro: {{ detail.dispute.resolution }}</p>
            </template>
          </div>
        </div>

        <!-- ══════ Coluna direita: os dois chats ══════ -->
        <div class="space-y-6">
          <!-- Chat de mediação (disputa) — com os prints -->
          <div class="overflow-hidden rounded-2xl border border-semantic-error/25 bg-surface-1">
            <div class="flex items-center justify-between border-b border-hairline bg-surface-2 p-4">
              <h3 class="flex items-center gap-2 font-display text-body-lg font-bold text-ink">
                <ShieldAlert :size="17" class="text-semantic-error" /> Chat de mediação
              </h3>
              <span class="text-caption text-ink-tertiary">Provas e argumentos</span>
            </div>
            <div class="max-h-[520px] space-y-4 overflow-y-auto bg-canvas p-5 custom-scrollbar">
              <p v-if="detail.dispute_messages.length === 0" class="py-8 text-center text-body-sm italic text-ink-subtle">Nenhuma mensagem na disputa ainda.</p>
              <div v-for="msg in detail.dispute_messages" :key="msg.id" class="flex flex-col"
                :class="sideOf(msg.sender_id) === 'creator' ? 'items-start' : 'items-end'">
                <span class="mb-1 px-1 text-[10px] font-semibold" :class="sideOf(msg.sender_id) === 'creator' ? 'text-primary' : 'text-accent'">{{ msg.sender_username }}</span>
                <div class="max-w-[85%] rounded-lg border px-4 py-3 text-body-sm"
                  :class="sideOf(msg.sender_id) === 'creator' ? 'rounded-tl-none border-hairline bg-surface-2 text-ink' : 'rounded-tr-none border-accent/25 bg-accent/10 text-ink'">
                  <p v-if="msg.message" class="whitespace-pre-wrap">{{ msg.message }}</p>
                  <a v-if="msg.attachment_url" :href="msg.attachment_url" target="_blank" rel="noopener" class="mt-2 block">
                    <img v-if="isImage(msg.attachment_url)" :src="msg.attachment_url" class="max-w-full rounded-lg border border-hairline" />
                    <span v-else class="inline-flex items-center gap-1.5 rounded-lg bg-black/20 px-2.5 py-1.5 text-caption font-bold text-ink"><Paperclip :size="13" /> Ver anexo</span>
                  </a>
                  <span class="mt-1.5 block text-right text-[10px] text-ink-tertiary">{{ fmtTime(msg.created_at) }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Chat dos jogadores (antes da disputa) -->
          <div class="overflow-hidden rounded-2xl border border-hairline bg-surface-1">
            <div class="flex items-center justify-between border-b border-hairline bg-surface-2 p-4">
              <h3 class="flex items-center gap-2 font-display text-body-lg font-bold text-ink">
                <MessageSquare :size="17" class="text-primary" /> Conversa dos jogadores
              </h3>
              <span class="text-caption text-ink-tertiary">Antes da disputa</span>
            </div>
            <div class="max-h-[420px] space-y-4 overflow-y-auto bg-canvas p-5 custom-scrollbar">
              <p v-if="detail.match_messages.length === 0" class="py-8 text-center text-body-sm italic text-ink-subtle">Os dois não trocaram mensagens no chat do desafio.</p>
              <div v-for="msg in detail.match_messages" :key="msg.id" class="flex flex-col"
                :class="sideOf(msg.sender_id) === 'creator' ? 'items-start' : 'items-end'">
                <span class="mb-1 px-1 text-[10px] font-semibold" :class="sideOf(msg.sender_id) === 'creator' ? 'text-primary' : 'text-accent'">{{ msg.sender_username }}</span>
                <div class="max-w-[85%] rounded-lg border px-4 py-3 text-body-sm"
                  :class="sideOf(msg.sender_id) === 'creator' ? 'rounded-tl-none border-hairline bg-surface-2 text-ink' : 'rounded-tr-none border-accent/25 bg-accent/10 text-ink'">
                  <p class="whitespace-pre-wrap">{{ msg.message }}</p>
                  <span class="mt-1.5 block text-right text-[10px] text-ink-tertiary">{{ fmtTime(msg.created_at) }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
