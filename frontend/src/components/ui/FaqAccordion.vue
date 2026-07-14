<script setup lang="ts">
import { ref, useId } from 'vue'
import { Plus } from '@lucide/vue'

/* Acordeão de FAQ reutilizável (landing, Como Funciona).
   Um item aberto por vez; a animação de altura usa o truque de
   grid-template-rows 0fr→1fr, que dispensa medir o conteúdo em JS. */
export interface FaqItem {
  q: string
  a: string
}

defineProps<{ items: FaqItem[] }>()

const uid = useId()
const open = ref<number | null>(null)

function toggle(i: number) {
  open.value = open.value === i ? null : i
}
</script>

<template>
  <div class="flex flex-col gap-3">
    <div
      v-for="(item, i) in items"
      :key="item.q"
      class="rounded-xl border bg-surface-2/80 backdrop-blur transition-colors duration-300"
      :class="open === i ? 'border-primary/35' : 'border-hairline hover:border-hairline-strong'"
    >
      <button
        :id="`${uid}-q-${i}`"
        type="button"
        class="flex w-full cursor-pointer items-center justify-between gap-4 px-5 py-4 text-left text-[15px] font-bold text-ink sm:px-6 sm:py-5 sm:text-base"
        :aria-expanded="open === i"
        :aria-controls="`${uid}-a-${i}`"
        @click="toggle(i)"
      >
        {{ item.q }}
        <span
          class="grid size-7 shrink-0 place-items-center rounded-full transition-all duration-300 motion-reduce:transition-none"
          :class="open === i ? 'rotate-45 bg-primary text-canvas' : 'bg-surface-3 text-primary'"
        >
          <Plus :size="15" />
        </span>
      </button>
      <div
        :id="`${uid}-a-${i}`"
        role="region"
        :aria-labelledby="`${uid}-q-${i}`"
        class="grid transition-[grid-template-rows] duration-300 ease-out motion-reduce:transition-none"
        :class="open === i ? 'grid-rows-[1fr]' : 'grid-rows-[0fr]'"
      >
        <div class="overflow-hidden">
          <p class="px-5 pb-5 text-sm leading-relaxed text-ink-subtle sm:px-6">{{ item.a }}</p>
        </div>
      </div>
    </div>
  </div>
</template>
