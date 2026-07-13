<script setup lang="ts">
import { ShieldCheck } from '@lucide/vue'

// Mensagem de jogo responsável — enquadramento de COMPETIÇÃO DE HABILIDADE,
// nunca de aposta/cassino (decisão de posicionamento legal, ver
// mapa-riscos-legais.md). A cópia mora só aqui: ajustar num lugar reflete em
// todos os pontos onde o componente é usado (rodapé, login/cadastro, depósito).
//   variant="tag"      → linha curta e discreta (rodapés, telas de entrada)
//   variant="reminder" → bloco maior pra momentos sensíveis (depósito)
withDefaults(defineProps<{ variant?: 'tag' | 'reminder' }>(), { variant: 'tag' })
</script>

<template>
  <p v-if="variant === 'tag'" class="flex items-center justify-center gap-1.5 text-caption text-ink-tertiary">
    <ShieldCheck :size="14" class="shrink-0" />
    <span><strong class="font-semibold text-ink-subtle">+18</strong> · Jogue com responsabilidade</span>
  </p>

  <div v-else class="flex items-start gap-2.5 rounded-xl border border-hairline bg-surface-1/60 p-3.5 text-body-sm text-ink-subtle">
    <ShieldCheck :size="18" class="mt-0.5 shrink-0 text-ink-tertiary" />
    <p>
      A ArenaX1 é competição de habilidade. Jogue por diversão, com equilíbrio — e saiba a hora de parar.
      <strong class="font-semibold text-ink-subtle">+18</strong>
    </p>
  </div>
</template>
