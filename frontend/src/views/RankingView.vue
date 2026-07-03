<script setup lang="ts">
import { ref, computed } from 'vue'
import { Info, Star, Crown, Medal } from '@lucide/vue'

const filter = ref('all') // 'all', 'PS5', 'XBOX', 'PC'

// Gerando 150 jogadores mockados dinamicamente
const names = ['CarlosFC', 'MateusPro', 'Thiago', 'RafaelBR', 'Lucas_Gamer', 'JoaoP', 'Felipe_X1', 'Alex_FIFA', 'Gustavo_Pro', 'Leo_BR', 'Vini', 'Edu_Sports', 'Henrique', 'Breno', 'Caio_Fut', 'Daniel', 'Victor_Pro', 'Arthur_BR', 'Igor', 'Samuel_X1', 'Gabriel', 'Bruno_FPS', 'Diego', 'Marcelo_G', 'Fernando', 'Rodrigo_Play', 'Andre', 'Renato_BR', 'Luciano', 'Marcos_99']
const platforms = ['PS5', 'XBOX', 'PC']
const games = ['EA FC 25', 'eFootball']

const rawData = []

// Inserindo os Top 3 fixos para ter certeza que o pódio fica coerente
rawData.push({ name: 'CarlosFC_10', game: 'EA FC 25', platform: 'PS5', wins: 180, losses: 15, rating: 4.9 })
rawData.push({ name: 'MateusPro_99', game: 'eFootball', platform: 'XBOX', wins: 165, losses: 18, rating: 4.8 })
rawData.push({ name: 'ThiagoBR', game: 'EA FC 25', platform: 'PC', wins: 150, losses: 22, rating: 4.7 })

for (let i = 3; i < 150; i++) {
    const wins = Math.floor(Math.random() * 120) + 10
    const losses = Math.floor(Math.random() * 60) + 5
    const baseRating = (Math.random() * (4.6 - 3.0) + 3.0).toFixed(1)

    rawData.push({
        name: `${names[i % names.length]}_${Math.floor(Math.random() * 999)}`,
        game: games[i % games.length],
        platform: platforms[i % platforms.length],
        wins: wins,
        losses: losses,
        rating: parseFloat(baseRating)
    })
}

const enrichedData = rawData.map(player => {
    const totalMatches = player.wins + player.losses
    const winRate = totalMatches > 0 ? parseFloat(((player.wins / totalMatches) * 100).toFixed(1)) : 0.0
    const netWins = player.wins - player.losses
    return { ...player, winRate, netWins }
})

const filteredRanking = computed(() => {
    let list = enrichedData
    if (filter.value !== 'all') {
        list = enrichedData.filter(p => p.platform === filter.value)
    }
    // Reordenar e limitar ao Top 20. Critérios: 1. Vitórias, 2. Win Rate, 3. Menos Derrotas
    return list.sort((a, b) => b.wins - a.wins || b.winRate - a.winRate || a.losses - b.losses).slice(0, 20)
})

// Refs dedicadas pro pódio: o template só renderiza esse bloco quando
// filteredRanking.length >= 3, mas o TS não enxerga essa garantia num
// acesso por índice — resolvendo aqui em vez de espalhar `!` no template.
const podiumFirst = computed(() => filteredRanking.value[0]!)
const podiumSecond = computed(() => filteredRanking.value[1]!)
const podiumThird = computed(() => filteredRanking.value[2]!)

const others = computed(() => filteredRanking.value.slice(3))

/* ── Pódio: cartas estilo "cartão premium" (ouro/prata/bronze) ── */
const podiumTheme: Record<1 | 2 | 3, { ring: string; border: string; glow: string; text: string; badge: string; icon: typeof Crown }> = {
    1: {
        ring: 'from-amber-300 via-amber-400 to-amber-600',
        border: 'border-amber-400/30',
        glow: 'shadow-[0_0_60px_-16px_rgba(251,191,36,0.55)]',
        text: 'text-amber-300',
        badge: 'bg-gradient-to-br from-amber-300 to-amber-600 text-amber-950',
        icon: Crown,
    },
    2: {
        ring: 'from-zinc-200 via-zinc-300 to-zinc-500',
        border: 'border-zinc-300/25',
        glow: 'shadow-[0_0_40px_-18px_rgba(212,212,216,0.5)]',
        text: 'text-zinc-300',
        badge: 'bg-gradient-to-br from-zinc-200 to-zinc-400 text-zinc-900',
        icon: Medal,
    },
    3: {
        ring: 'from-orange-300 via-orange-500 to-orange-800',
        border: 'border-orange-600/30',
        glow: 'shadow-[0_0_40px_-18px_rgba(194,120,3,0.5)]',
        text: 'text-orange-400',
        badge: 'bg-gradient-to-br from-orange-400 to-orange-700 text-orange-950',
        icon: Medal,
    },
}

