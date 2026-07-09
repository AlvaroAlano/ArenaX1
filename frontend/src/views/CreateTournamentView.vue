<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { Trophy, Users, UserPlus, Shuffle, Info, Lock, Coins, CalendarClock, Gamepad2 } from '@lucide/vue'
import { useRouter } from 'vue-router'
import { api } from '@/services/api'
import { GAME_OPTIONS } from '@/constants/games'

const router = useRouter()

const mode = ref<'local' | 'online'>('local')

const title = ref('')
const game = ref(GAME_OPTIONS[0])
const maxPlayers = ref(4)
const participantNames = ref<string[]>(['', '', '', ''])
const randomizeTeams = ref(false)
const teamNames = ref<string[]>(['', '', '', ''])
const isSubmitting = ref(false)
const errorMsg = ref('')

// Redimensiona os arrays de nomes conforme a contagem de jogadores escolhida,
// preservando o que já foi digitado.
watch(maxPlayers, (n) => {
    participantNames.value = Array.from({ length: n }, (_, i) => participantNames.value[i] || '')
    teamNames.value = Array.from({ length: n }, (_, i) => teamNames.value[i] || '')
})

const isValid = computed(() => {
    if (!title.value.trim() || !game.value) return false
    if (participantNames.value.length !== maxPlayers.value) return false
    if (participantNames.value.some(n => !n.trim())) return false
    if (randomizeTeams.value && teamNames.value.some(t => !t.trim())) return false
    return true
})

const submitTournament = async () => {
    if (!isValid.value) return
    isSubmitting.value = true
    errorMsg.value = ''

    try {
        const tournament = await api.post<{ id: string }>('/api/tournaments/create', {
            title: title.value.trim(),
            game: game.value,
            max_players: maxPlayers.value,
            participant_names: participantNames.value.map(n => n.trim()),
            randomize_teams: randomizeTeams.value,
            team_names: randomizeTeams.value ? teamNames.value.map(t => t.trim()) : undefined,
        })
        router.push(`/my-tournaments/${tournament.id}`)
    } catch (err: any) {
        errorMsg.value = err.message || 'Erro ao criar o torneio.'
    } finally {
        isSubmitting.value = false
    }
}

/* ── Torneio Online Pago ── */
const oTitle = ref('')
const oGame = ref(GAME_OPTIONS[0])
const oPlatform = ref('PS5')
const oMaxPlayers = ref(4)
const oEntryFee = ref(10)
const oDeadline = ref('') // valor cru do <input type="datetime-local">
const oSubmitting = ref(false)
const oErrorMsg = ref('')

