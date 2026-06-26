<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import DisputeChat from '@/components/DisputeChat.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const challengeId = route.params.id as string
const challenge = ref<any>(null)
const loading = ref(true)
const reporting = ref(false)
let realtimeSub: any = null

const API_URL = 'http://localhost:8000/api/challenges'

const fetchChallenge = async () => {
  try {
    const { data, error } = await supabase
      .from('challenges')
      .select('*, creator_profile:creator_id(username, fair_play_rating), opponent_profile:opponent_id(username, fair_play_rating)')
      .eq('id', challengeId)
      .single()

    if (error) throw error
    challenge.value = data
  } catch (err) {
    console.error('Erro ao buscar desafio:', err)
    router.push('/challenges')
  } finally {
    loading.value = false
  }
}

const setupRealtime = () => {
  realtimeSub = supabase
    .channel(`match-${challengeId}`)
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'challenges', filter: `id=eq.${challengeId}` },
      (payload) => {
        // Atualiza apenas os campos que mudaram, ou faz refetch. O refetch traz os joins.
        fetchChallenge()
      }
    )
    .subscribe()
}

onMounted(() => {
  fetchChallenge()
  setupRealtime()
})

onUnmounted(() => {
  if (realtimeSub) supabase.removeChannel(realtimeSub)
})

const isCreator = computed(() => challenge.value?.creator_id === authStore.user?.id)
const isOpponent = computed(() => challenge.value?.opponent_id === authStore.user?.id)

const myResult = computed(() => isCreator.value ? challenge.value?.creator_result : challenge.value?.opponent_result)
const opponentResult = computed(() => isCreator.value ? challenge.value?.opponent_result : challenge.value?.creator_result)

const handleReport = async (result: 'win' | 'loss') => {
  if (!confirm(`Tem certeza que deseja reportar ${result === 'win' ? 'VITÓRIA' : 'DERROTA'}? Isso é irreversível e declarações falsas podem resultar em banimento.`)) {
    return
  }

  reporting.value = true
  try {
    const res = await fetch(`${API_URL}/report`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        challenge_id: challengeId,
        user_id: authStore.user?.id,
        result: result
      })
    })

    if (!res.ok) {
      const errData = await res.json()
      throw new Error(errData.detail || 'Erro ao reportar resultado.')
    }

    const resData = await res.json()
    alert(resData.message)
    await fetchChallenge()
  } catch (err: any) {
    alert(err.message)
  } finally {
    reporting.value = false
  }
}
</script>

