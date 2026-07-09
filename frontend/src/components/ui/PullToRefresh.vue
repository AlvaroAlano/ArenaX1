<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { RefreshCw } from '@lucide/vue'

/* ── Puxar pra baixo no topo da tela recarrega o app — gesto padrão de
   app nativo. Funciona em cima de QUALQUER container rolável: acha o
   ancestral rolável mais próximo do toque (a área do Dashboard rola dentro
   de <main overflow-y-auto>, já as páginas públicas rolam na janela). ── */
const PULL_THRESHOLD = 72
const MAX_PULL = 110
const RESISTANCE = 0.45

const pulling = ref(false)
const refreshing = ref(false)
const pullDistance = ref(0)

let startY = 0
let scrollEl: HTMLElement | null = null
let tracking = false

function getScrollParent(el: HTMLElement | null): HTMLElement {
  if (!el || el === document.body || el === document.documentElement) {
    return (document.scrollingElement as HTMLElement) || document.documentElement
  }
  const style = getComputedStyle(el)
  if ((style.overflowY === 'auto' || style.overflowY === 'scroll') && el.scrollHeight > el.clientHeight) {
    return el
  }
  return getScrollParent(el.parentElement)
}

function onTouchStart(e: TouchEvent) {
  const touch = e.touches[0]
  if (refreshing.value || e.touches.length > 1 || !touch) return
  scrollEl = getScrollParent(e.target as HTMLElement)
  if (scrollEl.scrollTop > 0) {
    tracking = false
    return
  }
  startY = touch.clientY
  tracking = true
}

function onTouchMove(e: TouchEvent) {
  const touch = e.touches[0]
  if (!tracking || refreshing.value || !touch) return
  const delta = touch.clientY - startY

  if (delta <= 0 || (scrollEl && scrollEl.scrollTop > 0)) {
    tracking = false
    pulling.value = false
    pullDistance.value = 0
    return
  }

  e.preventDefault()
  pulling.value = true
  pullDistance.value = Math.min(delta * RESISTANCE, MAX_PULL)
}

function onTouchEnd() {
  if (!tracking) return
  tracking = false

  if (pullDistance.value >= PULL_THRESHOLD) {
    refreshing.value = true
    pullDistance.value = PULL_THRESHOLD
    window.location.reload()
  } else {
    pulling.value = false
    pullDistance.value = 0
  }
}

onMounted(() => {
  document.addEventListener('touchstart', onTouchStart, { passive: true })
  document.addEventListener('touchmove', onTouchMove, { passive: false })
  document.addEventListener('touchend', onTouchEnd, { passive: true })
  document.addEventListener('touchcancel', onTouchEnd, { passive: true })
})
onUnmounted(() => {
  document.removeEventListener('touchstart', onTouchStart)
  document.removeEventListener('touchmove', onTouchMove)
  document.removeEventListener('touchend', onTouchEnd)
  document.removeEventListener('touchcancel', onTouchEnd)
})
</script>

<template>
  <Teleport to="body">
    <div
      class="pointer-events-none fixed inset-x-0 top-0 z-[9999] flex justify-center"
      :style="{
        transform: `translateY(${pullDistance - 40}px)`,
        transition: pulling ? 'none' : 'transform 250ms ease',
        paddingTop: 'env(safe-area-inset-top, 0px)',
      }"
    >
      <div
        v-if="pullDistance > 0 || refreshing"
        class="mt-3 grid size-9 place-items-center rounded-full border border-hairline-strong bg-surface-1 text-primary shadow-lg"
      >
        <RefreshCw
          :size="18"
          :class="refreshing ? 'animate-spin' : ''"
          :style="!refreshing ? { transform: `rotate(${pullDistance * 3}deg)` } : {}"
        />
      </div>
    </div>
  </Teleport>
</template>
