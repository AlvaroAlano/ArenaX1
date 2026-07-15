<script setup lang="ts">
// Fila de saques pro admin processar manualmente (regra: o Mercado Pago não
// manda Pix pra chave de terceiro via API — ver backend/pix.py). O saque já
// debitou a carteira do usuário na hora; aqui o admin só confirma que
// mandou o Pix de verdade pelo próprio banco, ou rejeita e o valor estorna.
import { ref, onMounted } from 'vue'
import { ArrowUpFromLine, ShieldAlert, RefreshCw, Check, X } from '@lucide/vue'
import { api } from '@/services/api'
import { useConfirmStore } from '@/stores/confirm'
import { useToastStore } from '@/stores/toast'

const confirm = useConfirmStore()
const toast = useToastStore()

interface AdminWithdrawal {
  id: string; amount: number; pix_key: string; status: 'pending' | 'completed' | 'failed'
  description: string; created_at: string; processed_at: string | null
  failure_reason: string | null; username: string
}

type Filter = 'pending' | 'completed' | 'failed' | 'all'
const FILTERS: { value: Filter; label: string }[] = [
  { value: 'pending', label: 'Pendentes' },
  { value: 'completed', label: 'Confirmados' },
  { value: 'failed', label: 'Rejeitados' },
  { value: 'all', label: 'Todos' },
]

const filter = ref<Filter>('pending')
const withdrawals = ref<AdminWithdrawal[]>([])
const loading = ref(true)
const forbidden = ref(false)
const loadError = ref('')
const actingId = ref<string | null>(null)
const rejectingId = ref<string | null>(null)
const rejectReason = ref('')

const load = async () => {
  loading.value = true
  forbidden.value = false
  loadError.value = ''
  try {
    withdrawals.value = await api.get<AdminWithdrawal[]>(`/api/admin/withdrawals?status=${filter.value}`)
  } catch (err: any) {
    if (err.message?.includes('restrito') || err.message?.includes('administrad')) forbidden.value = true
    else loadError.value = err?.message || 'Erro ao carregar saques.'
  } finally {
    loading.value = false
  }
}
onMounted(load)

const setFilter = (f: Filter) => { filter.value = f; load() }

const fmtDateTime = (iso: string) =>
  new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })

const confirmWithdrawal = async (w: AdminWithdrawal) => {
  if (!(await confirm.ask({
    title: 'Confirmar saque',
    message: `Você já enviou R$ ${w.amount.toFixed(2)} via Pix para a chave "${w.pix_key}"? Essa ação só marca o saque como concluído no sistema — o envio precisa ter sido feito antes, pelo seu próprio banco.`,
    confirmText: 'Sim, já enviei',
  }))) return

  actingId.value = w.id
  try {
    await api.post(`/api/admin/withdrawals/${w.id}/confirm`)
    toast.push('Saque confirmado.', 'success')
    await load()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao confirmar o saque.', 'error')
  } finally {
    actingId.value = null
  }
}

const startReject = (w: AdminWithdrawal) => {
  rejectingId.value = w.id
  rejectReason.value = ''
}

const cancelReject = () => {
  rejectingId.value = null
  rejectReason.value = ''
}

