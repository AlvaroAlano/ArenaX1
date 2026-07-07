<script setup lang="ts">
import { onMounted } from 'vue'
import { Wallet } from '@lucide/vue'
import DashboardSidebar from '@/components/layout/DashboardSidebar.vue'
import DashboardBottomNav from '@/components/layout/DashboardBottomNav.vue'
import NotificationBell from '@/components/ui/NotificationBell.vue'
import { useWalletStore } from '@/stores/wallet'

const walletStore = useWalletStore()
onMounted(() => { walletStore.fetchWallet() })

const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
</script>

<template>
  <div class="flex min-h-screen text-ink font-display overflow-x-hidden">

    <!-- Mobile Header (sem hambúrguer — navegação mobile é via bottom nav + tela /menu) -->
    <div class="md:hidden fixed top-0 left-0 right-0 z-50 bg-surface-1/90 backdrop-blur border-b border-hairline">
      <div class="flex items-center justify-between px-4 h-14">
          <span class="flex items-center gap-2">
            <span class="grid size-7 place-items-center rounded-md bg-primary text-xs font-black tracking-tighter text-canvas">X1</span>
            <span class="font-display text-lg font-black tracking-tight text-ink">ARENA<span class="text-primary">X1</span></span>
          </span>
          <div class="flex items-center gap-2.5">
            <router-link
              to="/wallet"
              class="flex items-center gap-1.5 rounded-xl border border-semantic-success/20 bg-semantic-success/10 px-3 py-2 text-sm font-bold tabular-nums text-semantic-success no-underline transition-colors active:bg-semantic-success/20"
            >
              <Wallet :size="15" />
              {{ walletStore.loaded ? fmtBRL(walletStore.balance) : '···' }}
            </router-link>
            <NotificationBell />
          </div>
      </div>
    </div>

    <!-- Sidebar Component (Desktop only agora — mobile usa a tela /menu) -->
    <DashboardSidebar :isOpen="false" />

    <!-- Spacer lateral para Desktop -->
    <div class="hidden md:block w-64 shrink-0"></div>

    <!-- Área de Conteúdo -->
    <main class="flex-1 flex flex-col relative overflow-y-auto overflow-x-hidden h-screen custom-scrollbar pt-14 pb-20 md:pt-0 md:pb-0">
        <router-view v-slot="{ Component, route }">
            <transition name="page" mode="out-in">
                <component :is="Component" :key="route.path" />
            </transition>
        </router-view>
    </main>

    <!-- Bottom Nav (Mobile) -->
    <DashboardBottomNav />

  </div>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar { width: 6px; }
.custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
.custom-scrollbar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 10px; }
.custom-scrollbar:hover::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); }
</style>
