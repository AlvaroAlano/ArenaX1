<script setup lang="ts">
import { ref } from 'vue'
import { prefersReduce } from '@/composables/useReveal'

/* Cartão com tilt 3D sutil guiado pelo ponteiro + brilho que segue o cursor.
   Só ativa em dispositivos com ponteiro fino e hover real (desktop) e
   respeita prefers-reduced-motion — no touch o card fica estático, sem
   nenhum listener fazendo trabalho à toa no scroll. */
const props = withDefaults(defineProps<{ maxTilt?: number }>(), { maxTilt: 7 })

const el = ref<HTMLElement>()
const transform = ref('')
const glare = ref({ x: 50, y: 50, o: 0 })

function canTilt(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia('(hover: hover) and (pointer: fine)').matches &&
    !prefersReduce()
  )
}

function onMove(e: PointerEvent) {
  if (!el.value || !canTilt()) return
  const r = el.value.getBoundingClientRect()
  const px = (e.clientX - r.left) / r.width
  const py = (e.clientY - r.top) / r.height
  const rx = (0.5 - py) * props.maxTilt * 2
  const ry = (px - 0.5) * props.maxTilt * 2
  transform.value = `perspective(900px) rotateX(${rx.toFixed(2)}deg) rotateY(${ry.toFixed(2)}deg)`
  glare.value = { x: px * 100, y: py * 100, o: 1 }
}

function onLeave() {
  transform.value = ''
  glare.value = { x: 50, y: 50, o: 0 }
}
</script>

<template>
  <div
    ref="el"
    class="tilt-card"
    :style="transform ? { transform } : undefined"
    @pointermove="onMove"
    @pointerleave="onLeave"
  >
    <slot />
    <span
      aria-hidden="true"
      class="tilt-glare"
      :style="{
        opacity: glare.o,
        background: `radial-gradient(circle at ${glare.x}% ${glare.y}%, rgba(200, 240, 60, 0.10), transparent 58%)`,
      }"
    />
  </div>
</template>

<style scoped>
.tilt-card {
  position: relative;
  transform-style: preserve-3d;
  transition: transform 0.2s ease-out;
  will-change: transform;
}

.tilt-glare {
  position: absolute;
  inset: 0;
  border-radius: inherit;
  pointer-events: none;
  transition: opacity 0.35s ease;
}
</style>
