<script setup lang="ts">
import { ref, computed } from 'vue'
import { List, Calendar, History, Lock, Gamepad2, CalendarDays, Users, Trophy, SearchX, Plus } from '@lucide/vue'
import { vReveal } from '@/composables/useReveal'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

const filter = ref('all') // 'all', 'proximos', 'concluidos'

/* ── Mock (ainda não existe backend de torneios — ver TODO.md "Torneio de Sofá") ── */
const allTournaments = ref([
    { id: 1, title: 'Copa Final de Semana', game: 'EA FC 26', prize: 80, entryFee: 10, date: 'Hoje, 20:00', enrolled: 4, maxPlayers: 8, status: 'proximo', private: false },
    { id: 2, title: 'Liga Noturna eFootball', game: 'eFootball', prize: 150, entryFee: 15, date: 'Amanhã, 22:00', enrolled: 12, maxPlayers: 16, status: 'proximo', private: false },
    { id: 3, title: 'Torneio Fechado NDAMBA', game: 'EA FC 25', prize: 0, entryFee: 0, date: '25 Nov, 19:00', enrolled: 8, maxPlayers: 8, status: 'proximo', private: true },
    { id: 4, title: 'Supercopa de Sexta', game: 'EA FC 26', prize: 500, entryFee: 25, date: 'Sexta, 21:00', enrolled: 16, maxPlayers: 32, status: 'proximo', private: false },
    { id: 5, title: 'Campeonato Mensal Pro', game: 'eFootball', prize: 1000, entryFee: 50, date: 'Dia 30, 15:00', enrolled: 45, maxPlayers: 64, status: 'proximo', private: false },
    { id: 6, title: 'Taça dos Campeões', game: 'EA FC 25', prize: 200, entryFee: 20, date: 'Ontem, 20:00', enrolled: 16, maxPlayers: 16, status: 'concluido', private: false },
    { id: 7, title: 'Liga Amadora (Série B)', game: 'EA FC 25', prize: 40, entryFee: 5, date: 'Sábado passado', enrolled: 8, maxPlayers: 8, status: 'concluido', private: false },
    { id: 8, title: 'X1 da Madrugada', game: 'eFootball', prize: 30, entryFee: 5, date: 'Domingo passado', enrolled: 8, maxPlayers: 8, status: 'concluido', private: false },
    { id: 9, title: 'Invitational de Inverno', game: 'EA FC 26', prize: 0, entryFee: 0, date: 'Semana passada', enrolled: 16, maxPlayers: 16, status: 'concluido', private: true },
    { id: 10, title: 'Copa Novatos', game: 'EA FC 25', prize: 50, entryFee: 5, date: 'Amanhã, 14:00', enrolled: 6, maxPlayers: 16, status: 'proximo', private: false },
    { id: 11, title: 'Desafio dos 100', game: 'eFootball', prize: 100, entryFee: 10, date: 'Hoje, 23:30', enrolled: 10, maxPlayers: 16, status: 'proximo', private: false },
    { id: 12, title: 'Masters EA FC', game: 'EA FC 26', prize: 400, entryFee: 40, date: 'Mês passado', enrolled: 16, maxPlayers: 16, status: 'concluido', private: false },
])

const filterTabs = computed(() => [
    { key: 'all', label: 'Todos', icon: List, count: allTournaments.value.length },
    { key: 'proximos', label: 'Próximos', icon: Calendar, count: allTournaments.value.filter(t => t.status === 'proximo').length },
    { key: 'concluidos', label: 'Concluídos', icon: History, count: allTournaments.value.filter(t => t.status === 'concluido').length },
])

