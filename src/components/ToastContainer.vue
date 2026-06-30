<script setup lang="ts">
import { useToast } from '@/composables/useToast'

const { toasts, remove } = useToast()

const iconPaths: Record<string, string> = {
  success: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
  error: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z',
  info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
}

const colorClasses: Record<string, string> = {
  success: 'text-semantic-success',
  error: 'text-semantic-danger',
  info: 'text-primary',
}
</script>

<template>
  <div
    aria-live="polite"
    aria-atomic="true"
    class="fixed bottom-4 right-4 z-[100] flex flex-col gap-3 w-full max-w-sm pointer-events-none"
  >
    <transition-group
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 translate-y-2"
      enter-to-class="opacity-100 translate-y-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-for="toast in toasts"
        :key="toast.id"
        role="status"
        class="bg-surface-1 border border-hairline-strong rounded-lg shadow-lg p-4 flex items-start gap-3 pointer-events-auto"
      >
        <svg
          class="w-5 h-5 shrink-0 mt-0.5"
          :class="colorClasses[toast.type]"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="iconPaths[toast.type]" />
        </svg>
        <p class="text-body-sm text-ink flex-1 leading-relaxed">{{ toast.message }}</p>
        <button
          @click="remove(toast.id)"
          aria-label="Fechar notificação"
          class="text-ink-tertiary hover:text-ink transition-colors shrink-0"
        >
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </transition-group>
  </div>
</template>
