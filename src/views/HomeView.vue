<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { formatCurrency } from '@/utils/format'

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
      <svg class="animate-spin h-10 w-10 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-ink-subtle text-sm font-medium">Carregando seus dados da Arena...</p>
    </div>

    <!-- Conteúdo Principal -->
    <div v-else class="space-y-8">
      
      <!-- Cabeçalho de Boas-vindas -->
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-surface-1 border border-hairline p-6 rounded-lg ">
        <div>
          <h2 class="text-headline font-display md:text-display-md font-display font-semibold text-ink">
            Olá, <span class="text-primary">{{ profile?.username || 'Jogador' }}</span>!
          </h2>
          <p class="text-ink-subtle text-sm mt-1">
            Bem-vindo de volta à Arena. Seu Fair Play Rating é de 
            <span class="text-ink-muted font-bold">{{ profile?.fair_play_rating?.toFixed(1) || '5.0' }} ★</span>
          </p>
        </div>
        <div class="flex gap-3">
          <button class="bg-surface-3 hover:bg-surface-4 border border-hairline-strong text-ink px-5 py-3 rounded-lg font-bold transition-colors text-sm">
            Editar Perfil
          </button>
          <button class="bg-primary hover:bg-primary-hover text-on-primary px-5 py-3 rounded-lg font-bold transition-colors text-sm">
            Jogar X1
          </button>
        </div>
      </div>

      <!-- Grid de Cards de Saldo / Stats -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Card Carteira -->
        <div class="bg-surface-1 border border-hairline hover:border-primary p-6 rounded-lg transition-colors duration-300 relative overflow-hidden group">
          
          <div class="flex justify-between items-start mb-4">
            <h3 class="text-ink-subtle text-caption font-semibold uppercase tracking-wider">Saldo na Carteira</h3>
            <span class="text-semantic-success text-caption font-bold bg-surface-2 px-2 py-1 rounded-md">Pix Ativo</span>
          </div>
          <div class="text-display-md font-display font-semibold text-ink">
            {{ formatCurrency(wallet?.balance) }}
          </div>
          <div class="text-caption text-ink-subtle mt-2">
            Saldo congelado em jogo: {{ formatCurrency(wallet?.locked_balance) }}
          </div>
        </div>

        <!-- Card de Plataformas -->
        <div class="bg-surface-1 border border-hairline p-6 rounded-lg">
          <h3 class="text-ink-subtle text-caption font-semibold uppercase tracking-wider mb-4">Suas Contas de Jogador</h3>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between py-1 border-b border-hairline">
              <span class="text-ink-subtle">EA ID:</span>
              <span class="text-ink font-medium">{{ profile?.ea_id || 'Não Vinculado' }}</span>
            </div>
            <div class="flex justify-between py-1 border-b border-hairline">
              <span class="text-ink-subtle">PSN ID:</span>
              <span class="text-ink font-medium">{{ profile?.psn_id || 'Não Vinculado' }}</span>
            </div>
            <div class="flex justify-between py-1">
              <span class="text-ink-subtle">Xbox Live:</span>
              <span class="text-ink font-medium">{{ profile?.xbox_id || 'Não Vinculado' }}</span>
            </div>
          </div>
        </div>

        <!-- Card de Matchmaking Rápido -->
        <div class="bg-surface-1 border border-hairline p-6 rounded-lg flex flex-col justify-between">
          <div>
            <h3 class="text-ink-subtle text-caption font-semibold uppercase tracking-wider mb-2">Desafios</h3>
            <p class="text-ink-subtle text-sm">Crie salas públicas para outros jogadores entrarem, ou gere links privados para desafiar seus amigos.</p>
          </div>
          <button class="w-full bg-surface-2 hover:bg-surface-3 border border-hairline-strong text-ink py-3 rounded-lg font-bold transition-colors text-sm mt-4">
            Gerar Link de Desafio
          </button>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
</style>