// Prazo mínimo selecionável: daqui a 1h, formatado pro input datetime-local (sem timezone).
function toLocalInputValue(d: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
const minDeadline = toLocalInputValue(new Date(Date.now() + 60 * 60 * 1000))

// Tabela de premiação por tamanho de chave (sempre sobre o pote líquido,
// depois do rake de 10% — mesma regra usada no backend, ver
// backend/19_tiered_prize_distribution.sql). 4 jogadores: só o campeão
// leva. 8: top 3. 16: top 4.
const oPrizeBreakdown = computed(() => {
    const pool = oMaxPlayers.value * oEntryFee.value * 0.9
    const table = oMaxPlayers.value === 4
        ? [{ label: '1º Lugar', pct: 1.00 }]
        : oMaxPlayers.value === 8
        ? [{ label: '1º Lugar', pct: 0.55 }, { label: '2º Lugar', pct: 0.30 }, { label: '3º Lugar', pct: 0.15 }]
        : [{ label: '1º Lugar', pct: 0.50 }, { label: '2º Lugar', pct: 0.25 }, { label: '3º Lugar', pct: 0.15 }, { label: '4º Lugar', pct: 0.10 }]
    return table.map(t => ({ ...t, amount: pool * t.pct }))
})

const oIsValid = computed(() => {
    if (!oTitle.value.trim() || !oGame.value || !oPlatform.value) return false
    if (![4, 8, 16].includes(oMaxPlayers.value)) return false
    if (oEntryFee.value < 1) return false
    if (!oDeadline.value) return false
    if (new Date(oDeadline.value).getTime() <= Date.now()) return false
    return true
})

const submitOnlineTournament = async () => {
    if (!oIsValid.value) return
    oSubmitting.value = true
    oErrorMsg.value = ''

    try {
        const tournament = await api.post<{ id: string }>('/api/tournaments/online/create', {
            title: oTitle.value.trim(),
            game: oGame.value,
            platform: oPlatform.value,
            max_players: oMaxPlayers.value,
            entry_fee: oEntryFee.value,
            registration_deadline: new Date(oDeadline.value).toISOString(),
        })
        router.push(`/tournaments/${tournament.id}`)
    } catch (err: any) {
        oErrorMsg.value = err.message || 'Erro ao criar o torneio online.'
    } finally {
        oSubmitting.value = false
    }
}
</script>

<template>
  <div class="flex-1 p-6 lg:p-10 w-full">
    <div class="max-w-2xl mx-auto flex flex-col gap-8">

        <section>
            <h1 class="font-display text-3xl lg:text-4xl font-black uppercase tracking-tight mb-2 text-ink">Criar um Torneio</h1>
            <p class="text-ink-subtle">Junta a galera, monta a chave em segundos e descobre quem é o melhor de verdade.</p>
        </section>

        <!-- Seleção de modo -->
        <section class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <button
                type="button"
                @click="mode = 'local'"
                class="flex flex-col gap-2 rounded-xl border-2 p-4 text-left transition-all"
                :class="mode === 'local' ? 'border-primary bg-primary/10' : 'border-hairline bg-surface-1 hover:border-primary/40'"
            >
                <Users :size="22" :class="mode === 'local' ? 'text-primary' : 'text-ink-tertiary'" />
                <p class="font-bold" :class="mode === 'local' ? 'text-ink' : 'text-ink-subtle'">Torneio Local</p>
                <p class="text-caption text-ink-subtle">Você e seus amigos, no mesmo sofá — chaveamento automático, sem precisar de conta.</p>
            </button>
            <button
                type="button"
                @click="mode = 'online'"
                class="flex flex-col gap-2 rounded-xl border-2 p-4 text-left transition-all"
                :class="mode === 'online' ? 'border-primary bg-primary/10' : 'border-hairline bg-surface-1 hover:border-primary/40'"
            >
                <Trophy :size="22" :class="mode === 'online' ? 'text-primary' : 'text-ink-tertiary'" />
                <p class="font-bold" :class="mode === 'online' ? 'text-ink' : 'text-ink-subtle'">Torneio Online Pago</p>
                <p class="text-caption text-ink-subtle">Inscrição com dinheiro real — jogadores de verdade, prêmio de verdade pro pódio.</p>
            </button>
        </section>

        <form v-if="mode === 'local'" @submit.prevent="submitTournament">

            <!-- Secção 1 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">1</span>
                    <h2 class="text-xl font-bold text-ink">Detalhes do Torneio</h2>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-semibold text-ink mb-1.5">Nome do torneio</label>
                        <input v-model="title" type="text" maxlength="80" placeholder="Ex: Copa da Sala" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all" />
                    </div>
                    <div>
                        <label class="block text-sm font-semibold text-ink mb-1.5">Jogo</label>
                        <select v-model="game" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all">
                            <option v-for="opt in GAME_OPTIONS" :key="opt" :value="opt">{{ opt }}</option>
                        </select>
                    </div>
                </div>
            </section>

            <!-- Secção 2 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">2</span>
                    <h2 class="text-xl font-bold text-ink">Número de Jogadores</h2>
                </div>
                <div class="grid grid-cols-3 gap-3">
                    <label v-for="val in [4, 8, 16]" :key="val" class="cursor-pointer group">
                        <input type="radio" v-model="maxPlayers" :value="val" class="peer sr-only" />
                        <div class="flex flex-col items-center justify-center p-4 rounded-xl border-2 border-hairline bg-surface-1 peer-checked:border-primary peer-checked:bg-primary/10 hover:border-primary/50 transition-all">
                            <span class="text-lg font-bold text-ink">{{ val }}</span>
                        </div>
                    </label>
                </div>
            </section>

            <!-- Secção 3 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">3</span>
                    <h2 class="text-xl font-bold text-ink">Participantes</h2>
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div v-for="(_, i) in participantNames" :key="i" class="relative">
                        <UserPlus :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-ink-subtle" />
                        <input
                            v-model="participantNames[i]"
                            type="text"
                            maxlength="40"
                            :placeholder="`Nome do jogador ${i + 1}`"
                            class="w-full bg-surface-1 border border-hairline text-ink rounded-lg h-12 pl-10 pr-4 focus:ring-2 focus:ring-primary outline-none transition-all"
                        />
                    </div>
                </div>
                <p class="text-[11px] text-ink-subtle flex items-center gap-1">
                    <Info :size="14" />
                    Seus amigos não precisam ter conta na ArenaX1 — é só o nome de cada um.
                </p>
            </section>

            <!-- Secção 4 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">4</span>
                    <h2 class="text-xl font-bold text-ink">Sorteio de Times</h2>
                    <span class="text-xs text-ink-subtle ml-1">(opcional)</span>
                </div>
                <label class="flex cursor-pointer items-center gap-3 rounded-xl border border-hairline bg-surface-1 p-4">
                    <input type="checkbox" v-model="randomizeTeams" class="peer sr-only" />
                    <span class="relative h-6 w-11 shrink-0 rounded-full bg-surface-3 transition-colors peer-checked:bg-primary" :class="randomizeTeams ? 'bg-primary' : ''">
                        <span class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white transition-transform" :class="randomizeTeams ? 'translate-x-5' : ''"></span>
                    </span>
                    <span class="flex items-center gap-2 font-semibold text-ink">
                        <Shuffle :size="18" class="text-primary" />
                        Sortear times para os participantes
                    </span>
                </label>

                <div v-if="randomizeTeams" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div v-for="(_, i) in teamNames" :key="i" class="relative">
                        <Trophy :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-ink-subtle" />
                        <input
                            v-model="teamNames[i]"
                            type="text"
                            maxlength="40"
                            :placeholder="`Nome do time ${i + 1}`"
                            class="w-full bg-surface-1 border border-hairline text-ink rounded-lg h-12 pl-10 pr-4 focus:ring-2 focus:ring-primary outline-none transition-all"
                        />
                    </div>
                </div>
                <p v-if="randomizeTeams" class="text-[11px] text-ink-subtle flex items-center gap-1">
                    <Lock :size="14" />
                    O sorteio é feito no servidor — nem o anfitrião escolhe quem pega qual time.
                </p>
            </section>

            <div class="pt-6 border-t border-hairline">
                <p v-if="errorMsg" class="mb-4 text-center text-sm font-semibold text-semantic-error">{{ errorMsg }}</p>
                <button type="submit" :disabled="!isValid || isSubmitting" class="w-full py-4 rounded-xl bg-primary hover:bg-primary-hover text-canvas font-bold text-lg flex items-center justify-center gap-2 transition-all shadow-lg shadow-primary/20 disabled:opacity-50 disabled:cursor-not-allowed">
                    <Trophy :size="24" v-if="!isSubmitting" />
                    <svg v-if="isSubmitting" class="w-5 h-5 text-canvas animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                    </svg>
                    <span>{{ isSubmitting ? 'A criar...' : 'Criar o Torneio' }}</span>
                </button>
                <p class="text-center text-[10px] text-ink-subtle uppercase tracking-widest mt-4">Torneio local e grátis • A chave é gerada automaticamente</p>
            </div>
        </form>

        <form v-else @submit.prevent="submitOnlineTournament">

            <!-- Secção 1 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">1</span>
                    <h2 class="text-xl font-bold text-ink">Detalhes do Torneio</h2>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-semibold text-ink mb-1.5">Nome do torneio</label>
                        <input v-model="oTitle" type="text" maxlength="80" placeholder="Ex: Copa de Final de Semana" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all" />
                    </div>
                    <div>
                        <label class="block text-sm font-semibold text-ink mb-1.5">Jogo</label>
                        <select v-model="oGame" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all">
                            <option v-for="opt in GAME_OPTIONS" :key="opt" :value="opt">{{ opt }}</option>
                        </select>
                    </div>
                </div>
                <div>
                    <label class="block text-sm font-semibold text-ink mb-1.5 flex items-center gap-1.5"><Gamepad2 :size="16" /> Plataforma</label>
                    <select v-model="oPlatform" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all">
                        <option value="PS5">PS5</option>
                        <option value="Xbox">Xbox</option>
                        <option value="PC">PC</option>
                        <option value="Crossplay">Crossplay</option>
                    </select>
                </div>
            </section>

            <!-- Secção 2 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">2</span>
                    <h2 class="text-xl font-bold text-ink">Número de Vagas</h2>
                </div>
                <div class="grid grid-cols-3 gap-3">
                    <label v-for="val in [4, 8, 16]" :key="val" class="cursor-pointer group">
                        <input type="radio" v-model="oMaxPlayers" :value="val" class="peer sr-only" />
                        <div class="flex flex-col items-center justify-center p-4 rounded-xl border-2 border-hairline bg-surface-1 peer-checked:border-primary peer-checked:bg-primary/10 hover:border-primary/50 transition-all">
                            <span class="text-lg font-bold text-ink">{{ val }}</span>
                        </div>
                    </label>
                </div>
            </section>

            <!-- Secção 3 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">3</span>
                    <h2 class="text-xl font-bold text-ink flex items-center gap-1.5"><Coins :size="18" class="text-primary" /> Taxa de Inscrição</h2>
                </div>
                <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <label v-for="val in [10, 20, 50, 100]" :key="val" class="cursor-pointer group">
                        <input type="radio" v-model="oEntryFee" :value="val" class="peer sr-only" />
                        <div class="flex flex-col items-center justify-center p-4 rounded-xl border-2 border-hairline bg-surface-1 peer-checked:border-primary peer-checked:bg-primary/10 hover:border-primary/50 transition-all">
                            <span class="text-lg font-bold text-ink">R$ {{ val.toFixed(2) }}</span>
                        </div>
                    </label>
                </div>
                <div class="rounded-xl border border-hairline bg-surface-2 p-4 text-body-sm">
                    <div class="flex items-center justify-between text-ink-subtle">
                        <span>Pote total ({{ oMaxPlayers }} × R$ {{ oEntryFee.toFixed(2) }})</span>
                        <span class="font-bold text-ink">R$ {{ (oMaxPlayers * oEntryFee).toFixed(2) }}</span>
                    </div>
                    <div class="mt-1 flex items-center justify-between text-ink-subtle">
                        <span>Premiação líquida (após 10% de comissão da ArenaX1)</span>
                        <span class="font-bold text-semantic-success">R$ {{ (oMaxPlayers * oEntryFee * 0.9).toFixed(2) }}</span>
                    </div>
                    <div class="mt-3 space-y-1 border-t border-hairline pt-3">
                        <div v-for="tier in oPrizeBreakdown" :key="tier.label" class="flex items-center justify-between">
                            <span class="text-ink-subtle">{{ tier.label }} <span class="text-ink-tertiary">({{ (tier.pct * 100).toFixed(0) }}%)</span></span>
                            <span class="font-bold text-ink">R$ {{ tier.amount.toFixed(2) }}</span>
                        </div>
                    </div>
                    <p class="mt-2 text-[11px] text-ink-tertiary">
                        Você (anfitrião) entra pagando a inscrição igual a qualquer jogador.
                    </p>
                </div>
            </section>

            <!-- Secção 4 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">4</span>
                    <h2 class="text-xl font-bold text-ink flex items-center gap-1.5"><CalendarClock :size="18" class="text-primary" /> Prazo de Inscrição</h2>
                </div>
                <input
                    v-model="oDeadline"
                    type="datetime-local"
                    :min="minDeadline"
                    class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all"
                />
                <p class="text-[11px] text-ink-subtle flex items-center gap-1">
                    <Info :size="14" />
                    Se as vagas não completarem até este horário, todo mundo é reembolsado automaticamente e o torneio é cancelado.
                </p>
                <p class="text-[11px] text-ink-subtle flex items-center gap-1">
                    <Lock :size="14" />
                    Quem se inscrever pode desistir e reaver o valor a qualquer momento, exceto nos últimos 30 minutos antes desse prazo.
                </p>
            </section>

            <div class="pt-6 border-t border-hairline">
                <p v-if="oErrorMsg" class="mb-4 text-center text-sm font-semibold text-semantic-error">{{ oErrorMsg }}</p>
                <button type="submit" :disabled="!oIsValid || oSubmitting" class="w-full py-4 rounded-xl bg-primary hover:bg-primary-hover text-canvas font-bold text-lg flex items-center justify-center gap-2 transition-all shadow-lg shadow-primary/20 disabled:opacity-50 disabled:cursor-not-allowed">
                    <Trophy :size="24" v-if="!oSubmitting" />
                    <svg v-if="oSubmitting" class="w-5 h-5 text-canvas animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                    </svg>
                    <span>{{ oSubmitting ? 'A criar...' : 'Criar e Pagar Inscrição' }}</span>
                </button>
                <p class="text-center text-[10px] text-ink-subtle uppercase tracking-widest mt-4">A inscrição é bloqueada na sua carteira agora • 10% de comissão da ArenaX1 sobre o prêmio</p>
            </div>
        </form>
    </div>
  </div>
</template>
