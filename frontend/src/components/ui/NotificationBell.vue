<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  Bell, Trophy, Swords, ShieldAlert, XCircle, CheckCheck, ThumbsDown, BadgeCheck,
  ArrowDownCircle, ArrowUpCircle, Hourglass, ArrowRight,
} from '@lucide/vue'
import { api } from '@/services/api'

type NotificationType =
  | 'tournament_open' | 'match_ready' | 'match_disputed' | 'tournament_prize'
  | 'tournament_cancelled' | 'dispute_resolved_win' | 'dispute_resolved_loss'
  | 'deposit_confirmed' | 'withdraw_completed'
  | 'challenge_accepted' | 'challenge_result_pending' | 'challenge_win'
  | 'challenge_loss' | 'challenge_disputed'
interface NotificationItem {
  id: string
  type: NotificationType
  title: string
  body: string
  tournament_id: string | null
  match_id: string | null
  challenge_id: string | null
  read_at: string | null
  created_at: string
}

// `align="left"` faz o painel abrir pra DIREITA do sino (ancorado pelo lado
// esquerdo) — necessário na sidebar do Dashboard, onde o sino fica coladinho
// na borda esquerda da tela: abrindo pra esquerda (padrão) o painel de 320px
// simplesmente não cabe e é cortado. No header mobile, onde o sino fica na
// borda direita, o padrão (abre pra esquerda) é o correto.
const props = withDefaults(defineProps<{ align?: 'left' | 'right' }>(), { align: 'right' })

const router = useRouter()
const rootEl = ref<HTMLElement | null>(null)
const open = ref(false)
const unreadCount = ref(0)
const notifications = ref<NotificationItem[]>([])

// ⚠️ MOCK TEMPORÁRIO — QA visual dos 7 tipos novos de notificação sem
// depender do INSERT funcionar no Supabase (pedido do usuário, 09/07/2026).
// Troque pra `false` (ou apague o bloco inteiro) antes de ir pra produção
// de verdade — com isso em `true`, TODO usuário vê essas notificações fake
// de depósito/saque/desafio em vez das reais.
const MOCK_PREVIEW_NOTIFICATIONS = true
const now = Date.now()
const mockNotifications: NotificationItem[] = [
  {
    id: 'mock-1', type: 'deposit_confirmed', title: 'Depósito confirmado 💰',
    body: 'Seu depósito de R$ 50.00 caiu na carteira. Saldo atual: R$ 150.00.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: null, created_at: new Date(now - 2 * 60_000).toISOString(),
  },
  {
    id: 'mock-2', type: 'withdraw_completed', title: 'Saque realizado ✅',
    body: 'Seu saque de R$ 80.00 via Pix foi processado e enviado para a chave informada.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: null, created_at: new Date(now - 20 * 60_000).toISOString(),
  },
  {
    id: 'mock-3', type: 'challenge_accepted', title: 'Desafio aceito ⚔️',
    body: 'joaozinho topou sua aposta de R$ 20.00 em EA FC 26. Combinem sala e horário no chat.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: null, created_at: new Date(now - 40 * 60_000).toISOString(),
  },
  {
    id: 'mock-4', type: 'challenge_result_pending', title: 'Sua vez de reportar ⏳',
    body: 'mariasilva já reportou o resultado do desafio em EA FC 26. Confirma o que aconteceu pra liberar o pote.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: null, created_at: new Date(now - 3 * 60 * 60_000).toISOString(),
  },
  {
    id: 'mock-5', type: 'challenge_win', title: 'Você venceu 🏆',
    body: 'Vitória confirmada no desafio de eFootball. R$ 36.00 caíram na sua carteira.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: new Date().toISOString(), created_at: new Date(now - 26 * 60 * 60_000).toISOString(),
  },
  {
    id: 'mock-6', type: 'challenge_loss', title: 'Resultado confirmado',
    body: 'Derrota confirmada no desafio de EA FC 25. R$ 20.00 saíram da sua carteira.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: new Date().toISOString(), created_at: new Date(now - 30 * 60 * 60_000).toISOString(),
  },
  {
    id: 'mock-7', type: 'challenge_disputed', title: 'Resultado em disputa ⚠️',
    body: 'Os resultados do desafio de EA FC 26 bateram de frente e foram pra mediação da ArenaX1.',
    tournament_id: null, match_id: null, challenge_id: null,
    read_at: null, created_at: new Date(now - 5 * 60_000).toISOString(),
  },
]

const loadNotifications = async () => {
  if (MOCK_PREVIEW_NOTIFICATIONS) {
    notifications.value = mockNotifications
    unreadCount.value = mockNotifications.filter(n => !n.read_at).length
    return
  }
  try {
    const feed = await api.get<{ unread_count: number; notifications: NotificationItem[] }>('/api/notifications')
    unreadCount.value = feed.unread_count
    notifications.value = feed.notifications
  } catch {
    // Sino é acessório — falha ao carregar não deve travar o resto da tela.
  }
}

let pollTimer: ReturnType<typeof setInterval> | null = null
onMounted(() => {
  loadNotifications()
  pollTimer = setInterval(loadNotifications, 30_000)
  document.addEventListener('click', handleOutsideClick)
})
onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
  document.removeEventListener('click', handleOutsideClick)
})

function handleOutsideClick(e: MouseEvent) {
  if (open.value && rootEl.value && !rootEl.value.contains(e.target as Node)) open.value = false
}

const toggle = () => {
  open.value = !open.value
  if (open.value) loadNotifications()
}

