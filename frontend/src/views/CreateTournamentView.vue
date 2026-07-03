<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { Trophy, Users, UserPlus, Shuffle, Info, Lock } from '@lucide/vue'
import { useRouter } from 'vue-router'
import { api } from '@/services/api'
import { GAME_OPTIONS } from '@/constants/games'

const router = useRouter()

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
            <div class="flex flex-col gap-2 rounded-xl border-2 border-primary bg-primary/10 p-4">
                <Users :size="22" class="text-primary" />
                <p class="font-bold text-ink">Torneio Local</p>
                <p class="text-caption text-ink-subtle">Você e seus amigos, no mesmo sofá — chaveamento automático, sem precisar de conta.</p>
            </div>
            <div class="relative flex flex-col gap-2 rounded-xl border-2 border-hairline bg-surface-1 p-4 opacity-60 cursor-not-allowed">
                <span class="absolute right-3 top-3 rounded-full bg-surface-3 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider text-ink-tertiary">Em breve</span>
                <Trophy :size="22" class="text-ink-tertiary" />
                <p class="font-bold text-ink-tertiary">Torneio Online Pago</p>
                <p class="text-caption text-ink-tertiary">Inscrição com dinheiro real e premiação para o pódio.</p>
            </div>
        </section>

        <form @submit.prevent="submitTournament">

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
    </div>
  </div>
</template>
