<script setup lang="ts">
import { Download } from '@lucide/vue'
import { usePwaInstall } from '@/composables/usePwaInstall'

withDefaults(defineProps<{ variant?: 'solid' | 'ghost' }>(), { variant: 'solid' })

const { canInstall, install } = usePwaInstall()
</script>

<template>
  <button
    v-if="canInstall"
    @click="install"
    :class="[
      'flex items-center gap-2 rounded-lg text-sm font-bold transition-colors no-underline',
      variant === 'solid'
        ? 'bg-primary text-canvas px-4 py-2.5 hover:bg-primary-hover'
        : 'px-3 py-2.5 text-ink-subtle hover:bg-surface-2 hover:text-ink',
    ]"
  >
    <Download :size="18" />
    Instalar App
  </button>
</template>
