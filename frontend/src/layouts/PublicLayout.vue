<template>
  <div class="flex flex-col min-h-screen">
    <AppHeader />
    <div class="h-16 md:h-[76px]"></div> <!-- Spacer for fixed header -->
    <main class="flex-1 flex flex-col relative">
      <router-view v-slot="{ Component, route }">
        <transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </transition>
      </router-view>
    </main>
    <AppFooter />
    <BottomNav />
  </div>
</template>

<script setup lang="ts">
import AppHeader from '@/components/layout/AppHeader.vue'
import AppFooter from '@/components/layout/AppFooter.vue'
import BottomNav from '@/components/layout/BottomNav.vue'
</script>
