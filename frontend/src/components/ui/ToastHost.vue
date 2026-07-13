<script setup lang="ts">
import { useToastStore } from '@/stores/toast'
import { CheckCircle2, AlertCircle, Info, X } from '@lucide/vue'

const toast = useToastStore()

const iconFor = { success: CheckCircle2, error: AlertCircle, info: Info }
const accentFor = {
  success: 'border-semantic-success/30 text-semantic-success',
  error: 'border-semantic-error/30 text-semantic-error',
  info: 'border-accent/30 text-accent',
}
</script>

<template>
  <Teleport to="body">
    <div class="pointer-events-none fixed inset-x-0 top-0 z-[10000] flex flex-col items-center gap-2 px-4 pt-[calc(env(safe-area-inset-top,0px)+0.75rem)]">
      <TransitionGroup name="toast">
        <div
          v-for="t in toast.toasts"
          :key="t.id"
          class="pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-xl border bg-surface-1/95 p-3.5 shadow-card-premium backdrop-blur"
          :class="accentFor[t.type]"
        >
          <component :is="iconFor[t.type]" :size="18" class="mt-0.5 shrink-0" />
          <p class="flex-1 text-body-sm font-medium text-ink">{{ t.message }}</p>
          <button @click="toast.dismiss(t.id)" class="shrink-0 text-ink-tertiary transition-colors hover:text-ink">
            <X :size="16" />
          </button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(-12px);
}
</style>
