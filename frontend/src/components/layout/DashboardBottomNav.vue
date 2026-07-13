<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { LayoutDashboard, Swords, Award, Menu, Plus, Trophy } from '@lucide/vue'
import ExpandableTabs, { type TabItem } from '@/components/ui/expandable-tabs.vue'

const route = useRoute()
const router = useRouter()
const isMenuOpen = ref(false)

const closeMenu = () => { isMenuOpen.value = false }
const toggleMenu = () => { isMenuOpen.value = !isMenuOpen.value }

const goCreateChallenge = () => {
  closeMenu()
  router.push('/create-challenge')
}

const goCreateTournament = () => {
  closeMenu()
  router.push('/create-tournament')
}

const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Escape') closeMenu()
}
onMounted(() => window.addEventListener('keydown', onKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))
watch(() => route.path, closeMenu)

const isCreateActive = computed(() => isMenuOpen.value || route.path.startsWith('/create-challenge') || route.path.startsWith('/create-tournament') || route.path.startsWith('/my-tournaments'))

const tabsLeft = computed<TabItem[]>(() => [
  { title: 'Painel', icon: LayoutDashboard, to: '/dashboard', match: (p) => p === '/dashboard' },
  { title: 'Desafios', icon: Swords, to: '/challenges' },
])
const tabsRight = computed<TabItem[]>(() => [
  { title: 'Torneios', icon: Award, to: '/tournaments' },
  {
    title: 'Menu',
    icon: Menu,
    to: '/menu',
    match: (p) => ['/menu', '/wallet', '/settings', '/referrals', '/support'].some((prefix) => p.startsWith(prefix)),
  },
])
</script>

<template>
  <!-- Fecha o menu ao tocar fora -->
  <div v-if="isMenuOpen" class="fixed inset-0 z-[9989] md:hidden" @click="closeMenu" aria-hidden="true"></div>

  <nav
    class="fixed inset-x-0 bottom-0 z-[9990] border-t border-hairline-strong bg-surface-1/95 shadow-[0_-8px_24px_-12px_rgba(0,0,0,0.5)] backdrop-blur-xl md:hidden"
    style="padding-bottom: env(safe-area-inset-bottom)"
  >
    <div
      class="relative mx-auto flex max-w-lg items-center justify-around gap-1 px-2 py-1.5"
    >
      <!-- Menu do botão criar -->
      <Transition name="create-menu">
        <div
          v-if="isMenuOpen"
          class="absolute bottom-full left-1/2 mb-3 w-72 -translate-x-1/2 rounded-2xl border border-hairline-strong bg-surface-1 p-2 shadow-card-premium backdrop-blur-xl"
        >
          <button
            type="button"
            @click="goCreateChallenge"
            class="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left transition-colors hover:bg-surface-2"
          >
            <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
              <Swords :size="19" />
            </span>
            <span class="flex-1">
              <span class="block text-body-sm font-semibold text-ink">Criar Desafio</span>
              <span class="block text-caption text-ink-tertiary">Desafie um adversário 1v1</span>
            </span>
          </button>

          <button
            type="button"
            @click="goCreateTournament"
            class="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left transition-colors hover:bg-surface-2"
          >
            <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
              <Trophy :size="19" />
            </span>
            <span class="flex-1">
              <span class="block text-body-sm font-semibold text-ink">Criar Torneio</span>
              <span class="block text-caption text-ink-tertiary">Torneio local com seus amigos</span>
            </span>
          </button>
        </div>
      </Transition>

      <ExpandableTabs :tabs="tabsLeft" />

      <!-- Botão Criar: destacado, sempre "+" -->
      <button
        type="button"
        @click="toggleMenu"
        :aria-expanded="isMenuOpen"
        aria-label="Abrir opções de criação"
        class="relative mx-0.5 grid size-[50px] shrink-0 place-items-center rounded-full bg-gradient-to-br from-accent to-primary text-canvas shadow-glow-primary transition-all duration-200 active:scale-90"
        :class="isCreateActive ? 'ring-2 ring-accent/50 ring-offset-2 ring-offset-surface-1' : ''"
      >
        <Plus :size="24" :stroke-width="2.5" />
      </button>

      <ExpandableTabs :tabs="tabsRight" />
    </div>
  </nav>
</template>

<style scoped>
.create-menu-enter-active {
  transition: opacity 0.2s ease, transform 0.22s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.create-menu-leave-active {
  transition: opacity 0.16s ease-in, transform 0.2s ease-in;
}
.create-menu-enter-from {
  opacity: 0;
  transform: translate(-50%, 10px) scale(0.96);
}
.create-menu-leave-to {
  opacity: 0;
  transform: translate(-50%, 14px) scale(0.97);
}

@media (prefers-reduced-motion: reduce) {
  .create-menu-enter-active,
  .create-menu-leave-active {
    transition: none !important;
  }
}
</style>
