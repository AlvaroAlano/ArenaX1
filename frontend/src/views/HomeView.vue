<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const profile = ref<any>(null)
const wallet = ref<any>(null)
const loading = ref(true)

const loadUserData = async () => {
  if (!authStore.user) return

  loading.value = true
  try {
    // Buscar perfil do usuário
    const { data: profileData } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authStore.user.id)
      .single()

    profile.value = profileData

    // Buscar carteira do usuário
    const { data: walletData } = await supabase
      .from('wallets')
      .select('*')
      .eq('user_id', authStore.user.id)
      .single()

    wallet.value = walletData
  } catch (err) {
    console.error('Erro ao carregar dados do usuário:', err)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadUserData()
})
</script>

<template>
  <div class="flex-1 p-6 md:p-10 max-w-7xl mx-auto w-full space-y-8">
    <!-- Seção de Loading -->
    <div v-if="loading" class="flex flex-col items-center justify-center py-20 space-y-4">
      <svg class="animate-spin h-10 w-10 text-[#00f2fe]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-[#8c9ba5] text-sm font-medium">Carregando seus dados da Arena...</p>
    </div>

    <!-- Conteúdo Principal -->
    <div v-else class="space-y-8">
      
      <!-- Cabeçalho de Boas-vindas -->
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-[#161920]/60 border border-[#262b35] p-6 rounded-2xl backdrop-blur-sm">
        <div>
          <h2 class="text-2xl md:text-3xl font-extrabold text-white">
            Olá, <span class="text-[#00f2fe]">{{ profile?.username || 'Jogador' }}</span>!
          </h2>
          <p class="text-[#8c9ba5] text-sm mt-1">
            Bem-vindo de volta à Arena. Seu Fair Play Rating é de 
            <span class="text-yellow-400 font-bold">{{ profile?.fair_play_rating?.toFixed(1) || '5.0' }} ★</span>
          </p>
        </div>
        <div class="flex gap-3">
          <button class="bg-[#1f2430] hover:bg-[#2e3543] border border-[#2e3543] text-white px-5 py-3 rounded-xl font-bold transition-all text-sm">
            Editar Perfil
          </button>
          <button class="bg-gradient-to-r from-[#00f2fe] to-[#4facfe] hover:from-[#00d8e4] hover:to-[#3b93e6] text-white px-5 py-3 rounded-xl font-bold shadow-lg shadow-[#4facfe]/10 transition-all text-sm">
            Jogar X1
          </button>
        </div>
      </div>

      <!-- Grid de Cards de Saldo / Stats -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Card Carteira -->
        <div class="bg-gradient-to-br from-[#161920] to-[#1c2230] border border-[#262b35] hover:border-[#4facfe]/30 p-6 rounded-2xl shadow-xl transition-all duration-300 relative overflow-hidden group">
          <div class="absolute -right-8 -bottom-8 w-24 h-24 bg-[#4facfe]/5 rounded-full group-hover:scale-155 transition-transform duration-500"></div>
          <div class="flex justify-between items-start mb-4">
            <h3 class="text-[#8c9ba5] text-xs font-semibold uppercase tracking-wider">Saldo na Carteira</h3>
            <span class="text-green-400 text-xs font-bold bg-green-500/10 px-2 py-1 rounded-md">Pix Ativo</span>
          </div>
          <div class="text-3xl font-black text-white">
            R$ {{ wallet?.balance?.toFixed(2) || '0.00' }}
          </div>
          <div class="text-xs text-[#8c9ba5] mt-2">
            Saldo congelado em jogo: R$ {{ wallet?.locked_balance?.toFixed(2) || '0.00' }}
          </div>
        </div>

        <!-- Card de Plataformas -->
        <div class="bg-[#161920]/40 border border-[#262b35] p-6 rounded-2xl shadow-xl">
          <h3 class="text-[#8c9ba5] text-xs font-semibold uppercase tracking-wider mb-4">Suas Contas de Jogador</h3>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between py-1 border-b border-[#262b35]/40">
              <span class="text-[#8c9ba5]">EA ID:</span>
              <span class="text-white font-medium">{{ profile?.ea_id || 'Não Vinculado' }}</span>
            </div>
            <div class="flex justify-between py-1 border-b border-[#262b35]/40">
              <span class="text-[#8c9ba5]">PSN ID:</span>
              <span class="text-white font-medium">{{ profile?.psn_id || 'Não Vinculado' }}</span>
            </div>
            <div class="flex justify-between py-1">
              <span class="text-[#8c9ba5]">Xbox Live:</span>
              <span class="text-white font-medium">{{ profile?.xbox_id || 'Não Vinculado' }}</span>
            </div>
          </div>
        </div>

        <!-- Card de Matchmaking Rápido -->
        <div class="bg-[#161920]/40 border border-[#262b35] p-6 rounded-2xl shadow-xl flex flex-col justify-between">
          <div>
            <h3 class="text-[#8c9ba5] text-xs font-semibold uppercase tracking-wider mb-2">Desafios</h3>
            <p class="text-[#8c9ba5] text-sm">Crie salas públicas para outros jogadores entrarem, ou gere links privados para desafiar seus amigos.</p>
          </div>
          <button class="w-full bg-[#1b1f28] hover:bg-[#262b35] border border-[#2e3543] text-white py-3 rounded-xl font-bold transition-all text-sm mt-4">
            Gerar Link de Desafio
          </button>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
</style>