<template>
  <div class="flex-1 p-6 md:p-10 max-w-7xl mx-auto w-full">
    <div v-if="loading" class="flex items-center justify-center py-20">
      <svg class="animate-spin h-10 w-10 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </div>

    <div v-else-if="challenge" class="space-y-8">
      
      <!-- Cabeçalho -->
      <div class="flex items-center justify-between">
        <button @click="router.push('/challenges')" class="text-ink-subtle hover:text-ink flex items-center gap-2 transition-colors font-bold text-sm">
          &larr; Voltar ao Lobby
        </button>
        <div class="flex items-center gap-3">
          <span class="text-[10px] font-bold uppercase tracking-wider bg-surface-3 border border-hairline-strong px-3 py-1.5 rounded-full text-ink-subtle">
            {{ challenge.game }}
          </span>
          <span class="text-[10px] font-bold uppercase tracking-wider bg-primary-focus/10 border border-primary px-3 py-1.5 rounded-full text-primary">
            {{ challenge.platform }}
          </span>
        </div>
      </div>

      <!-- Banner de Status -->
      <div 
        class="rounded-lg p-4 text-center border font-bold uppercase tracking-widest text-sm"
        :class="{
          'bg-surface-2 border-hairline text-ink-muted': challenge.status === 'in_progress',
          'bg-surface-2 border-hairline text-semantic-success': challenge.status === 'completed',
          'bg-surface-2 border-hairline text-ink-muted': challenge.status === 'disputed'
        }"
      >
        <span v-if="challenge.status === 'in_progress'">Partida em Andamento</span>
        <span v-else-if="challenge.status === 'completed'">Partida Concluída</span>
        <span v-else-if="challenge.status === 'disputed'">Partida em Disputa (Mediação Necessária)</span>
      </div>

      <!-- Placar e Versus -->
      <div class="bg-surface-1 border border-hairline rounded-xxl p-8 shadow-none relative overflow-hidden">
        <!-- Detalhes do Pote -->
        <div class="absolute top-0 left-1/2 -translate-x-1/2 bg-surface-2 border border-hairline border-t-0 px-8 py-3 rounded-b-3xl shadow-none flex items-center gap-4">
          <span class="text-ink-subtle text-caption font-bold uppercase tracking-wider">Aposta</span>
          <span class="text-ink font-semibold text-xl">R$ {{ parseFloat(challenge.bet_amount).toFixed(2) }}</span>
        </div>

        <div class="flex flex-col md:flex-row items-center justify-between gap-10 mt-12">
          
          <!-- Criador -->
          <div class="flex-1 text-center space-y-4">
            <div class="w-24 h-24 mx-auto rounded-full bg-surface-3 border-4 border-hairline flex items-center justify-center shadow-none">
              <span class="text-display-md font-display">🎮</span>
            </div>
            <div>
              <h2 class="text-headline font-display font-semibold text-ink">{{ challenge.creator_profile?.username }}</h2>
              <p class="text-ink-subtle text-sm">Criador da Sala</p>
              <div v-if="challenge.creator_result" class="mt-4">
                <span 
                  class="px-4 py-1.5 rounded-full text-caption font-bold uppercase border"
                  :class="challenge.creator_result === 'win' ? 'bg-surface-2 text-semantic-success border-hairline' : 'bg-surface-2 text-ink-muted border-hairline'"
                >
                  Reportou: {{ challenge.creator_result === 'win' ? 'Vitória' : 'Derrota' }}
                </span>
              </div>
            </div>
          </div>

          <!-- VS -->
          <div class="flex flex-col items-center">
            <div class="w-16 h-16 rounded-full bg-primary flex items-center justify-center shadow-none">
              <span class="text-ink font-semibold italic text-xl">VS</span>
            </div>
          </div>

          <!-- Oponente -->
          <div class="flex-1 text-center space-y-4">
            <div class="w-24 h-24 mx-auto rounded-full bg-surface-3 border-4 border-hairline flex items-center justify-center shadow-none">
              <span class="text-display-md font-display">🎯</span>
            </div>
            <div>
              <h2 class="text-headline font-display font-semibold text-ink">{{ challenge.opponent_profile?.username || 'Aguardando...' }}</h2>
              <p class="text-ink-subtle text-sm">Desafiante</p>
              <div v-if="challenge.opponent_result" class="mt-4">
                <span 
                  class="px-4 py-1.5 rounded-full text-caption font-bold uppercase border"
                  :class="challenge.opponent_result === 'win' ? 'bg-surface-2 text-semantic-success border-hairline' : 'bg-surface-2 text-ink-muted border-hairline'"
                >
                  Reportou: {{ challenge.opponent_result === 'win' ? 'Vitória' : 'Derrota' }}
                </span>
              </div>
            </div>
          </div>

        </div>
      </div>

      <!-- Ações de Reporte (Apenas se in_progress e participante e ainda não reportou) -->
      <div v-if="challenge.status === 'in_progress' && (isCreator || isOpponent)" class="bg-surface-1 border border-hairline p-8 rounded-xxl text-center shadow-none">
        
        <div v-if="myResult">
          <h3 class="text-xl font-bold text-ink mb-2">Seu resultado foi registrado!</h3>
          <p class="text-ink-subtle">Aguardando oponente confirmar o resultado da partida para liberar os fundos.</p>
        </div>
        
        <div v-else>
          <h3 class="text-headline font-display font-semibold text-ink mb-2 uppercase tracking-tight">Reportar Resultado</h3>
          <p class="text-ink-subtle mb-8 text-sm max-w-lg mx-auto">
            A partida terminou? Seja honesto. Reportes falsos constantes reduzirão seu Fair Play e levarão ao banimento permanente.
          </p>

          <div class="flex flex-col sm:flex-row justify-center gap-6">
            <button 
              @click="handleReport('win')"
              :disabled="reporting"
              class="flex-1 max-w-xs bg-green-500 hover:bg-green-600 text-ink font-semibold text-lg py-5 rounded-lg shadow-none hover:shadow-none transition-all disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
              </svg>
              EU VENCI
            </button>
            <button 
              @click="handleReport('loss')"
              :disabled="reporting"
              class="flex-1 max-w-xs bg-red-500 hover:bg-red-600 text-ink font-semibold text-lg py-5 rounded-lg shadow-none hover:shadow-none transition-all disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12" />
              </svg>
              EU PERDI
            </button>
          </div>
        </div>

      </div>

      <!-- Disputa Ativa -->
      <div v-if="challenge.status === 'disputed'" class="mt-8">
        <DisputeChat :challenge-id="challengeId" />
      </div>

    </div>
  </div>
</template>
