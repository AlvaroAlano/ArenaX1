<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  Wallet, Lock, ArrowDownToLine, ArrowUpFromLine, Trophy, Percent,
  Swords, Award, Users, ShieldAlert, Gamepad2, RefreshCw, ChevronRight,
} from '@lucide/vue'
import { api } from '@/services/api'

const router = useRouter()

interface DashboardMetrics {
  financeiro: {
    saldo_disponivel_total: number
    saldo_travado_total: number
    total_depositado: number
    total_sacado: number
    total_premios_pagos: number
    total_rake_desafios: number
    total_rake_torneios: number
    travado_em_desafios: number
    travado_em_torneios_online: number
  }
  desafios: {
    total: number; abertos: number; em_andamento: number; concluidos: number
    em_disputa: number; aposta_media: number
  }
  torneios_locais: { total: number; em_andamento: number; concluidos: number }
  torneios_online: {
    total: number; inscricoes_abertas: number; em_andamento: number
    concluidos: number; cancelados: number; taxa_inscricao_media: number
    distribuicao_tamanho: Record<string, number>
  }
  usuarios: { total: number; jogadores_ativos: number; fair_play_medio: number }
  disputas: { desafios_em_disputa: number; torneios_em_disputa: number; resolvidas_total: number }
  preferencias: {
    jogos_populares: { label: string; total: number }[]
    plataformas_populares: { label: string; total: number }[]
  }
}

const metrics = ref<DashboardMetrics | null>(null)
const loading = ref(true)
const loadError = ref('')
const forbidden = ref(false)

const loadMetrics = async () => {
  loading.value = true
  loadError.value = ''
  forbidden.value = false
  try {
    metrics.value = await api.get<DashboardMetrics>('/api/admin/metrics')
  } catch (err: any) {
    if (err.message?.includes('restrito') || err.message?.includes('administrad')) {
      forbidden.value = true
    } else {
      loadError.value = err.message || 'Erro ao carregar o painel administrativo.'
    }
  } finally {
    loading.value = false
  }
}
onMounted(loadMetrics)