const filteredTournaments = computed(() => {
    if (filter.value === 'proximos') return allTournaments.value.filter(t => t.status === 'proximo')
    if (filter.value === 'concluidos') return allTournaments.value.filter(t => t.status === 'concluido')
    return allTournaments.value
})
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-8">
    <!-- Cabeçalho -->
    <div class="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
        <div>
            <span class="text-eyebrow uppercase tracking-widest text-accent">Competições oficiais</span>
            <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Torneios</h1>
            <p class="mt-1 text-body-sm text-ink-subtle">Mata-mata com premiação de verdade. Entra, elimina geral e leva o pote.</p>
        </div>
        <router-link
            :to="authStore.user ? '/create-tournament' : '/register'"
            class="group inline-flex w-fit items-center justify-center gap-2 rounded-xl bg-primary px-6 py-3 text-button font-semibold text-canvas no-underline shadow-glow-primary transition-all duration-200 hover:bg-primary-hover"
        >
            <Plus :size="18" class="transition-transform duration-200 group-hover:rotate-90" />
            {{ authStore.user ? 'Criar Torneio Local' : 'Criar conta para criar torneio' }}
        </router-link>
    </div>

    <!-- Filtros -->
    <div class="sticky top-16 z-40 -mx-6 px-6 pb-4 pt-2 md:top-[76px] lg:-mx-20 lg:px-20">
        <div class="custom-scrollbar flex gap-2 overflow-x-auto pb-1">
            <button
                v-for="tab in filterTabs"
                :key="tab.key"
                @click="filter = tab.key"
                :class="filter === tab.key
                    ? 'border-primary/40 bg-primary/15 text-primary shadow-glow-primary'
                    : 'border-hairline-strong bg-surface-1/60 text-ink-subtle hover:bg-surface-2 hover:text-ink'"
                class="relative inline-flex shrink-0 cursor-pointer items-center gap-1.5 whitespace-nowrap rounded-full border px-4 py-2 text-body-sm font-semibold transition-all duration-200"
            >
                <component :is="tab.icon" :size="14" />
                {{ tab.label }}
                <span
                    v-if="tab.count > 0"
                    class="rounded-full bg-surface-3 px-1.5 py-0.5 text-[10px] font-bold tabular-nums text-ink-subtle"
                    :class="filter === tab.key ? 'bg-primary/20 text-primary' : ''"
                >{{ tab.count }}</span>
            </button>
        </div>
    </div>

    <!-- Estado vazio -->
    <div v-if="filteredTournaments.length === 0" class="flex flex-col items-center gap-3 py-24 text-center">
        <span class="grid size-14 place-items-center rounded-2xl bg-surface-2 text-ink-tertiary">
            <SearchX :size="26" />
        </span>
        <p class="font-semibold text-ink">Nenhum torneio nesse filtro</p>
        <p class="max-w-xs text-body-sm text-ink-subtle">Troca o filtro ou monta o teu mata-mata e chama a galera pra briga.</p>
    </div>

    <!-- Grid de torneios -->
    <div v-else class="grid grid-cols-1 gap-5 lg:grid-cols-2 xl:grid-cols-3">
        <router-link
            v-for="(t, i) in filteredTournaments"
            :key="t.id"
            :to="'/torneios/' + t.id"
            v-reveal="`${(i % 6) * 60}ms`"
            class="glow-border group flex flex-col overflow-hidden rounded-2xl border border-hairline bg-surface-1/60 backdrop-blur transition-all duration-300 hover:-translate-y-0.5 hover:border-hairline-strong no-underline"
            :class="t.status === 'concluido' ? 'opacity-70' : ''"
        >
            <!-- Banner -->
            <div class="relative flex h-28 items-center justify-center overflow-hidden border-b border-hairline bg-surface-2 p-5">
                <Trophy :size="80" class="pointer-events-none absolute -right-4 -top-4 text-ink/[0.04]" />
                <span v-if="t.private" class="absolute left-3 top-3 grid size-8 place-items-center rounded-full border border-hairline-strong bg-surface-3 text-ink-tertiary">
                    <Lock :size="14" />
                </span>
                <div class="z-10 text-center">
                    <h3 class="max-w-[220px] truncate font-display text-lg font-bold text-ink">{{ t.title }}</h3>
                    <span class="mt-2 inline-flex items-center gap-1.5 rounded-full border border-accent/30 bg-accent/10 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-accent">
                        <Gamepad2 :size="12" /> {{ t.game }}
                    </span>
                </div>
            </div>

            <!-- Corpo -->
            <div class="flex flex-col gap-4 p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-caption uppercase tracking-widest text-ink-tertiary">Premiação</p>
                        <p class="text-lg font-bold" :class="t.status === 'concluido' ? 'text-ink-subtle' : 'text-semantic-success'">{{ t.private ? 'Privada' : `R$ ${t.prize.toFixed(2)}` }}</p>
                    </div>
                    <div class="text-right">
                        <p class="text-caption uppercase tracking-widest text-ink-tertiary">Inscrição</p>
                        <p class="text-body-sm font-semibold text-ink">{{ t.private ? '—' : `R$ ${t.entryFee.toFixed(2)}` }}</p>
                    </div>
                </div>

                <div class="flex flex-col gap-2 rounded-xl border border-hairline bg-surface-2 p-4">
                    <div class="flex items-center justify-between text-body-sm">
                        <span class="inline-flex items-center gap-1.5 text-ink-tertiary"><CalendarDays :size="14" /> Data</span>
                        <span class="font-medium text-ink">{{ t.date }}</span>
                    </div>
                    <div class="flex items-center justify-between text-body-sm">
                        <span class="inline-flex items-center gap-1.5 text-ink-tertiary"><Users :size="14" /> Vagas</span>
                        <span class="font-bold" :class="t.status === 'concluido' ? 'text-ink-tertiary' : 'text-accent'">{{ t.enrolled }}/{{ t.maxPlayers }}</span>
                    </div>
                </div>

                <div
                    class="rounded-xl py-2.5 text-center text-button font-semibold transition-colors duration-200"
                    :class="t.status === 'concluido' ? 'bg-surface-3 text-ink-tertiary' : 'bg-surface-3 text-ink-subtle group-hover:bg-primary group-hover:text-canvas'"
                >
                    {{ t.status === 'concluido' ? 'Ver Chaveamento' : 'Ver Detalhes' }}
                </div>
            </div>
        </router-link>
    </div>
  </div>
</template>
