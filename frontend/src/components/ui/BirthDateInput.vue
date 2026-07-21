<script setup lang="ts">
import { ref, watch, nextTick } from 'vue'
import { CalendarDays } from '@lucide/vue'

// Padrão de mercado pra data de nascimento (Nubank/Itaú/PicPay/C6): campo
// segmentado DD/MM/AAAA digitado direto, não calendário — o usuário já sabe
// a própria data de cor, então digitar é sempre mais rápido que navegar um
// calendário (mesmo com atalho de ano). Calendário visual faz mais sentido
// pra escolher uma data futura, onde contexto visual (dia da semana, "quanto
// falta") importa — não é o caso aqui.

const props = defineProps<{ modelValue: string }>() // ISO yyyy-mm-dd, '' quando incompleto
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

const day = ref('')
const month = ref('')
const year = ref('')

const dayEl = ref<HTMLInputElement | null>(null)
const monthEl = ref<HTMLInputElement | null>(null)
const yearEl = ref<HTMLInputElement | null>(null)

// Só sincroniza os campos a partir de fora quando o valor for uma data
// COMPLETA de verdade. Enquanto o usuário digita/apaga, este componente emite
// '' pro v-model a cada estado incompleto (esperado) — se o watcher reagisse
// a esse '' limpando os 3 campos, qualquer backspace no meio da digitação
// apagaria a data inteira (o valor ecoa de volta como prop e vira um loop).
function syncFromModel(iso: string) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso)
  if (m) {
    year.value = m[1]!
    month.value = m[2]!
    day.value = m[3]!
  }
}
syncFromModel(props.modelValue)
watch(() => props.modelValue, syncFromModel)

function emitIfComplete() {
  if (day.value.length === 2 && month.value.length === 2 && year.value.length === 4) {
    emit('update:modelValue', `${year.value}-${month.value}-${day.value}`)
  } else {
    emit('update:modelValue', '')
  }
}

function onDigitsOnly(raw: string): string {
  return raw.replace(/\D/g, '')
}

function onDayInput(e: Event) {
  const el = e.target as HTMLInputElement
  let v = onDigitsOnly(el.value).slice(0, 2)
  if (v.length === 2 && Number(v) > 31) v = '31'
  day.value = v
  el.value = v
  if (v.length === 2) nextTick(() => monthEl.value?.focus())
  emitIfComplete()
}
function onMonthInput(e: Event) {
  const el = e.target as HTMLInputElement
  let v = onDigitsOnly(el.value).slice(0, 2)
  if (v.length === 2 && Number(v) > 12) v = '12'
  month.value = v
  el.value = v
  if (v.length === 2) nextTick(() => yearEl.value?.focus())
  emitIfComplete()
}
function onYearInput(e: Event) {
  const el = e.target as HTMLInputElement
  const v = onDigitsOnly(el.value).slice(0, 4)
  year.value = v
  el.value = v
  emitIfComplete()
}

// Backspace num campo vazio pula pro anterior e apaga o último dígito dele —
// assume controle manual da deleção (preventDefault) em vez de deixar o
// navegador decidir: mudar o foco no meio do próprio evento de keydown deixa
// ambíguo em qual campo o navegador aplicaria a deleção default.
function onDayKeydown(e: KeyboardEvent) {
  if (e.key === 'ArrowRight' && (e.target as HTMLInputElement).selectionStart === day.value.length) monthEl.value?.focus()
}
function onMonthKeydown(e: KeyboardEvent) {
  if (e.key === 'Backspace' && month.value === '') {
    e.preventDefault()
    day.value = day.value.slice(0, -1)
    emitIfComplete()
    dayEl.value?.focus()
  } else if (e.key === 'ArrowLeft' && (e.target as HTMLInputElement).selectionStart === 0) {
    dayEl.value?.focus()
  } else if (e.key === 'ArrowRight' && (e.target as HTMLInputElement).selectionStart === month.value.length) {
    yearEl.value?.focus()
  }
}
function onYearKeydown(e: KeyboardEvent) {
  if (e.key === 'Backspace' && year.value === '') {
    e.preventDefault()
    month.value = month.value.slice(0, -1)
    emitIfComplete()
    monthEl.value?.focus()
  } else if (e.key === 'ArrowLeft' && (e.target as HTMLInputElement).selectionStart === 0) {
    monthEl.value?.focus()
  }
}

// Cola "21/07/1998", "21071998" etc de uma vez e distribui pelos 3 campos —
// evita forçar o usuário a colar segmento por segmento.
function onPaste(e: ClipboardEvent) {
  const text = e.clipboardData?.getData('text') || ''
  const digits = onDigitsOnly(text)
  if (digits.length >= 8) {
    e.preventDefault()
    day.value = digits.slice(0, 2)
    month.value = digits.slice(2, 4)
    year.value = digits.slice(4, 8)
    emitIfComplete()
    nextTick(() => yearEl.value?.focus())
  }
}
</script>

<template>
  <div class="group flex h-12 w-full items-center gap-1 rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 relative transition-all focus-within:border-primary focus-within:ring-2 focus-within:ring-primary">
    <CalendarDays :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
    <input
      ref="dayEl"
      :value="day"
      @input="onDayInput"
      @keydown="onDayKeydown"
      @paste="onPaste"
      type="text"
      inputmode="numeric"
      maxlength="2"
      placeholder="DD"
      aria-label="Dia de nascimento"
      class="w-6 bg-transparent text-center text-body-sm text-ink placeholder-ink-tertiary outline-none"
    />
    <span class="text-ink-tertiary">/</span>
    <input
      ref="monthEl"
      :value="month"
      @input="onMonthInput"
      @keydown="onMonthKeydown"
      @paste="onPaste"
      type="text"
      inputmode="numeric"
      maxlength="2"
      placeholder="MM"
      aria-label="Mês de nascimento"
      class="w-6 bg-transparent text-center text-body-sm text-ink placeholder-ink-tertiary outline-none"
    />
    <span class="text-ink-tertiary">/</span>
    <input
      ref="yearEl"
      :value="year"
      @input="onYearInput"
      @keydown="onYearKeydown"
      @paste="onPaste"
      type="text"
      inputmode="numeric"
      maxlength="4"
      placeholder="AAAA"
      aria-label="Ano de nascimento"
      class="w-11 bg-transparent text-center text-body-sm text-ink placeholder-ink-tertiary outline-none"
    />
  </div>
</template>
