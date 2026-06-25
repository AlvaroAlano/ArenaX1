<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'

const email = ref('')
const password = ref('')
const loading = ref(false)
const errorMessage = ref('')

const router = useRouter()

const handleLogin = async () => {
  if (!email.value || !password.value) {
    errorMessage.value = 'Preencha todos os campos.'
    return
  }

  loading.value = true
  errorMessage.value = ''

  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value
    })

    if (error) {
      errorMessage.value = error.message === 'Invalid login credentials' 
        ? 'E-mail ou senha incorretos.' 
        : error.message
      return
    }

    router.push('/')
  } catch (err: any) {
    errorMessage.value = 'Ocorreu um erro ao tentar fazer login.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-[#0d0e12] bg-radial-gradient px-4 relative overflow-hidden">
    <!-- Efeitos Visuais de Fundo -->
    <div class="absolute -top-40 -left-40 w-96 h-96 bg-[#00f2fe]/10 rounded-full blur-3xl"></div>
    <div class="absolute -bottom-40 -right-40 w-96 h-96 bg-[#4facfe]/10 rounded-full blur-3xl"></div>

    <div class="w-full max-w-md bg-[#161920]/80 backdrop-blur-xl border border-[#262b35] p-8 rounded-2xl shadow-2xl relative z-10 transition-all duration-300 hover:border-[#4facfe]/30">
      
      <!-- Logo / Header -->
      <div class="text-center mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-[#00f2fe] to-[#4facfe] bg-clip-text text-transparent">
          Arena-X1
        </h1>
        <p class="text-[#8c9ba5] text-sm mt-2">
          Faça login para entrar no lobby dos campeões
        </p>
      </div>

      <!-- Alerta de Erro -->
      <div 
        v-if="errorMessage" 
        class="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm flex items-center gap-2 animate-pulse"
      >
        <span class="font-semibold">Erro:</span> {{ errorMessage }}
      </div>

      <!-- Formulário -->
      <form @submit.prevent="handleLogin" class="space-y-6">
        <div>
          <label class="block text-xs font-semibold text-[#8c9ba5] uppercase tracking-wider mb-2">E-mail</label>
          <input 
            v-model="email" 
            type="email" 
            placeholder="seu@email.com" 
            required 
            class="w-full bg-[#1b1f28] border border-[#2e3543] rounded-xl px-4 py-3 text-white placeholder-[#515c6e] focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
          />
        </div>

        <div>
          <div class="flex justify-between items-center mb-2">
            <label class="block text-xs font-semibold text-[#8c9ba5] uppercase tracking-wider">Senha</label>
          </div>
          <input 
            v-model="password" 
            type="password" 
            placeholder="••••••••" 
            required 
            class="w-full bg-[#1b1f28] border border-[#2e3543] rounded-xl px-4 py-3 text-white placeholder-[#515c6e] focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
          />
        </div>

        <button 
          type="submit" 
          :disabled="loading" 
          class="w-full bg-gradient-to-r from-[#00f2fe] to-[#4facfe] hover:from-[#00d8e4] hover:to-[#3b93e6] text-white font-bold py-3.5 px-4 rounded-xl shadow-lg shadow-[#4facfe]/20 hover:shadow-[#4facfe]/40 transition-all duration-300 flex items-center justify-center gap-2 text-sm disabled:opacity-50"
        >
          <svg v-if="loading" class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          {{ loading ? 'Entrando...' : 'Entrar' }}
        </button>
      </form>

      <!-- Cadastro Link -->
      <div class="mt-8 text-center border-t border-[#262b35] pt-6">
        <p class="text-sm text-[#8c9ba5]">
          Ainda não tem conta? 
          <router-link to="/register" class="text-[#00f2fe] hover:text-[#4facfe] font-semibold transition-colors">
            Cadastre-se grátis
          </router-link>
        </p>
      </div>

    </div>
  </div>
</template>

<style scoped>
.bg-radial-gradient {
  background-image: radial-gradient(circle at center, #1b202c 0%, #0d0e12 100%);
}
</style>
