<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Info, Tag, UserSearch, Lock, Swords } from '@lucide/vue'
import { useAuthStore } from '@/stores/auth'
import { useWalletStore } from '@/stores/wallet'
import { useRouter } from 'vue-router'
import { api } from '@/services/api'
import { GAME_OPTIONS } from '@/constants/games'

const authStore = useAuthStore()
const walletStore = useWalletStore()
const router = useRouter()

const stake = ref(5)
const game = ref(GAME_OPTIONS[0])
const platform = ref('PS5')
const gameId = ref(authStore.user?.user_metadata?.ea_id || '')
const inviteSearch = ref('')
const isSubmitting = ref(false)
const errorMsg = ref('')

onMounted(() => { walletStore.fetchWallet() })

const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

const isValid = computed(() => {
    return stake.value >= 1
        && game.value
        && platform.value
        && gameId.value.trim().length > 0
        && (!walletStore.loaded || stake.value <= walletStore.balance)
})

const submitChallenge = async () => {
    if (!isValid.value) return
    isSubmitting.value = true
    errorMsg.value = ''

    try {
        const challenge = await api.post<{ id: string }>('/api/challenges/create', {
            bet_amount: stake.value,
            platform: platform.value,
            game: game.value,
        })
        router.push(`/match/${challenge.id}`)
    } catch (err: any) {
        errorMsg.value = err.message || 'Erro ao criar o desafio.'
    } finally {
        isSubmitting.value = false
    }
}
</script>

