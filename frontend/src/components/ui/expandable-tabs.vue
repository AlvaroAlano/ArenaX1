<script setup lang="ts">
import { useRoute } from 'vue-router'

defineProps<{
  tabs: TabItem[]
  activeColor?: string
}>()

const route = useRoute()

function isActive(tab: TabItem): boolean {
  if (tab.active !== undefined) return tab.active
  if (tab.match) return tab.match(route.path)
  if (!tab.to) return false
  return tab.to === '/' ? route.path === '/' : route.path.startsWith(tab.to)
}
</script>

<script lang="ts">
import type { Component } from 'vue'

export interface TabItem {
  title: string
  icon: Component
  /** Navegação simples. Omitir e usar `onClick` para uma aba de ação (ex.: abrir um menu). */
  to?: string
  /** Matcher customizado para o estado ativo; padrão: route.path.startsWith(to) */
  match?: (path: string) => boolean
  /** Handler para abas sem `to` (renderiza como <button> em vez de <router-link>). */
  onClick?: () => void
  /** Sobrescreve o estado ativo calculado — necessário para abas de ação. */
  active?: boolean
}
</script>

<template>
  <template v-for="tab in tabs" :key="tab.title">
    <router-link
      v-if="tab.to"
      :to="tab.to"
      class="tab-item group relative flex min-h-[46px] min-w-[46px] shrink-0 items-center justify-center gap-1.5 rounded-full px-3.5 py-3 no-underline transition-[background-color,color,transform] duration-300 ease-[cubic-bezier(0.25,1,0.5,1)] active:scale-[0.9]"
      :class="
        isActive(tab)
          ? ['bg-primary/15', activeColor || 'text-primary']
          : 'text-ink-tertiary hover:bg-surface-2 hover:text-ink-subtle'
      "
    >
      <component
        :is="tab.icon"
        :size="22"
        :stroke-width="isActive(tab) ? 2.25 : 1.75"
        class="shrink-0 transition-[stroke-width,transform] duration-[350ms] ease-[cubic-bezier(0.25,1,0.5,1)]"
        :class="isActive(tab) ? 'scale-110' : 'scale-100'"
      />

      <span class="tab-label-track grid overflow-hidden" :class="isActive(tab) ? 'is-open' : ''">
        <span class="overflow-hidden whitespace-nowrap text-[11px] font-bold leading-none">{{ tab.title }}</span>
      </span>
    </router-link>

    <button
      v-else
      type="button"
      @click="tab.onClick && tab.onClick()"
      class="tab-item group relative flex min-h-[46px] min-w-[46px] shrink-0 items-center justify-center gap-1.5 rounded-full px-3.5 py-3 transition-[background-color,color,transform] duration-300 ease-[cubic-bezier(0.25,1,0.5,1)] active:scale-[0.9]"
      :class="
        isActive(tab)
          ? ['bg-primary/15', activeColor || 'text-primary']
          : 'text-ink-tertiary hover:bg-surface-2 hover:text-ink-subtle'
      "
    >
      <component
        :is="tab.icon"
        :size="22"
        :stroke-width="isActive(tab) ? 2.25 : 1.75"
        class="shrink-0 transition-[stroke-width,transform] duration-[350ms] ease-[cubic-bezier(0.25,1,0.5,1)]"
        :class="isActive(tab) ? 'scale-110' : 'scale-100'"
      />

      <span class="tab-label-track grid overflow-hidden" :class="isActive(tab) ? 'is-open' : ''">
        <span class="overflow-hidden whitespace-nowrap text-[11px] font-bold leading-none">{{ tab.title }}</span>
      </span>
    </button>
  </template>
</template>

<style scoped>
.tab-label-track {
  grid-template-columns: 0fr;
  opacity: 0;
  transition:
    grid-template-columns 0.42s cubic-bezier(0.25, 1, 0.5, 1),
    opacity 0.3s ease-out;
}
.tab-label-track.is-open {
  grid-template-columns: 1fr;
  opacity: 1;
}

@media (prefers-reduced-motion: reduce) {
  .tab-label-track,
  .tab-item :deep(svg) {
    transition: none !important;
  }
}
</style>
