<template>
  <div class="flex flex-col min-h-screen">
    <AppHeader />
    <!-- Spacer p/ o header fixo; inclui o safe-area do topo (notch do iPhone) -->
    <div class="h-[calc(4rem+env(safe-area-inset-top))] md:h-[calc(76px+env(safe-area-inset-top))]"></div>
    <main class="flex-1 flex flex-col relative">
      <router-view v-slot="{ Component, route }">
        <transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </transition>
      </router-view>
    </main>
    <AppFooter />
    <!-- Espaço p/ a barra fixa inferior não cobrir o fim do rodapé no mobile -->
    <div class="md:hidden" style="height: calc(64px + env(safe-area-inset-bottom))"></div>
    <BottomNav />
  </div>
</template>

<script setup lang="ts">
import AppHeader from '@/components/layout/AppHeader.vue'
import AppFooter from '@/components/layout/AppFooter.vue'
import BottomNav from '@/components/layout/BottomNav.vue'
</script>
