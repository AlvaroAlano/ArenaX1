<script setup lang="ts">
import { RouterView, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/services/supabase'
import { computed } from 'vue'

const authStore = useAuthStore()
const router = useRouter()
const route = useRoute()

// Ocultar a navbar em telas de login e register ou caso o usuário não esteja autenticado
const showNavbar = computed(() => {
  return authStore.user !== null && route.path !== '/login' && route.path !== '/register'
})

const handleLogout = async () => {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen bg-[#0d0e12] text-white flex flex-col">
    <!-- Navbar Premium -->
    <header 
      v-if="showNavbar" 
      class="bg-[#161920]/80 backdrop-blur-md border-b border-[#262b35] sticky top-0 z-50 px-6 py-4 flex items-center justify-between"
    >
      <div class="flex items-center gap-8">
        <router-link to="/" class="text-2xl font-black bg-gradient-to-r from-[#00f2fe] to-[#4facfe] bg-clip-text text-transparent hover:opacity-90 transition-opacity">
          ARENA-X1
        </router-link>
        <nav class="hidden md:flex items-center gap-6">
          <router-link to="/" class="text-sm font-medium text-[#8c9ba5] hover:text-white transition-colors" active-class="text-[#00f2fe]">
            Dashboard
          </router-link>
          <router-link to="/about" class="text-sm font-medium text-[#8c9ba5] hover:text-white transition-colors" active-class="text-[#00f2fe]">
            Sobre
          </router-link>
        </nav>
      </div>

      <div class="flex items-center gap-4">
        <!-- Detalhes do Usuário logado -->
        <span class="text-xs bg-[#1f2430] border border-[#2e3543] px-3 py-1.5 rounded-full text-[#8c9ba5] max-w-[180px] truncate">
          {{ authStore.user?.email }}
        </span>
        <button 
          @click="handleLogout" 
          class="text-sm font-medium text-red-400 hover:text-red-300 bg-red-500/10 hover:bg-red-500/20 border border-red-500/20 px-4 py-2 rounded-xl transition-all duration-300"
        >
          Sair
        </button>
      </div>
    </header>

    <!-- Conteúdo da Página -->
    <main class="flex-1 flex flex-col">
      <RouterView />
    </main>
  </div>
</template>

<style>
/* Reset de estilos para compatibilidade total com Tailwind */
#app {
  max-width: none !important;
  margin: 0 !important;
  padding: 0 !important;
  width: 100%;
}
</style>
