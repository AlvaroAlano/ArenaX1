<script setup lang="ts">
import { RouterView, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/services/supabase'
import { computed } from 'vue'
import PullToRefresh from '@/components/ui/PullToRefresh.vue'
import ToastHost from '@/components/ui/ToastHost.vue'
import ConfirmDialog from '@/components/ui/ConfirmDialog.vue'

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
    <PullToRefresh />
    <ToastHost />
    <ConfirmDialog />

    <!-- Glow ambiente: teleportado pro <body> pra escapar de qualquer stacking/overflow context do #app.
         Importante: usa z-0 (nunca z-index negativo) — nesta base de código, elementos fixed com
         z-index negativo somem por trás do fundo em telas com conteúdo rolável (bug de compositing
         do Chromium, não descoberto o porquê exato; z-index >= 0 + conteúdo em z-10 é a saída estável). -->
    <Teleport to="body">
      <div aria-hidden="true" class="pointer-events-none fixed inset-0 z-0 overflow-hidden">
          <div class="absolute -left-32 -top-32 h-[480px] w-[480px] rounded-full bg-primary/12 blur-[120px]"></div>
          <div class="absolute -bottom-40 -right-40 h-[560px] w-[560px] rounded-full bg-accent/12 blur-[130px]"></div>
      </div>
    </Teleport>

    <!-- Conteúdo da Página -->
    <main class="flex-1 flex flex-col relative z-10 overflow-hidden">
      <router-view v-slot="{ Component }">
        <transition name="page" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
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

/* Transições Suaves de Rota (Padrão para todas as telas) */
.page-enter-active,
.page-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}

.page-enter-from,
.page-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
</style>
