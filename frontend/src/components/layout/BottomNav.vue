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
    class="fixed inset-x-0 bottom-0 z-[9990] border-t border-hairline-strong bg-surface-1/95 shadow-[0_-8px_24px_-12px_rgba(0,0,0,0.5)] backdrop-blur-xl md:hidden"
    style="padding-bottom: env(safe-area-inset-bottom)"
  >
    <div class="relative mx-auto flex max-w-lg items-center justify-around gap-1 px-2 py-1.5">
      <ExpandableTabs :tabs="tabs" />
    </div>
  </nav>
</template>