const podiumTop3 = computed(() => [
    { rank: 1 as const, player: podiumFirst.value, theme: podiumTheme[1] },
    { rank: 2 as const, player: podiumSecond.value, theme: podiumTheme[2] },
    { rank: 3 as const, player: podiumThird.value, theme: podiumTheme[3] },
])

const filterTabs = [
    { key: 'all', label: 'Todos', activeClass: 'bg-primary text-canvas shadow-glow-primary' },
    { key: 'PS5', label: 'PS5', activeClass: 'bg-[#00439C] text-white shadow-md shadow-[#00439C]/30' },
    { key: 'XBOX', label: 'XBOX', activeClass: 'bg-[#107C10] text-white shadow-md shadow-[#107C10]/30' },
    { key: 'PC', label: 'PC', activeClass: 'bg-ink text-canvas shadow-md shadow-black/30' },
]
</script>

<template>
  <div class="w-full space-y-10 px-6 py-8 lg:px-20">
    <!-- Cabeçalho e Filtros -->
    <div class="space-y-6">
        <div>
            <span class="text-eyebrow uppercase tracking-widest text-accent">Ranking nacional</span>
            <h1 class="mt-2 font-display text-headline font-black uppercase tracking-tight text-ink">Classificação</h1>
            <p class="mt-1 text-body-sm text-ink-subtle">O ranking é o seu palco. Vitória vale posição — quem só fala fica lá embaixo.</p>
        </div>

        <div class="flex items-start gap-3 rounded-xl border border-accent/20 bg-accent/10 p-4 text-body-sm text-ink">
            <Info :size="20" class="mt-0.5 shrink-0 text-accent" />
            <p><strong class="text-ink">Como funciona o Ranking?</strong> A classificação oficial da ArenaX1 prioriza jogadores pelo total de <strong>Vitórias</strong>. Em caso de empate, avaliamos a <strong>Taxa de Vitória (%)</strong> e o <strong>menor número de Derrotas</strong> (Saldo Positivo).</p>
        </div>

        <div class="flex gap-2 overflow-x-auto pb-2">
            <button
                v-for="tab in filterTabs"
                :key="tab.key"
                @click="filter = tab.key"
                :class="filter === tab.key ? tab.activeClass : 'border border-hairline-strong bg-surface-1/60 text-ink-subtle hover:bg-surface-2 hover:text-ink'"
                class="inline-flex cursor-pointer items-center whitespace-nowrap rounded-full px-5 py-2.5 text-body-sm font-semibold transition-all duration-200"
            >
                {{ tab.label }}
            </button>
        </div>
    </div>

    <!-- Se não houver jogadores para o filtro -->
    <div v-if="filteredRanking.length === 0" class="py-20 text-center text-ink-subtle">
        Nenhum jogador encontrado para esta plataforma.
    </div>

    <!-- Pódio -->
    <div v-if="filteredRanking.length >= 3" class="relative mb-8 mt-10 px-1">
        <p class="mb-5 text-center text-[11px] font-bold uppercase tracking-[0.2em] text-ink-tertiary">Top 3 da temporada</p>

        <div class="pointer-events-none absolute left-1/2 top-6 -z-10 h-64 w-64 -translate-x-1/2 rounded-full bg-amber-500/10 blur-[90px]"></div>

        <div class="grid grid-cols-1 gap-5 sm:grid-cols-3 sm:items-center">
            <div
                v-for="p in podiumTop3"
                :key="p.rank"
                class="group relative flex flex-col overflow-hidden rounded-2xl border bg-gradient-to-br from-surface-2 to-surface-1 p-5 backdrop-blur transition-all duration-300 hover:-translate-y-1.5"
                :class="[
                    p.theme.border,
                    p.theme.glow,
                    p.rank === 1 ? 'order-1 z-10 sm:order-2 sm:-translate-y-3 sm:scale-[1.04]' : p.rank === 2 ? 'order-2 sm:order-1' : 'order-3 sm:order-3',
                ]"
            >
                <!-- Número embutido (marca d'água) -->
                <span class="pointer-events-none absolute -right-2 -top-8 select-none font-display text-[112px] font-black leading-none text-white/[0.04]">{{ p.rank }}</span>

                <!-- Topo: posição + medalha -->
                <div class="flex items-center justify-between">
                    <span class="flex size-7 items-center justify-center rounded-full text-xs font-black shadow-md" :class="p.theme.badge">{{ p.rank }}</span>
                    <component :is="p.theme.icon" :size="p.rank === 1 ? 22 : 18" :class="p.theme.text" :fill="p.rank === 1 ? 'currentColor' : 'none'" />
                </div>

                <!-- Avatar + nome -->
                <div class="mt-5 flex items-center gap-3">
                    <div class="rounded-full bg-gradient-to-br p-[2px]" :class="p.theme.ring">
                        <div class="grid size-11 place-items-center rounded-full bg-surface-1 text-sm font-bold uppercase text-ink">
                            {{ p.player.name.substring(0, 2) }}
                        </div>
                    </div>
                    <div class="min-w-0">
                        <p class="truncate text-base font-bold text-ink">{{ p.player.name }}</p>
                        <p class="text-[10px] font-semibold uppercase tracking-widest text-ink-tertiary">{{ p.player.platform }}</p>
                    </div>
                </div>

                <!-- Estatísticas estilo "cartão" -->
                <div class="mt-5 flex items-end justify-between border-t border-white/5 pt-4 font-mono">
                    <div>
                        <p class="text-[9px] uppercase tracking-widest text-ink-tertiary">Cartel</p>
                        <p class="text-sm font-bold tracking-wider">
                            <span class="text-semantic-success">{{ p.player.wins }}V</span>
                            <span class="text-ink-tertiary"> · </span>
                            <span class="text-semantic-error">{{ p.player.losses }}D</span>
                            <span
                                class="ml-1.5 rounded px-1.5 py-0.5 text-[10px] font-bold"
                                :class="p.player.netWins > 0 ? 'bg-semantic-success/10 text-semantic-success' : 'bg-surface-3 text-ink-tertiary'"
                            >{{ p.player.netWins > 0 ? '+' : '' }}{{ p.player.netWins }}</span>
                        </p>
                    </div>
                    <div class="flex items-center gap-1" :class="p.theme.text">
                        <Star :size="14" fill="currentColor" />
                        <span class="text-sm font-black">{{ p.player.rating.toFixed(1) }}</span>
                    </div>
                </div>

                <!-- Brilho ao passar o mouse -->
                <div class="pointer-events-none absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/[0.07] to-transparent transition-transform duration-700 ease-out group-hover:translate-x-full"></div>
            </div>
        </div>
    </div>

    <!-- Resto da Tabela -->
    <div v-if="others.length > 0" class="w-full">
        <div class="overflow-hidden rounded-2xl border border-hairline bg-surface-1/60 backdrop-blur">
            <div class="overflow-x-auto">
                <table class="w-full whitespace-nowrap text-left text-body-sm">
                    <thead class="bg-surface-2 text-caption font-bold uppercase tracking-wider text-ink-tertiary">
                        <tr>
                            <th class="w-16 px-6 py-4 text-center">Pos</th>
                            <th class="px-6 py-4">Jogador</th>
                            <th class="px-6 py-4">Plataforma</th>
                            <th class="px-6 py-4 text-center">Cartel (Vitórias/Derrotas)</th>
                            <th class="px-6 py-4 text-center">Taxa de Vitória</th>
                            <th class="px-6 py-4 text-right">Nota</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-hairline">
                        <tr v-for="(player, index) in others" :key="player.name" class="transition-colors hover:bg-surface-2/60">
                            <td class="px-6 py-4">
                                <div class="mx-auto flex size-8 items-center justify-center rounded-full bg-surface-3 text-sm font-bold text-ink-subtle">
                                    {{ index + 4 }}
                                </div>
                            </td>
                            <td class="px-6 py-4">
                                <div class="flex items-center gap-3">
                                    <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary/10 font-bold uppercase text-primary">
                                        {{ player.name.charAt(0) }}
                                    </div>
                                    <div>
                                        <p class="text-base font-bold text-ink">{{ player.name }}</p>
                                        <p class="text-caption text-ink-tertiary">{{ player.game }}</p>
                                    </div>
                                </div>
                            </td>
                            <td class="px-6 py-4 text-caption font-semibold uppercase tracking-widest text-ink-subtle">
                                {{ player.platform }}
                            </td>
                            <td class="px-6 py-4 text-center">
                                <span class="font-bold text-semantic-success">{{ player.wins }}V</span>
                                <span class="mx-1 text-ink-tertiary">-</span>
                                <span class="font-bold text-semantic-error">{{ player.losses }}D</span>
                                <span class="ml-2 rounded px-1.5 py-0.5 text-[10px] font-bold" :class="player.netWins > 0 ? 'bg-semantic-success/10 text-semantic-success' : 'bg-surface-3 text-ink-tertiary'">{{ player.netWins > 0 ? '+' : '' }}{{ player.netWins }}</span>
                            </td>
                            <td class="px-6 py-4 text-center">
                                <div class="mx-auto mb-1 h-1.5 w-full max-w-[80px] rounded-full bg-surface-3">
                                    <div class="h-1.5 rounded-full bg-semantic-success" :style="{ width: player.winRate + '%' }"></div>
                                </div>
                                <span class="text-caption font-bold text-ink-subtle">{{ player.winRate }}%</span>
                            </td>
                            <td class="px-6 py-4 text-right">
                                <div class="inline-flex items-center gap-1.5">
                                    <Star :size="16" fill="currentColor" class="text-amber-400" />
                                    <span class="font-black text-ink-muted">{{ player.rating.toFixed(1) }}</span>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
  </div>
</template>
