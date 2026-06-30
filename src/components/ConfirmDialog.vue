<script setup lang="ts">
import { ref, watch, nextTick } from 'vue'
import { useConfirm } from '@/composables/useConfirm'

const { state, handleConfirm, handleCancel } = useConfirm()
const cancelButton = ref<HTMLButtonElement | null>(null)

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') handleCancel()
}

watch(
  () => state.open,
  (open) => {
    if (open) {
      window.addEventListener('keydown', onKeydown)
      nextTick(() => cancelButton.value?.focus())
    } else {
      window.removeEventListener('keydown', onKeydown)
    }
  },
)
</script>

<template>
  <div
    v-if="state.open"
    class="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/70"
    @click.self="handleCancel"
  >
    <div
      role="alertdialog"
      aria-modal="true"
      aria-labelledby="confirm-dialog-title"
      aria-describedby="confirm-dialog-message"
      class="w-full max-w-sm bg-surface-1 border border-hairline-strong p-6 rounded-lg space-y-5"
    >
      <div>
        <h3 id="confirm-dialog-title" class="text-card-title font-display font-medium text-ink mb-2">
          {{ state.title }}
        </h3>
        <p id="confirm-dialog-message" class="text-body-sm text-ink-subtle leading-relaxed">
          {{ state.message }}
        </p>
      </div>

      <div class="flex gap-3">
        <button
          ref="cancelButton"
          @click="handleCancel"
          class="flex-1 bg-surface-2 hover:bg-surface-3 border border-hairline text-ink py-2.5 rounded-md text-button font-medium transition-colors"
        >
          {{ state.cancelLabel }}
        </button>
        <button
          @click="handleConfirm"
          class="flex-1 text-on-primary py-2.5 rounded-md text-button font-medium transition-colors"
          :class="state.danger ? 'bg-semantic-danger hover:opacity-90' : 'bg-primary hover:bg-primary-hover'"
        >
          {{ state.confirmLabel }}
        </button>
      </div>
    </div>
  </div>
</template>