const fmtBRL = (n: number) => `R$ ${(n ?? 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
const fmtNum = (n: number) => (n ?? 0).toLocaleString('pt-BR')

const maxPref = (list: { label: string; total: number }[]) => Math.max(1, ...list.map(i => i.total))
const barPct = (value: number, max: number) => Math.max(4, Math.round((value / max) * 100))

const tamanhoOrdenado = computed(() => {
  if (!metrics.value) return []
  return Object.entries(metrics.value.torneios_online.distribuicao_tamanho)
    .map(([size, total]) => ({ label: `${size} jogadores`, total: total as number }))
    .sort((a, b) => Number(a.label) - Number(b.label))
})

const disputasAbertasTotal = computed(() => {
  if (!metrics.value) return 0
  return metrics.value.disputas.torneios_em_disputa
})
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <span class="text-eyebrow uppercase tracking-widest text-accent">Portal de admin</span>
        <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Visão Geral</h1>
        <p class="mt-1 text-body-sm text-ink-subtle">Dinheiro, desafios e torneios rodando na ArenaX1 agora.</p>
      </div>
      <button @click="loadMetrics" :disabled="loading" class="inline-flex w-fit items-center gap-2 rounded-xl border border-hairline-strong bg-surface-1 px-4 py-2.5 text-body-sm font-semibold text-ink-subtle transition-colors hover:bg-surface-2 disabled:opacity-60">
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
      <p class="max-w-sm text-body-sm text-ink-subtle">Sua conta não tem permissão de admin. Se isso for um engano, marque <code>is_admin = true</code> no seu perfil pelo painel do Supabase.</p>
    </div>

    <div v-else-if="loadError" class="flex flex-col items-center gap-3 py-24 text-center">
      <p class="font-semibold text-semantic-error">{{ loadError }}</p>
      <button @click="loadMetrics" class="text-body-sm font-semibold text-primary hover:underline">Tentar novamente</button>
    </div>

    <template v-else-if="metrics">
      <!-- Atalho pra disputas -->
      <button
        type="button"
        @click="router.push('/admin/disputes')"
        class="flex w-full items-center justify-between gap-3 rounded-2xl border p-5 text-left transition-colors"
        :class="disputasAbertasTotal > 0
          ? 'border-semantic-error/25 bg-semantic-error/[0.04] hover:bg-semantic-error/[0.08]'
          : 'border-hairline bg-surface-1/60 hover:bg-surface-2'"
      >
        <span class="flex items-center gap-3">
          <span class="grid size-10 place-items-center rounded-xl" :class="disputasAbertasTotal > 0 ? 'bg-semantic-error/10 text-semantic-error' : 'bg-surface-3 text-ink-subtle'">
            <ShieldAlert :size="18" />
          </span>
          <span>
            <span class="block font-bold text-ink">Disputas de torneio</span>
            <span class="block text-body-sm text-ink-subtle">
              {{ disputasAbertasTotal > 0 ? `${disputasAbertasTotal} aberta(s) esperando resolução` : 'Nenhuma disputa aberta agora' }}
            </span>
          </span>
        </span>
        <ChevronRight :size="18" class="shrink-0 text-ink-tertiary" />
      </button>

      <!-- Financeiro -->
      <section>
        <h2 class="mb-4 text-eyebrow uppercase tracking-widest text-accent">Financeiro</h2>
        <div class="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-4">
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-primary/10 text-primary"><Wallet :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Saldo disponível (todos)</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.financeiro.saldo_disponivel_total) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-accent/10 text-accent"><Lock :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Saldo travado (em jogo)</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.financeiro.saldo_travado_total) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-semantic-success/10 text-semantic-success"><ArrowDownToLine :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Total depositado</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.financeiro.total_depositado) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-surface-3 text-ink-subtle"><ArrowUpFromLine :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Total sacado</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.financeiro.total_sacado) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-semantic-success/10 text-semantic-success"><Trophy :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Total pago em prêmios</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.financeiro.total_premios_pagos) }}</p>
          </div>
          <div class="rounded-2xl border border-primary/25 bg-primary/[0.06] p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-primary/15 text-primary"><Percent :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Receita (rake) — Desafios</p>
            <p class="mt-1 font-display text-xl font-bold text-primary">{{ fmtBRL(metrics.financeiro.total_rake_desafios) }}</p>
          </div>
          <div class="rounded-2xl border border-primary/25 bg-primary/[0.06] p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-primary/15 text-primary"><Percent :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Receita (rake) — Torneios</p>
            <p class="mt-1 font-display text-xl font-bold text-primary">{{ fmtBRL(metrics.financeiro.total_rake_torneios) }}</p>
          </div>
        </div>

        <div class="mt-4 rounded-2xl border border-hairline bg-surface-1/60 p-5">
          <p class="mb-3 text-body-sm font-semibold text-ink">De onde vem o saldo travado</p>
          <!-- Duas cores neutras-vs-lime (não accent/primary, que são o mesmo
               tom nesta identidade mono-lime — usar os dois juntos aqui deixava
               a barra parecendo uma cor sólida só). -->
          <div class="flex h-3 overflow-hidden rounded-full bg-surface-3">
            <div
              class="h-full bg-ink-tertiary"
              :style="{ width: (metrics.financeiro.travado_em_desafios + metrics.financeiro.travado_em_torneios_online) > 0
                ? (metrics.financeiro.travado_em_desafios / (metrics.financeiro.travado_em_desafios + metrics.financeiro.travado_em_torneios_online) * 100) + '%'
                : '50%' }"
            ></div>
            <div class="h-full bg-primary flex-1"></div>
          </div>
          <div class="mt-2 flex justify-between text-caption text-ink-subtle">
            <span class="inline-flex items-center gap-1.5"><span class="size-2 rounded-full bg-ink-tertiary"></span> Desafios — {{ fmtBRL(metrics.financeiro.travado_em_desafios) }}</span>
            <span class="inline-flex items-center gap-1.5"><span class="size-2 rounded-full bg-primary"></span> Torneios online — {{ fmtBRL(metrics.financeiro.travado_em_torneios_online) }}</span>
          </div>
        </div>
      </section>

      <!-- Desafios -->
      <section>
        <h2 class="mb-4 text-eyebrow uppercase tracking-widest text-accent">Desafios (X1)</h2>
        <div class="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <span class="mb-2 grid size-9 place-items-center rounded-lg bg-surface-3 text-ink-subtle"><Swords :size="18" /></span>
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Total</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.desafios.total) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Abertos</p>
            <p class="mt-1 font-display text-xl font-bold text-semantic-success">{{ fmtNum(metrics.desafios.abertos) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Em andamento</p>
            <p class="mt-1 font-display text-xl font-bold text-accent">{{ fmtNum(metrics.desafios.em_andamento) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Concluídos</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.desafios.concluidos) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Em disputa</p>
            <p class="mt-1 font-display text-xl font-bold text-semantic-error">{{ fmtNum(metrics.desafios.em_disputa) }}</p>
          </div>
          <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
            <p class="text-caption uppercase tracking-wider text-ink-tertiary">Aposta média</p>
            <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.desafios.aposta_media) }}</p>
          </div>
        </div>
      </section>

      <!-- Torneios -->
      <section class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div>
          <h2 class="mb-4 text-eyebrow uppercase tracking-widest text-accent">Torneios Locais</h2>
          <div class="grid grid-cols-3 gap-4">
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Total</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.torneios_locais.total) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Ao vivo</p>
              <p class="mt-1 font-display text-xl font-bold text-accent">{{ fmtNum(metrics.torneios_locais.em_andamento) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Concluídos</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.torneios_locais.concluidos) }}</p>
            </div>
          </div>
        </div>

        <div>
          <h2 class="mb-4 text-eyebrow uppercase tracking-widest text-accent">Torneios Online Pagos</h2>
          <div class="grid grid-cols-3 gap-4">
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Total</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.torneios_online.total) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Inscrições abertas</p>
              <p class="mt-1 font-display text-xl font-bold text-semantic-success">{{ fmtNum(metrics.torneios_online.inscricoes_abertas) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Ao vivo</p>
              <p class="mt-1 font-display text-xl font-bold text-accent">{{ fmtNum(metrics.torneios_online.em_andamento) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Concluídos</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.torneios_online.concluidos) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Cancelados</p>
              <p class="mt-1 font-display text-xl font-bold text-ink-tertiary">{{ fmtNum(metrics.torneios_online.cancelados) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Inscrição média</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtBRL(metrics.torneios_online.taxa_inscricao_media) }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Usuários e Disputas -->
      <section class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div>
          <h2 class="mb-4 text-eyebrow uppercase tracking-widest text-accent">Usuários</h2>
          <div class="grid grid-cols-3 gap-4">
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <span class="mb-2 grid size-9 place-items-center rounded-lg bg-surface-3 text-ink-subtle"><Users :size="18" /></span>
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Cadastrados</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.usuarios.total) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Já jogaram</p>
              <p class="mt-1 font-display text-xl font-bold text-primary">{{ fmtNum(metrics.usuarios.jogadores_ativos) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Fair Play médio</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ metrics.usuarios.fair_play_medio.toFixed(2) }}</p>
            </div>
          </div>
        </div>

        <div>
          <h2 class="mb-4 text-eyebrow uppercase tracking-widest text-accent">Disputas (histórico)</h2>
          <div class="grid grid-cols-3 gap-4">
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Desafios em disputa</p>
              <p class="mt-1 font-display text-xl font-bold text-semantic-error">{{ fmtNum(metrics.disputas.desafios_em_disputa) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Torneios em disputa</p>
              <p class="mt-1 font-display text-xl font-bold text-semantic-error">{{ fmtNum(metrics.disputas.torneios_em_disputa) }}</p>
            </div>
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-5">
              <p class="text-caption uppercase tracking-wider text-ink-tertiary">Resolvidas</p>
              <p class="mt-1 font-display text-xl font-bold text-ink">{{ fmtNum(metrics.disputas.resolvidas_total) }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Preferências -->
      <section class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6">
          <h3 class="mb-4 flex items-center gap-2 text-body-sm font-bold text-ink"><Gamepad2 :size="16" class="text-primary" /> Jogos mais populares</h3>
          <div v-if="metrics.preferencias.jogos_populares.length === 0" class="text-body-sm text-ink-subtle">Sem dados ainda.</div>
          <div v-else class="space-y-3">
            <div v-for="item in metrics.preferencias.jogos_populares" :key="item.label">
              <div class="mb-1 flex justify-between text-body-sm">
                <span class="text-ink">{{ item.label }}</span>
                <span class="font-semibold text-ink-subtle">{{ item.total }}</span>
              </div>
              <div class="h-2 overflow-hidden rounded-full bg-surface-3">
                <div class="h-full rounded-full bg-primary" :style="{ width: barPct(item.total, maxPref(metrics.preferencias.jogos_populares)) + '%' }"></div>
              </div>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6">
          <h3 class="mb-4 flex items-center gap-2 text-body-sm font-bold text-ink"><Gamepad2 :size="16" class="text-accent" /> Plataformas mais usadas</h3>
          <div v-if="metrics.preferencias.plataformas_populares.length === 0" class="text-body-sm text-ink-subtle">Sem dados ainda.</div>
          <div v-else class="space-y-3">
            <div v-for="item in metrics.preferencias.plataformas_populares" :key="item.label">
              <div class="mb-1 flex justify-between text-body-sm">
                <span class="text-ink">{{ item.label }}</span>
                <span class="font-semibold text-ink-subtle">{{ item.total }}</span>
              </div>
              <div class="h-2 overflow-hidden rounded-full bg-surface-3">
                <div class="h-full rounded-full bg-accent" :style="{ width: barPct(item.total, maxPref(metrics.preferencias.plataformas_populares)) + '%' }"></div>
              </div>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6">
          <h3 class="mb-4 flex items-center gap-2 text-body-sm font-bold text-ink"><Award :size="16" class="text-primary" /> Tamanho de torneio preferido</h3>
          <div v-if="tamanhoOrdenado.length === 0" class="text-body-sm text-ink-subtle">Sem dados ainda.</div>
          <div v-else class="space-y-3">
            <div v-for="item in tamanhoOrdenado" :key="item.label">
              <div class="mb-1 flex justify-between text-body-sm">
                <span class="text-ink">{{ item.label }}</span>
                <span class="font-semibold text-ink-subtle">{{ item.total }}</span>
              </div>
              <div class="h-2 overflow-hidden rounded-full bg-surface-3">
                <div class="h-full rounded-full bg-primary" :style="{ width: barPct(item.total, maxPref(tamanhoOrdenado)) + '%' }"></div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>
