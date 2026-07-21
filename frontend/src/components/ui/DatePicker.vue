<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { CalendarDays, ChevronLeft, ChevronRight } from '@lucide/vue'

const props = defineProps<{
  modelValue: string // ISO yyyy-mm-dd, '' quando vazio
  placeholder?: string
  max?: string // ISO yyyy-mm-dd — ex.: hoje, pra nascimento não aceitar data futura
  min?: string
}>()
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

const WEEKDAYS = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
const MONTHS = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']

function parseIso(iso: string): Date | null {
  if (!iso) return null
  const [y, m, d] = iso.split('-').map(Number)
  if (!y || !m || !d) return null
  return new Date(y, m - 1, d)
}
function toIso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}
function isSameDay(a: Date, b: Date | null) {
  return !!b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

const today = new Date()
today.setHours(0, 0, 0, 0)

const selected = computed(() => parseIso(props.modelValue))
const maxDate = computed(() => parseIso(props.max || ''))
const minDate = computed(() => parseIso(props.min || ''))

const open = ref(false)
const view = ref<'days' | 'years'>('days')
const rootEl = ref<HTMLElement | null>(null)

// mês exibido: o selecionado, senão perto do teto (nascimento abre perto da
// faixa adulta em vez de sempre no mês corrente), senão hoje.
const viewDate = ref(selected.value || maxDate.value || today)
watch(() => props.modelValue, (v) => {
  const d = parseIso(v)
  if (d) viewDate.value = d
})

const displayLabel = computed(() => {
  const d = selected.value
  if (!d) return ''
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
})
const monthLabel = computed(() => `${MONTHS[viewDate.value.getMonth()]} de ${viewDate.value.getFullYear()}`)

const daysGrid = computed(() => {
  const y = viewDate.value.getFullYear()
  const m = viewDate.value.getMonth()
  const startOffset = new Date(y, m, 1).getDay()
  const daysInMonth = new Date(y, m + 1, 0).getDate()
  const daysInPrevMonth = new Date(y, m, 0).getDate()

  const cells: { date: Date; inMonth: boolean }[] = []
  for (let i = startOffset - 1; i >= 0; i--) cells.push({ date: new Date(y, m - 1, daysInPrevMonth - i), inMonth: false })
  for (let d = 1; d <= daysInMonth; d++) cells.push({ date: new Date(y, m, d), inMonth: true })
  while (cells.length < 42) {
    const last = cells[cells.length - 1]!.date
    cells.push({ date: new Date(last.getFullYear(), last.getMonth(), last.getDate() + 1), inMonth: false })
  }
  return cells
})

function isDisabled(d: Date) {
  if (maxDate.value && d > maxDate.value) return true
  if (minDate.value && d < minDate.value) return true
  return false
}

function pick(d: Date) {
  if (isDisabled(d)) return
  emit('update:modelValue', toIso(d))
  open.value = false
}
function prevMonth() { viewDate.value = new Date(viewDate.value.getFullYear(), viewDate.value.getMonth() - 1, 1) }
function nextMonth() { viewDate.value = new Date(viewDate.value.getFullYear(), viewDate.value.getMonth() + 1, 1) }

// grade de anos (12 por página) — navegação rápida essencial pra nascimento,
// ninguém deveria clicar "mês anterior" centenas de vezes até chegar em 1990.
const yearsPageStart = ref(Math.floor(viewDate.value.getFullYear() / 12) * 12)
const yearsGrid = computed(() => Array.from({ length: 12 }, (_, i) => yearsPageStart.value + i))
function openYears() {
  yearsPageStart.value = Math.floor(viewDate.value.getFullYear() / 12) * 12
  view.value = 'years'
}
function prevYearsPage() { yearsPageStart.value -= 12 }
function nextYearsPage() { yearsPageStart.value += 12 }
function pickYear(y: number) {
  viewDate.value = new Date(y, viewDate.value.getMonth(), 1)
  view.value = 'days'
}

function toggle() {
  open.value = !open.value
  if (open.value) view.value = 'days'
}
function clear() {
  emit('update:modelValue', '')
  open.value = false
}
function goToday() {
  if (isDisabled(today)) return
  pick(today)
}

// mousedown (não click): dispara ANTES do handler de clique interno rodar,
// então funciona mesmo quando esse clique troca o v-if/v-else da view (dias
// <-> anos) e substitui o nó clicado no DOM — com "click", o target já
// estaria desconectado por ali, e o clique interno fecharia o próprio
// dropdown por engano.
function onClickOutside(e: MouseEvent) {
  if (open.value && rootEl.value && !rootEl.value.contains(e.target as Node)) open.value = false
}
function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape' && open.value) open.value = false
}
onMounted(() => {
  document.addEventListener('mousedown', onClickOutside)
  window.addEventListener('keydown', onKeydown)
})
onUnmounted(() => {
  document.removeEventListener('mousedown', onClickOutside)
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <div ref="rootEl" class="group relative">
    <CalendarDays :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors" :class="open ? 'text-primary' : ''" />
    <button
      type="button"
      @click="toggle"
      class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 text-left text-body-sm outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
      :class="displayLabel ? 'text-ink' : 'text-ink-tertiary'"
    >
      {{ displayLabel || placeholder || 'Selecione uma data' }}
    </button>

    <Transition name="datepicker">
      <div
        v-if="open"
        class="absolute z-50 mt-2 w-[300px] max-w-[calc(100vw-2rem)] rounded-xl border border-hairline-strong bg-surface-2 p-3 shadow-card-premium"
      >
        <!-- Vista de dias -->
        <template v-if="view === 'days'">
          <div class="flex items-center justify-between px-1 pb-2">
            <button type="button" @click="prevMonth" aria-label="Mês anterior" class="grid size-8 place-items-center rounded-lg text-ink-subtle transition-colors hover:bg-surface-3 hover:text-ink">
              <ChevronLeft :size="16" />
            </button>
            <button type="button" @click="openYears" class="rounded-lg px-2 py-1 text-body-sm font-semibold text-ink transition-colors hover:text-primary">
              {{ monthLabel }}
            </button>
            <button type="button" @click="nextMonth" aria-label="Próximo mês" class="grid size-8 place-items-center rounded-lg text-ink-subtle transition-colors hover:bg-surface-3 hover:text-ink">
              <ChevronRight :size="16" />
            </button>
          </div>

          <div class="grid grid-cols-7 gap-1 px-1">
            <span v-for="wd in WEEKDAYS" :key="wd" class="grid h-7 place-items-center text-[11px] font-semibold text-ink-tertiary">{{ wd }}</span>
          </div>
          <div class="grid grid-cols-7 gap-1 px-1">
            <button
              v-for="cell in daysGrid"
              :key="cell.date.toISOString()"
              type="button"
              :disabled="isDisabled(cell.date)"
              @click="pick(cell.date)"
              class="aspect-square rounded-lg text-caption font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-30"
              :class="[
                !cell.inMonth ? 'text-ink-tertiary' : 'text-ink',
                isSameDay(cell.date, selected) ? 'bg-primary text-canvas hover:bg-primary-hover' : 'hover:bg-surface-3',
                !isSameDay(cell.date, selected) && isSameDay(cell.date, today) ? 'ring-1 ring-inset ring-hairline-strong' : '',
              ]"
            >
              {{ cell.date.getDate() }}
            </button>
          </div>
        </template>

        <!-- Vista de anos (navegação rápida) -->
        <template v-else>
          <div class="flex items-center justify-between px-1 pb-2">
            <button type="button" @click="prevYearsPage" aria-label="Anos anteriores" class="grid size-8 place-items-center rounded-lg text-ink-subtle transition-colors hover:bg-surface-3 hover:text-ink">
              <ChevronLeft :size="16" />
            </button>
            <span class="text-body-sm font-semibold text-ink">{{ yearsGrid[0] }}–{{ yearsGrid[11] }}</span>
            <button type="button" @click="nextYearsPage" aria-label="Próximos anos" class="grid size-8 place-items-center rounded-lg text-ink-subtle transition-colors hover:bg-surface-3 hover:text-ink">
              <ChevronRight :size="16" />
            </button>
          </div>
          <div class="grid grid-cols-3 gap-2 p-1">
            <button
              v-for="y in yearsGrid"
              :key="y"
              type="button"
              @click="pickYear(y)"
              class="rounded-lg py-2 text-body-sm font-semibold transition-colors"
              :class="selected && selected.getFullYear() === y ? 'bg-primary text-canvas hover:bg-primary-hover' : 'text-ink hover:bg-surface-3'"
            >
              {{ y }}
            </button>
          </div>
        </template>

        <div class="mt-2 flex items-center justify-between border-t border-hairline px-1 pt-2.5">
          <button type="button" @click="clear" class="text-caption font-semibold text-ink-subtle transition-colors hover:text-ink">Limpar</button>
          <button type="button" @click="goToday" class="text-caption font-semibold text-primary transition-colors hover:underline">Hoje</button>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.datepicker-enter-active,
.datepicker-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.datepicker-enter-from,
.datepicker-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
