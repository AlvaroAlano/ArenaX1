<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const activeTab = ref<'open' | 'my' | 'history'>('open')
const loading = ref(true)

// Listas de Desafios
const openChallenges = ref<any[]>([])
const myChallenges = ref<any[]>([])

// Modal de Criação
const showCreateModal = ref(false)
const game = ref('EA FC 25')
const platform = ref('PS5')
const betAmount = ref<number | null>(null)
const creating = ref(false)

const API_URL = 'http://localhost:8000/api/challenges'

// Carregar desafios abertos
const loadOpenChallenges = async () => {
  try {
    const res = await fetch(`${API_URL}/open`)
    if (res.ok) {
      openChallenges.value = await res.json()
    }
  } catch (err) {
    console.error('Erro ao carregar desafios abertos:', err)
  }
}

// Carregar meus desafios (ativos + histórico)
const loadMyChallenges = async () => {
  if (!authStore.user) return
  try {
    const res = await fetch(`${API_URL}/my-challenges?user_id=${authStore.user.id}`)
    if (res.ok) {
      myChallenges.value = await res.json()
    }
  } catch (err) {
    console.error('Erro ao carregar meus desafios:', err)
  }
}

// Criar desafio
const handleCreateChallenge = async () => {
  if (!betAmount.value || betAmount.value <= 0) {
    alert('Insira um valor de aposta válido.')
    return
  }

  creating.value = true
  try {
    const res = await fetch(`${API_URL}/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creator_id: authStore.user?.id,
        bet_amount: betAmount.value,
        platform: platform.value,
        game: game.value
      })
    })

    if (!res.ok) {
      const errData = await res.json()
      throw new Error(errData.detail || 'Erro ao criar desafio.')
    }

    showCreateModal.value = false
    betAmount.value = null
    await loadMyChallenges()
    await loadOpenChallenges()
  } catch (err: any) {
    alert(err.message)
  } finally {
    creating.value = false
  }
}

// Aceitar desafio
const handleAcceptChallenge = async (challengeId: string) => {
  if (!confirm('Deseja aceitar este desafio? O valor da aposta será congelado de sua carteira.')) {
    return
  }

  try {
    const res = await fetch(`${API_URL}/accept`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        challenge_id: challengeId,
        opponent_id: authStore.user?.id
      })
    })

    if (!res.ok) {
      const errData = await res.json()
      throw new Error(errData.detail || 'Erro ao aceitar desafio.')
    }

    alert('Desafio aceito com sucesso! Prepare seu time e adicione o adversário.')
    activeTab.value = 'my'
    await loadMyChallenges()
    await loadOpenChallenges()
  } catch (err: any) {
    alert(err.message)
  }
}

// Compartilhar link do desafio
const handleShare = (challengeId: string) => {
  const link = `${window.location.origin}/challenges?id=${challengeId}`
  navigator.clipboard.writeText(link)
  alert('Link do desafio copiado! Envie nos grupos de WhatsApp/Telegram para chamar pro X1.')
}

// Supabase Realtime Channels para Lobby Reativo
let lobbySub: any = null

const setupRealtime = () => {
  lobbySub = supabase
    .channel('lobby-db-changes')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'challenges' },
      () => {
        loadOpenChallenges()
        loadMyChallenges()
      }
    )
    .subscribe()
}

onMounted(async () => {
  loading.value = true
  await Promise.all([loadOpenChallenges(), loadMyChallenges()])
  setupRealtime()
  loading.value = false
})

onUnmounted(() => {
  if (lobbySub) supabase.removeChannel(lobbySub)
})
</script>

<template>
  <div class="flex-1 p-6 md:p-10 max-w-7xl mx-auto w-full space-y-8">
    
    <!-- Header e Ação de Criar Sala -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-display-md font-display font-semibold tracking-tight text-ink uppercase">Lobby de Desafios</h1>
        <p class="text-ink-subtle text-sm mt-1">Crie salas de apostas ou aceite desafios abertos em consoles/PC.</p>
      </div>
      <button 
        @click="showCreateModal = true"
        class="bg-primary hover:bg-primary-hover text-ink font-semibold px-6 py-3.5 rounded-lg shadow-none shadow-none transition-all duration-300 flex items-center justify-center gap-2 text-sm"
      >
        <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4" />
        </svg>
        Criar Desafio X1
      </button>
    </div>

    <!-- Navegação por Abas -->
    <div class="flex border-b border-hairline">
      <button 
        @click="activeTab = 'open'"
        :class="[activeTab === 'open' ? 'border-[#00f2fe] text-primary bg-surface-2' : 'border-transparent text-ink-subtle hover:text-ink']"
        class="px-6 py-4 font-bold text-sm border-b-2 transition-all"
      >
        Salas Abertas ({{ openChallenges.length }})
      </button>
      <button 
        @click="activeTab = 'my'"
        :class="[activeTab === 'my' ? 'border-[#00f2fe] text-primary bg-surface-2' : 'border-transparent text-ink-subtle hover:text-ink']"
        class="px-6 py-4 font-bold text-sm border-b-2 transition-all"
      >
        Meus Desafios Ativos
      </button>
    </div>

    <!-- FEED DE DESAFIOS -->
    <div v-if="loading" class="flex flex-col items-center justify-center py-20">
      <svg class="animate-spin h-10 w-10 text-primary mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-ink-subtle text-sm">Carregando feed de partidas...</p>
    </div>

    <div v-else class="space-y-6">
      
      <!-- ABA: SALAS ABERTAS -->
      <div v-if="activeTab === 'open'" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-if="openChallenges.length === 0" class="col-span-full py-16 text-center bg-surface-1 border border-hairline rounded-lg">
          <p class="text-ink-subtle text-sm">Nenhuma sala aberta no momento.</p>
          <p class="text-caption text-ink-tertiary mt-1">Seja o primeiro a criar um desafio clicando no botão acima!</p>
        </div>

        <!-- Cards de Sala -->
        <div 
          v-for="ch in openChallenges" 
          :key="ch.id" 
          class="bg-surface-1 border border-hairline hover:border-primary p-6 rounded-lg shadow-none transition-all duration-300 relative group flex flex-col justify-between"
        >
          <div>
            <div class="flex justify-between items-center mb-4">
              <span class="text-[10px] font-bold uppercase tracking-wider bg-surface-3 border border-hairline-strong px-2.5 py-1 rounded-full text-ink-subtle">
                {{ ch.game }}
              </span>
              <span class="text-[10px] font-bold uppercase tracking-wider bg-primary-focus/10 border border-primary px-2.5 py-1 rounded-full text-primary">
                {{ ch.platform }}
              </span>
            </div>

            <div class="space-y-1">
              <h3 class="text-ink font-semibold text-lg flex items-center gap-1.5">
                {{ ch.profiles?.username || 'Desafiante' }}
              </h3>
              <p class="text-caption text-ink-subtle">Fair Play: <span class="text-ink-muted font-bold">{{ ch.profiles?.fair_play_rating?.toFixed(1) || '5.0' }} ★</span></p>
            </div>

            <!-- Dados da Aposta -->
            <div class="mt-6 p-4 rounded-lg bg-surface-2 border border-hairline flex justify-between items-center">
              <div>
                <span class="text-[10px] text-ink-subtle uppercase tracking-wider block">Aposta</span>
                <span class="text-md font-bold text-ink">R$ {{ parseFloat(ch.bet_amount).toFixed(2) }}</span>
              </div>
              <div class="text-right">
                <span class="text-[10px] text-semantic-success uppercase tracking-wider block">Prêmio (Pote - Rake)</span>
                <!-- Prêmio estimado = aposta x 2 - Rake de 10% -->
                <span class="text-md font-bold text-semantic-success">R$ {{ (parseFloat(ch.bet_amount) * 2 * 0.9).toFixed(2) }}</span>
              </div>
            </div>
          </div>

          <!-- Ações do Card -->
          <div class="grid grid-cols-2 gap-3 mt-6">
            <button 
              @click="handleShare(ch.id)"
              class="bg-surface-3 hover:bg-[#2e3543] border border-hairline-strong text-ink py-2.5 rounded-lg font-bold transition-all text-caption flex items-center justify-center gap-1.5"
            >
              Compartilhar
            </button>
            <button 
              v-if="ch.creator_id !== authStore.user?.id"
              @click="handleAcceptChallenge(ch.id)"
              class="bg-primary hover:bg-primary-hover text-ink py-2.5 rounded-lg font-bold shadow-md shadow-none/10 transition-all text-caption"
            >
              Aceitar
            </button>
            <span 
              v-else 
              class="bg-surface-2 border border-hairline text-ink-tertiary py-2.5 rounded-lg font-bold text-caption text-center block leading-loose"
            >
              Sua Sala
            </span>
          </div>
        </div>
      </div>

      <!-- ABA: MEUS DESAFIOS ATIVOS -->
      <div v-if="activeTab === 'my'" class="space-y-4">
        <div v-if="myChallenges.filter(ch => ch.status !== 'completed' && ch.status !== 'cancelled').length === 0" class="py-16 text-center bg-surface-1 border border-hairline rounded-lg">
          <p class="text-ink-subtle text-sm">Você não tem nenhum desafio ativo no momento.</p>
        </div>

        <div 
          v-for="ch in myChallenges.filter(ch => ch.status !== 'completed' && ch.status !== 'cancelled')" 
          :key="ch.id"
          class="bg-surface-1 border border-hairline p-5 rounded-lg flex flex-col md:flex-row justify-between items-start md:items-center gap-4 hover:border-primary transition-all"
        >
          <div>
            <div class="flex items-center gap-2.5">
              <span class="text-[10px] font-bold uppercase tracking-wider bg-surface-3 border border-hairline-strong px-2.5 py-0.5 rounded-full text-ink-subtle">
                {{ ch.game }}
              </span>
              <span class="text-[10px] font-bold uppercase tracking-wider bg-[#4facfe]/10 border border-[#4facfe]/20 px-2.5 py-0.5 rounded-full text-[#4facfe]">
                {{ ch.platform }}
              </span>
              <!-- Status Badge -->
              <span 
                :class="[
                  ch.status === 'open' ? 'bg-surface-2 text-ink-muted border-hairline' : 'bg-surface-2 text-semantic-success border-hairline'
                ]"
                class="text-[10px] font-bold uppercase tracking-wider border px-2.5 py-0.5 rounded-full"
              >
                {{ ch.status === 'open' ? 'Aguardando Oponente' : 'Em Andamento' }}
              </span>
            </div>

            <!-- Detalhes do Desafio -->
            <div class="mt-3 flex items-center gap-2">
              <span class="text-sm font-semibold text-ink">
                {{ ch.creator_profile?.username }} 
              </span>
              <span class="text-caption text-ink-subtle">vs</span>
              <span class="text-sm font-semibold text-ink">
                {{ ch.opponent_profile?.username || '?' }}
              </span>
            </div>
            <p class="text-[11px] text-ink-tertiary mt-1">Sala ID: {{ ch.id }}</p>
          </div>

          <!-- Pote Financeiro -->
          <div class="flex items-center gap-6">
            <div class="text-right">
              <span class="text-[10px] text-ink-subtle uppercase tracking-wider block">Valor Apostado</span>
              <span class="text-sm font-bold text-ink">R$ {{ parseFloat(ch.bet_amount).toFixed(2) }}</span>
            </div>

            <div class="flex gap-2">
              <button 
                v-if="ch.status === 'open'"
                @click="handleShare(ch.id)"
                class="bg-surface-3 hover:bg-[#2e3543] border border-hairline-strong text-ink font-bold px-4 py-2 rounded-lg text-caption transition-all"
              >
                Compartilhar Link
              </button>
              <button 
                v-else
                @click="$router.push(`/match/${ch.id}`)"
                class="bg-primary hover:bg-primary-hover text-ink font-bold px-5 py-2.5 rounded-lg text-caption shadow-md shadow-none/10 transition-all"
              >
                Abrir Sala
              </button>
            </div>
          </div>
        </div>
      </div>

    </div>

    <!-- MODAL DE CRIAÇÃO DE DESAFIO -->
    <div 
      v-if="showCreateModal" 
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 "
    >
      <div 
        class="w-full max-w-md bg-surface-1 border border-hairline p-6 rounded-lg shadow-none space-y-6"
      >
        <div class="flex justify-between items-center">
          <h3 class="text-xl font-bold text-ink uppercase tracking-tight">Criar Sala de X1</h3>
          <button 
            @click="showCreateModal = false"
            class="text-ink-subtle hover:text-ink transition-colors"
          >
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="space-y-4">
          <!-- Seleção de Jogo -->
          <div>
            <label class="block text-caption font-semibold text-ink-subtle uppercase tracking-wider mb-2">Jogo</label>
            <select 
              v-model="game"
              class="w-full bg-surface-2 border border-hairline-strong rounded-lg px-4 py-3 text-ink focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
            >
              <option value="EA FC 25">EA FC 25</option>
              <option value="eFootball">eFootball</option>
            </select>
          </div>

          <!-- Seleção de Plataforma -->
          <div>
            <label class="block text-caption font-semibold text-ink-subtle uppercase tracking-wider mb-2">Plataforma</label>
            <select 
              v-model="platform"
              class="w-full bg-surface-2 border border-hairline-strong rounded-lg px-4 py-3 text-ink focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
            >
              <option value="PS5">PlayStation 5</option>
              <option value="Xbox">Xbox Series X/S</option>
              <option value="PC">PC</option>
              <option value="Crossplay">Crossplay (Todas)</option>
            </select>
          </div>

          <!-- Valor da Aposta -->
          <div>
            <label class="block text-caption font-semibold text-ink-subtle uppercase tracking-wider mb-2">Valor da Aposta (R$)</label>
            <input 
              v-model.number="betAmount"
              type="number"
              placeholder="Digite o valor de sua aposta"
              class="w-full bg-surface-2 border border-hairline-strong rounded-lg px-4 py-3 text-ink placeholder-[#515c6e] focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
            />
            <p class="text-[10px] text-ink-subtle mt-1.5">Esse valor será congelado temporariamente de sua carteira.</p>
          </div>
        </div>

        <!-- Botão de Criação -->
        <button 
          @click="handleCreateChallenge"
          :disabled="creating"
          class="w-full bg-primary text-ink font-semibold py-3.5 rounded-lg shadow-none transition-all text-sm disabled:opacity-50"
        >
          {{ creating ? 'Criando sala...' : 'Publicar Desafio' }}
        </button>
      </div>
    </div>

  </div>
</template>

<style scoped>
</style>
