<script setup lang="ts">
import { onUnmounted } from 'vue'
import { useConfirmStore } from '@/stores/confirm'
import { AlertTriangle, HelpCircle } from '@lucide/vue'

const confirm = useConfirmStore()

function onConfirm() {
  confirm.respond(true)
}
function onCancel() {
  confirm.respond(false)
}

// ESC cancela, Enter confirma — teclado sem obrigar o mouse.
function onKey(e: KeyboardEvent) {
  if (!confirm.open) return
  if (e.key === 'Escape') onCancel()
  else if (e.key === 'Enter') onConfirm()
}
window.addEventListener('keydown', onKey)
onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <Teleport to="body">
    <Transition name="confirm">
      <div
        v-if="confirm.open"
        class="fixed inset-0 z-[10001] flex items-end justify-center p-4 sm:items-center"
        @click.self="onCancel"
      >
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="onCancel"></div>
        <div
          role="alertdialog"
          aria-modal="true"
          class="relative w-full max-w-sm rounded-2xl border border-hairline bg-surface-1 p-5 shadow-card-premium"
        >
          <div class="flex items-start gap-3">
            <span
              class="grid size-10 shrink-0 place-items-center rounded-xl"
              :class="confirm.options.tone === 'danger' ? 'bg-semantic-error/10 text-semantic-error' : 'bg-primary/10 text-primary'"
            >
              <component :is="confirm.options.tone === 'danger' ? AlertTriangle : HelpCircle" :size="20" />
            </span>
            <div class="flex-1 pt-0.5">
              <h3 class="font-display text-base font-bold text-ink">{{ confirm.options.title }}</h3>
              <p class="mt-1 whitespace-pre-line text-body-sm text-ink-subtle">{{ confirm.options.message }}</p>
            </div>
          </div>
          <div class="mt-5 flex gap-2.5">
            <button
              type="button"
              @click="onCancel"
              class="h-11 flex-1 rounded-lg border border-hairline bg-surface-2 text-body-sm font-semibold text-ink-subtle transition-colors hover:border-hairline-strong hover:text-ink"
            >
              {{ confirm.options.cancelText }}
            </button>
            <button
              type="button"
              @click="onConfirm"
              class="h-11 flex-1 rounded-lg text-body-sm font-bold transition-colors"
              :class="confirm.options.tone === 'danger' ? 'bg-semantic-error text-white hover:bg-semantic-error/90' : 'bg-primary text-canvas hover:bg-primary-hover'"
            >
              {{ confirm.options.confirmText }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.confirm-enter-active,
.confirm-leave-active {
  transition: opacity 0.2s ease;
}
.confirm-enter-from,
.confirm-leave-to {
  opacity: 0;
}
</style>
