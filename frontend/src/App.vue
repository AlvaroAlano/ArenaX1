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
  <div class="min-h-screen bg-canvas text-ink flex flex-col">
    <!-- Navbar Premium -->
    <header 
      v-if="showNavbar" 
      class="bg-surface-1  border-b border-hairline sticky top-0 z-50 px-6 py-4 flex items-center justify-between"
    >
      <div class="flex items-center gap-8">
        <router-link to="/" class="text-headline font-display font-semibold bg-primary text-primary hover:opacity-90 transition-opacity">
          ARENA-X1
        </router-link>
        <nav class="hidden md:flex items-center gap-6">
          <router-link to="/" class="text-sm font-medium text-ink-subtle hover:text-ink transition-colors" active-class="text-primary">
            Dashboard
          </router-link>
          <router-link to="/challenges" class="text-sm font-medium text-ink-subtle hover:text-ink transition-colors" active-class="text-primary">
            Desafios
          </router-link>
          <router-link to="/wallet" class="text-sm font-medium text-ink-subtle hover:text-ink transition-colors" active-class="text-primary">
            Carteira
          </router-link>
          <router-link to="/about" class="text-sm font-medium text-ink-subtle hover:text-ink transition-colors" active-class="text-primary">
            Sobre
          </router-link>
        </nav>
      </div>

      <div class="flex items-center gap-4">
        <!-- Detalhes do Usuário logado -->
        <span class="text-caption bg-surface-3 border border-hairline-strong px-3 py-1.5 rounded-full text-ink-subtle max-w-[180px] truncate">
          {{ authStore.user?.email }}
        </span>
        <button 
          @click="handleLogout" 
          class="text-sm font-medium text-ink-muted hover:text-red-300 bg-surface-2 hover:bg-red-500/20 border border-hairline px-4 py-2 rounded-lg transition-all duration-300"
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