<template>
  <div class="flex-1 p-6 lg:p-10 w-full">
    <div class="max-w-2xl mx-auto flex flex-col gap-8">
        
        <section>
            <h1 class="font-display text-3xl lg:text-4xl font-black uppercase tracking-tight mb-2 text-ink">Criar um Desafio</h1>
            <p class="text-ink-subtle">Fecha o valor, escolhe a plataforma e prova em campo. Saldo atual: <span class="text-primary font-bold">{{ walletStore.loaded ? fmtBRL(walletStore.balance) : '···' }}</span></p>
        </section>

        <form @submit.prevent="submitChallenge">
            
            <!-- Secção 1 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">1</span>
                    <h2 class="text-xl font-bold text-ink">Defina o Valor da Partida</h2>
                </div>
                <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <label v-for="val in [5, 10, 20, 50]" :key="val" class="cursor-pointer group">
                        <input type="radio" v-model="stake" :value="val" class="peer sr-only" />
                        <div class="flex flex-col items-center justify-center p-4 rounded-xl border-2 border-hairline bg-surface-1 peer-checked:border-primary peer-checked:bg-primary/10 hover:border-primary/50 transition-all">
                            <span class="text-lg font-bold text-ink">R$ {{ val.toFixed(2) }}</span>
                        </div>
                    </label>
                </div>
            </section>

            <!-- Secção 2 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">2</span>
                    <h2 class="text-xl font-bold text-ink">Informações da Partida</h2>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div>
                        <label class="block text-sm font-semibold text-ink mb-1.5">Jogo</label>
                        <select v-model="game" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all">
                            <option v-for="opt in GAME_OPTIONS" :key="opt" :value="opt">{{ opt }}</option>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-semibold text-ink mb-1.5">Plataforma</label>
                        <select v-model="platform" class="w-full rounded-lg border border-hairline bg-surface-1 text-ink h-12 px-4 focus:ring-2 focus:ring-primary outline-none transition-all">
                            <option value="PS5">PS5</option>
                            <option value="Xbox">Xbox</option>
                            <option value="PC">PC</option>
                            <option value="Crossplay">Crossplay</option>
                        </select>
                    </div>
                </div>
                <div class="p-5 rounded-xl bg-surface-2 border border-hairline">
                    <h3 class="font-bold mb-3 flex items-center gap-2 text-ink">
                        <Info :size="24" class="text-primary" />
                        Regras da partida:
                    </h3>
                    <ul class="text-sm text-ink-subtle space-y-3">
                        <li class="flex gap-3">
                            <span class="font-bold text-ink">1.</span>
                            <span>Jogo: <strong class="text-ink">{{ game }}</strong> — Plataforma: <strong class="text-ink">{{ platform }}</strong></span>
                        </li>
                        <li class="flex gap-3">
                            <span class="font-bold text-ink">2.</span>
                            <span>O vencedor leva até 1,84× o valor da partida (após a comissão de 8% da ArenaX1).</span>
                        </li>
                        <li class="flex gap-3">
                            <span class="font-bold text-ink">3.</span>
                            <span>Após a partida, cada jogador declara o resultado. Em caso de desacordo, abrir disputa.</span>
                        </li>
                    </ul>
                </div>
            </section>

            <!-- Secção 3 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">3</span>
                    <h2 class="text-xl font-bold text-ink">O Seu ID de Jogo</h2>
                </div>
                <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-ink">EA ID / Gamertag <span class="text-semantic-error">*</span></label>
                    <div class="relative">
                        <Tag :size="20" class="absolute left-3 top-1/2 -translate-y-1/2 text-ink-subtle" />
                        <input v-model="gameId" class="w-full bg-surface-1 border border-hairline text-ink rounded-lg h-12 pl-11 pr-4 focus:ring-2 focus:ring-primary outline-none transition-all" placeholder="Ex: EA_ProGamer42" type="text" required maxlength="100"/>
                    </div>
                    <p class="text-[11px] text-ink-subtle flex items-center gap-1 mt-1">
                        <Info :size="14" />
                        Este ID será usado para o identificar nas capturas de tela em caso de disputa.
                    </p>
                </div>
            </section>

            <!-- Secção 4 -->
            <section class="flex flex-col gap-4 mb-8">
                <div class="flex items-center gap-2">
                    <span class="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-canvas">4</span>
                    <h2 class="text-xl font-bold text-ink">Convidar um adversário</h2>
                    <span class="text-xs text-ink-subtle ml-1">(opcional)</span>
                </div>
                <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-ink">Procurar um jogador na plataforma</label>
                    <div class="relative">
                        <UserSearch :size="20" class="absolute left-3 top-1/2 -translate-y-1/2 text-ink-subtle" />
                        <input type="text" v-model="inviteSearch" class="w-full bg-surface-1 border border-hairline text-ink rounded-lg h-12 pl-11 pr-4 focus:ring-2 focus:ring-primary outline-none transition-all" placeholder="Escreva um nome para procurar..." />
                    </div>
                    <p class="text-[11px] text-ink-subtle flex items-center gap-1 mt-1">
                        <Lock :size="14" />
                        Se convidar um jogador, o desafio será privado e apenas esse jogador poderá participar.
                    </p>
                </div>
            </section>

            <div class="pt-6 border-t border-hairline">
                <p v-if="errorMsg" class="mb-4 text-center text-sm font-semibold text-semantic-error">{{ errorMsg }}</p>
                <button type="submit" :disabled="!isValid || isSubmitting" class="w-full py-4 rounded-xl bg-primary hover:bg-primary-hover text-canvas font-bold text-lg flex items-center justify-center gap-2 transition-all shadow-lg shadow-primary/20 disabled:opacity-50 disabled:cursor-not-allowed">
                    <Swords :size="24" v-if="!isSubmitting" />
                    <svg v-if="isSubmitting" class="w-5 h-5 text-canvas animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
                    </svg>
                    <span>{{ isSubmitting ? 'A criar...' : 'Criar o Desafio' }}</span>
                </button>
                <p class="text-center text-[10px] text-ink-subtle uppercase tracking-widest mt-4">O valor será bloqueado na sua carteira • 8% de comissão da ArenaX1 sobre o prêmio do vencedor</p>
            </div>
        </form>
    </div>
  </div>
</template>
