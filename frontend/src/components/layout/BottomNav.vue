<script setup lang="ts">
import { computed } from 'vue'
import { Home, Swords, Trophy, User, LayoutDashboard } from '@lucide/vue'
import { useAuthStore } from '@/stores/auth'
import ExpandableTabs, { type TabItem } from '@/components/ui/expandable-tabs.vue'

const authStore = useAuthStore()

const tabs = computed<TabItem[]>(() => [
  { title: 'Início', icon: Home, to: '/', match: (p) => p === '/' },
  { title: 'Desafios', icon: Swords, to: '/desafios' },
  { title: 'Ranking', icon: Trophy, to: '/classificacao' },
  authStore.user
    ? { title: 'Painel', icon: LayoutDashboard, to: '/dashboard' }
    : { title: 'Entrar', icon: User, to: '/login' },
])
</script>

<template>
  <nav
    class="pointer-events-none fixed inset-x-0 z-[9990] flex justify-center px-4 md:hidden"
    style="bottom: calc(1rem + env(safe-area-inset-bottom))"
  >
    <div
      class="pointer-events-auto flex items-center gap-1 rounded-full border border-hairline-strong bg-surface-1/90 p-1.5 shadow-card-premium backdrop-blur-xl"
    >
      <ExpandableTabs :tabs="tabs" />
    </div>
  </nav>
</template>
