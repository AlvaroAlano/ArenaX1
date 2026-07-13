<script setup lang="ts">
// Suporte = "e-mail interno" (opção C): um formulário que grava um ticket
// ESTRUTURADO, já amarrado ao user_id logado (some o problema de matching do
// mailto), e ALERTA os admins. A resposta do admin é manual por ora (SQL/portal)
// até a Fila de revisão (regra 4.4) ganhar thread + tela de lista. Sem mailto
// exposto de propósito.
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { Headset, Send, AlertTriangle, CheckCircle2 } from '@lucide/vue'
import { api } from '@/services/api'

const route = useRoute()

const CATEGORIES = [
  { value: 'other', label: 'Assunto geral' },
  { value: 'badge_contest', label: 'Contestar histórico de ausências' },
  { value: 'match', label: 'Problema numa partida' },
  { value: 'wallet', label: 'Carteira, saldo ou saque' },
  { value: 'account', label: 'Conta ou login' },
] as const

const validValues = CATEGORIES.map((c) => c.value) as readonly string[]
const initialCategory = typeof route.query.c === 'string' && validValues.includes(route.query.c)
  ? route.query.c
  : 'other'

const category = ref<string>(initialCategory)
const message = ref('')
const sending = ref(false)
const error = ref('')
const done = ref(false)

const canSend = computed(() => message.value.trim().length >= 5 && !sending.value)

const submit = async () => {
  if (!canSend.value) return
  sending.value = true
  error.value = ''
  try {
    await api.post('/api/support/tickets', {
      category: category.value,
      message: message.value.trim(),
    })
    done.value = true
  } catch (err: any) {
    error.value = err?.message || 'Não foi possível enviar sua mensagem. Tente novamente.'
  } finally {
    sending.value = false
  }
}

const sendAnother = () => {
  message.value = ''
  error.value = ''
  done.value = false
}
</script>

<template>
  <div class="mx-auto max-w-2xl space-y-6 p-6 md:p-10">
    <!-- Cabeçalho -->
    <header class="space-y-1.5">
      <div class="flex items-center gap-2.5">
        <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-primary/15 text-primary">
          <Headset :size="20" />
        </span>
        <h1 class="font-display text-2xl font-black text-ink">Suporte</h1>
      </div>
      <p class="text-body-sm text-ink-subtle">
        Problema numa partida, dúvida de saldo, ou precisa contestar algo? Escreve aqui — a mensagem
        chega direto pra nossa equipe, já amarrada à sua conta.
      </p>
    </header>

    <!-- Sucesso -->
    <div
      v-if="done"
      class="space-y-4 rounded-2xl border border-primary/25 bg-primary/[0.06] p-6 text-center"
    >
      <CheckCircle2 :size="40" class="mx-auto text-primary" />
      <div class="space-y-1">
        <h2 class="font-display text-lg font-black text-ink">Mensagem enviada ✅</h2>
        <p class="text-body-sm text-ink-subtle">
          Recebemos seu contato e a equipe vai analisar. A resposta chega pelas suas
          <strong class="text-ink">notificações</strong> aqui no app.
        </p>
      </div>
      <button
        type="button"
        class="rounded-xl border border-hairline bg-surface-2 px-4 py-2.5 font-bold text-ink transition-colors hover:border-hairline-strong"
        @click="sendAnother"
      >
        Enviar outra mensagem
      </button>
    </div>

    <!-- Formulário -->
    <form v-else class="space-y-5 rounded-2xl border border-hairline bg-surface-2 p-5" @submit.prevent="submit">
      <div class="space-y-1.5">
        <label class="block text-[10px] font-bold uppercase tracking-wider text-ink-subtle" for="support-category">
          Assunto
        </label>
        <select
          id="support-category"
          v-model="category"
          class="w-full rounded-xl border border-hairline bg-surface-1 px-3.5 py-3 text-body-sm text-ink outline-none transition-colors focus:border-primary/50"
        >
          <option v-for="c in CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
        </select>
      </div>

      <div class="space-y-1.5">
        <label class="block text-[10px] font-bold uppercase tracking-wider text-ink-subtle" for="support-message">
          Sua mensagem
        </label>
        <textarea
          id="support-message"
          v-model="message"
          rows="6"
          maxlength="4000"
          placeholder="Conte o que aconteceu com o máximo de detalhes (datas, sala da partida, adversário…)."
          class="w-full resize-y rounded-xl border border-hairline bg-surface-1 px-3.5 py-3 text-body-sm text-ink placeholder:text-ink-tertiary outline-none transition-colors focus:border-primary/50"
        ></textarea>
        <p class="text-caption text-ink-tertiary">{{ message.trim().length }}/4000 · mínimo de 5 caracteres</p>
      </div>

      <p v-if="error" class="rounded-xl border border-semantic-error/30 bg-semantic-error/10 px-3.5 py-2.5 text-body-sm text-semantic-error">
        {{ error }}
      </p>

      <button
        type="submit"
        :disabled="!canSend"
        class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 font-bold text-canvas transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
      >
        <Send :size="18" /> {{ sending ? 'Enviando…' : 'Enviar mensagem' }}
      </button>
    </form>

    <!-- Contestação do selo de abandono (regra 1.4) -->
    <div class="space-y-2 rounded-2xl border border-amber-500/25 bg-amber-500/[0.06] p-5">
      <div class="flex items-center gap-2">
        <AlertTriangle :size="18" class="shrink-0 text-amber-500" />
        <h2 class="font-bold text-ink">Recebeu um aviso de "histórico de ausências"?</h2>
      </div>
      <p class="text-body-sm text-ink-subtle">
        Se alguma partida foi marcada como ausência por um motivo justo (queda de energia, internet,
        problema no console…), escolha <strong class="text-ink">"Contestar histórico de ausências"</strong>
        acima e conte o que aconteceu <strong class="text-ink">antes do prazo de 48h</strong>. A gente
        analisa antes de o selo ficar visível no seu perfil.
      </p>
    </div>
  </div>
</template>