const markAllRead = async () => {
  if (unreadCount.value === 0) return
  const now = new Date().toISOString()
  unreadCount.value = 0
  notifications.value = notifications.value.map(n => ({ ...n, read_at: n.read_at || now }))
  try {
    await api.post('/api/notifications/mark-read', {})
  } catch {
    await loadNotifications() // desfaz o otimismo se a chamada falhar
  }
}

const handleClick = (n: NotificationItem) => {
  open.value = false
  if (!n.read_at) {
    const now = new Date().toISOString()
    unreadCount.value = Math.max(0, unreadCount.value - 1)
    notifications.value = notifications.value.map(item => item.id === n.id ? { ...item, read_at: now } : item)
    api.post('/api/notifications/mark-read', { ids: [n.id] }).catch(() => {})
  }
  if (n.challenge_id) router.push(`/match/${n.challenge_id}`)
  else if (n.tournament_id) router.push(`/tournaments/${n.tournament_id}`)
  else if (n.type === 'deposit_confirmed' || n.type === 'withdraw_completed') router.push('/wallet')
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

const ICONS: Record<NotificationType, any> = {
  tournament_open: Trophy,
  match_ready: Swords,
  match_disputed: ShieldAlert,
  tournament_prize: Trophy,
  tournament_cancelled: XCircle,
  dispute_resolved_win: BadgeCheck,
  dispute_resolved_loss: ThumbsDown,
  deposit_confirmed: ArrowDownCircle,
  withdraw_completed: ArrowUpCircle,
  challenge_accepted: Swords,
  challenge_result_pending: Hourglass,
  challenge_win: Trophy,
  challenge_loss: ThumbsDown,
  challenge_disputed: ShieldAlert,
}
const ICON_COLOR: Record<NotificationType, string> = {
  tournament_open: 'text-primary bg-primary/10',
  match_ready: 'text-accent bg-accent/10',
  match_disputed: 'text-semantic-error bg-semantic-error/10',
  tournament_prize: 'text-semantic-success bg-semantic-success/10',
  tournament_cancelled: 'text-ink-tertiary bg-surface-3',
  dispute_resolved_win: 'text-semantic-success bg-semantic-success/10',
  dispute_resolved_loss: 'text-semantic-error bg-semantic-error/10',
  deposit_confirmed: 'text-semantic-success bg-semantic-success/10',
  withdraw_completed: 'text-primary bg-primary/10',
  challenge_accepted: 'text-primary bg-primary/10',
  challenge_result_pending: 'text-amber-400 bg-amber-400/10',
  challenge_win: 'text-semantic-success bg-semantic-success/10',
  challenge_loss: 'text-ink-tertiary bg-surface-3',
  challenge_disputed: 'text-semantic-error bg-semantic-error/10',
}
</script>

<template>
  <div ref="rootEl" class="relative">
    <button
      type="button"
      @click="toggle"
      class="relative grid size-9 place-items-center rounded-full text-ink-subtle transition-colors hover:bg-surface-2 hover:text-ink"
      aria-label="Notificações"
    >
      <Bell :size="20" />
      <span
        v-if="unreadCount > 0"
        class="absolute -right-0.5 -top-0.5 grid min-w-[16px] place-items-center rounded-full bg-semantic-error px-1 text-[9px] font-bold leading-none text-white"
        style="height: 16px"
      >{{ unreadCount > 9 ? '9+' : unreadCount }}</span>
    </button>

    <div
      v-if="open"
      class="absolute z-[9996] mt-2 w-80 max-w-[90vw] overflow-hidden rounded-2xl border border-hairline-strong bg-surface-1 shadow-2xl"
      :class="props.align === 'left' ? 'left-0' : 'right-0'"
    >
      <div class="flex items-center justify-between border-b border-hairline px-4 py-3">
        <p class="text-body-sm font-bold text-ink">Notificações</p>
        <button
          v-if="unreadCount > 0"
          type="button"
          @click="markAllRead"
          class="inline-flex items-center gap-1 text-[11px] font-semibold text-primary hover:underline"
        >
          <CheckCheck :size="12" /> Marcar tudo como lido
        </button>
      </div>

      <div class="max-h-96 overflow-y-auto custom-scrollbar">
        <div v-if="notifications.length === 0" class="px-4 py-8 text-center text-body-sm text-ink-subtle">
          Nenhuma notificação ainda.
        </div>
        <div
          v-for="n in notifications"
          :key="n.id"
          role="button"
          tabindex="0"
          @click="handleClick(n)"
          @keydown.enter="handleClick(n)"
          class="flex w-full cursor-pointer items-start gap-3 border-b border-hairline px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-surface-2"
          :class="!n.read_at ? 'bg-primary/[0.04]' : ''"
        >
          <span class="grid size-8 shrink-0 place-items-center rounded-full" :class="ICON_COLOR[n.type]">
            <component :is="ICONS[n.type]" :size="15" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="truncate text-body-sm font-semibold text-ink">{{ n.title }}</p>
            <p class="mt-0.5 line-clamp-2 text-caption text-ink-subtle">{{ n.body }}</p>
            <button
              v-if="n.type === 'challenge_result_pending'"
              type="button"
              @click.stop="handleClick(n)"
              class="mt-2 inline-flex items-center gap-1 rounded-full bg-primary px-3 py-1.5 text-[11px] font-bold text-canvas transition-colors hover:bg-primary-hover"
            >
              Reportar resultado <ArrowRight :size="12" />
            </button>
            <p class="mt-1 text-[10px] text-ink-tertiary">{{ timeAgo(n.created_at) }}</p>
          </div>
          <span v-if="!n.read_at" class="mt-1.5 size-2 shrink-0 rounded-full bg-primary"></span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar { width: 6px; }
.custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
.custom-scrollbar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 10px; }
</style>