const submitReject = async (w: AdminWithdrawal) => {
  if (!rejectReason.value.trim()) {
    toast.push('Descreva o motivo da rejeição.', 'error')
    return
  }
  if (!(await confirm.ask({
    title: 'Rejeitar saque',
    message: `O valor de R$ ${w.amount.toFixed(2)} volta pro saldo de ${w.username} e o saque é marcado como rejeitado. Confirma?`,
    confirmText: 'Rejeitar e estornar',
    tone: 'danger',
  }))) return

  actingId.value = w.id
  try {
    await api.post(`/api/admin/withdrawals/${w.id}/reject`, { reason: rejectReason.value.trim() })
    toast.push('Saque rejeitado e valor estornado.', 'success')
    cancelReject()
    await load()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao rejeitar o saque.', 'error')
  } finally {
    actingId.value = null
  }
}
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-6">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <span class="text-eyebrow uppercase tracking-widest text-accent">Portal de admin</span>
        <h1 class="mt-2 flex items-center gap-2.5 font-display text-headline font-black uppercase tracking-tight text-ink">
          <ArrowUpFromLine :size="26" class="text-primary" /> Saques
        </h1>
        <p class="mt-1 text-body-sm text-ink-subtle">O Mercado Pago não envia Pix pra chave de terceiro — confirme aqui depois de mandar manualmente pelo banco.</p>
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

    <div v-else-if="withdrawals.length" class="space-y-2.5">
      <div
        v-for="w in withdrawals"
        :key="w.id"
        class="rounded-2xl border border-hairline bg-surface-1/60 p-4"
      >
        <div class="flex flex-wrap items-center gap-4">
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <p class="truncate font-bold text-ink">{{ w.username }}</p>
              <span class="shrink-0 rounded-full border px-2 py-0.5 text-[10px] font-bold"
                :class="w.status === 'pending' ? 'border-amber-400/30 bg-amber-400/10 text-amber-400'
                  : w.status === 'completed' ? 'border-semantic-success/30 bg-semantic-success/10 text-semantic-success'
                  : 'border-semantic-error/30 bg-semantic-error/10 text-semantic-error'">
                {{ w.status === 'pending' ? 'Pendente' : w.status === 'completed' ? 'Confirmado' : 'Rejeitado' }}
              </span>
            </div>
            <p class="mt-1 text-body-sm text-ink-subtle">Chave Pix: <span class="font-semibold text-ink">{{ w.pix_key }}</span></p>
            <p v-if="w.failure_reason" class="mt-1 text-caption text-semantic-error">Motivo da rejeição: {{ w.failure_reason }}</p>
          </div>
          <div class="text-right shrink-0">
            <p class="font-display text-xl font-black text-ink">R$ {{ w.amount.toFixed(2) }}</p>
            <p class="text-caption text-ink-tertiary">{{ fmtDateTime(w.created_at) }}</p>
          </div>
        </div>

        <div v-if="w.status === 'pending'" class="mt-4 flex flex-wrap gap-2 border-t border-hairline pt-4">
          <button
            @click="confirmWithdrawal(w)"
            :disabled="actingId === w.id"
            class="inline-flex items-center gap-1.5 rounded-lg bg-semantic-success/10 px-3.5 py-2 text-body-sm font-bold text-semantic-success transition-colors hover:bg-semantic-success/20 disabled:opacity-50"
          >
            <Check :size="16" /> Confirmar envio
          </button>
          <button
            v-if="rejectingId !== w.id"
            @click="startReject(w)"
            :disabled="actingId === w.id"
            class="inline-flex items-center gap-1.5 rounded-lg bg-semantic-error/10 px-3.5 py-2 text-body-sm font-bold text-semantic-error transition-colors hover:bg-semantic-error/20 disabled:opacity-50"
          >
            <X :size="16" /> Rejeitar
          </button>
        </div>

        <div v-if="rejectingId === w.id" class="mt-3 space-y-2 border-t border-hairline pt-3">
          <label class="block text-caption font-semibold uppercase tracking-wider text-ink-subtle">Motivo da rejeição</label>
          <textarea
            v-model="rejectReason"
            rows="2"
            placeholder="Ex.: chave Pix inválida, dados não conferem..."
            class="w-full rounded-lg border border-hairline-strong bg-surface-2 px-3.5 py-2.5 text-body-sm text-ink placeholder:text-ink-tertiary focus:border-primary focus:outline-none"
          ></textarea>
          <div class="flex gap-2">
            <button
              @click="submitReject(w)"
              :disabled="actingId === w.id"
              class="rounded-lg bg-semantic-error px-4 py-2 text-body-sm font-bold text-canvas transition-colors hover:bg-semantic-error/90 disabled:opacity-50"
            >
              Confirmar rejeição
            </button>
            <button @click="cancelReject" class="rounded-lg border border-hairline-strong px-4 py-2 text-body-sm font-semibold text-ink-subtle hover:bg-surface-2">
              Cancelar
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="flex flex-col items-center gap-2 rounded-2xl border border-dashed border-hairline-strong bg-surface-1/60 py-16 text-center">
      <ArrowUpFromLine :size="30" class="text-ink-tertiary" />
      <p class="font-semibold text-ink">Nenhum saque {{ filter === 'pending' ? 'pendente' : 'aqui' }}</p>
      <p class="text-body-sm text-ink-subtle">Quando um jogador solicitar um saque, ele aparece nesta fila.</p>
    </div>
  </div>
</template>
