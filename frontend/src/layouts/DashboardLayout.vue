<script setup lang="ts">
import DashboardSidebar from '@/components/layout/DashboardSidebar.vue'
import DashboardBottomNav from '@/components/layout/DashboardBottomNav.vue'
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
          <span class="text-xs font-bold text-semantic-success bg-semantic-success/10 px-2.5 py-1 rounded-lg">
            R$ 0.00
          </span>
      </div>
    </div>

    <!-- Sidebar Component (Desktop only agora — mobile usa a tela /menu) -->
    <DashboardSidebar :isOpen="false" />

    <!-- Spacer lateral para Desktop -->
    <div class="hidden md:block w-64 shrink-0"></div>

    <!-- Área de Conteúdo -->
    <main class="flex-1 flex flex-col relative overflow-y-auto h-screen custom-scrollbar pt-14 pb-20 md:pt-0 md:pb-0">
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
