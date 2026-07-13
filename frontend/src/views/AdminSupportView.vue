<script setup lang="ts">
// Fila de tickets de suporte pro admin (regra 4.4). Lista por status; clicar
// abre a conversa (SupportTicketView, a mesma tela do usuário — o backend
// autoriza o admin). Disputas de partida seguem em /admin/disputes, separado.
import { ref, onMounted } from 'vue'
import { Headset, ShieldAlert, RefreshCw, ChevronRight } from '@lucide/vue'
import { api } from '@/services/api'

interface AdminTicket {
  id: string; user_id: string; category: string; message: string
  status: 'open' | 'resolved' | 'closed'; created_at: string; updated_at: string
  user_profile?: { username: string; fair_play_rating: number } | null
}

type Filter = 'open' | 'resolved' | 'closed' | 'all'
const FILTERS: { value: Filter; label: string }[] = [
  { value: 'open', label: 'Em aberto' },
  { value: 'resolved', label: 'Resolvidos' },
  { value: 'closed', label: 'Fechados' },
  { value: 'all', label: 'Todos' },
]

const CATEGORY_LABEL: Record<string, string> = {
  other: 'Assunto geral',
  badge_contest: 'Contestação de ausências',
  match: 'Problema numa partida',
  wallet: 'Carteira, saldo ou saque',
  account: 'Conta ou login',
}
const STATUS_META: Record<'open' | 'resolved' | 'closed', { label: string; cls: string }> = {
  open: { label: 'Em aberto', cls: 'border-amber-400/30 bg-amber-400/10 text-amber-400' },
  resolved: { label: 'Resolvido', cls: 'border-semantic-success/30 bg-semantic-success/10 text-semantic-success' },
  closed: { label: 'Fechado', cls: 'border-hairline-strong bg-surface-3 text-ink-tertiary' },
}

const filter = ref<Filter>('open')
const tickets = ref<AdminTicket[]>([])
const loading = ref(true)
const forbidden = ref(false)
const loadError = ref('')

const load = async () => {
  loading.value = true
  forbidden.value = false
  loadError.value = ''
  try {
    tickets.value = await api.get<AdminTicket[]>(`/api/admin/support/tickets?status=${filter.value}`)
  } catch (err: any) {
    if (err.message?.includes('restrito') || err.message?.includes('administrad')) forbidden.value = true
    else loadError.value = err?.message || 'Erro ao carregar tickets.'
  } finally {
    loading.value = false
  }
}
onMounted(load)

const setFilter = (f: Filter) => { filter.value = f; load() }

const fmtDateTime = (iso: string) =>
  new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-6">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <span class="text-eyebrow uppercase tracking-widest text-accent">Portal de admin</span>
        <h1 class="mt-2 flex items-center gap-2.5 font-display text-headline font-black uppercase tracking-tight text-ink">
          <Headset :size="26" class="text-primary" /> Suporte
        </h1>
        <p class="mt-1 text-body-sm text-ink-subtle">Tickets abertos pelos jogadores. Clique para abrir a conversa e responder.</p>
      </div>
      <button @click="load" :disabled="loading" class="inline-flex w-fit items-center gap-2 rounded-xl border border-hairline-strong bg-surface-1 px-4 py-2.5 text-body-sm font-semibold text-ink-subtle transition-colors hover:bg-surface-2 disabled:opacity-60">
        <RefreshCw :size="15" :class="loading ? 'animate-spin' : ''" /> Atualizar
      </button>
    </div>

    <!-- Filtros -->
    <div class="flex flex-wrap gap-2">
      <button
        v-for="f in FILTERS"
        :key="f.value"
        type="button"
        class="rounded-full border px-4 py-1.5 text-body-sm font-semibold transition-colors"
        :class="filter === f.value
          ? 'border-primary/40 bg-primary/10 text-primary'
          : 'border-hairline bg-surface-1 text-ink-subtle hover:text-ink'"
        @click="setFilter(f.value)"
      >
        {{ f.label }}
      </button>
    </div>

    <!-- Estados -->
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

    <div v-else-if="tickets.length" class="space-y-2.5">
      <router-link
        v-for="t in tickets"
        :key="t.id"
        :to="`/support/${t.id}`"
        class="group flex items-center gap-4 rounded-2xl border border-hairline bg-surface-1/60 p-4 no-underline transition-colors hover:bg-surface-2"
      >
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <p class="truncate font-bold text-ink">{{ t.user_profile?.username || 'Usuário' }}</p>
            <span class="shrink-0 rounded-full border px-2 py-0.5 text-[10px] font-bold" :class="STATUS_META[t.status].cls">
              {{ STATUS_META[t.status].label }}
            </span>
            <span class="shrink-0 rounded-full border border-hairline bg-surface-2 px-2 py-0.5 text-[10px] font-semibold text-ink-subtle">
              {{ CATEGORY_LABEL[t.category] || 'Suporte' }}
            </span>
          </div>
          <p class="mt-1 truncate text-body-sm text-ink-subtle">{{ t.message }}</p>
        </div>
        <span class="shrink-0 text-caption text-ink-tertiary">{{ fmtDateTime(t.updated_at) }}</span>
        <ChevronRight :size="18" class="shrink-0 text-ink-tertiary transition-transform group-hover:translate-x-0.5" />
      </router-link>
    </div>

    <div v-else class="flex flex-col items-center gap-2 rounded-2xl border border-dashed border-hairline-strong bg-surface-1/60 py-16 text-center">
      <Headset :size="30" class="text-ink-tertiary" />
      <p class="font-semibold text-ink">Nenhum ticket {{ filter === 'open' ? 'em aberto' : 'aqui' }}</p>
      <p class="text-body-sm text-ink-subtle">Quando um jogador abrir um ticket, ele aparece nesta fila.</p>
    </div>
  </div>
</template>
