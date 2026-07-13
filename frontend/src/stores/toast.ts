import { defineStore } from 'pinia'
import { ref } from 'vue'

export type ToastType = 'success' | 'error' | 'info'
export interface Toast {
  id: number
  message: string
  type: ToastType
}

// Toast global simples — a app não tinha nada (usava alert()); isto é o
// mínimo reutilizável pra feedback não-bloqueante. Renderizado pelo
// ToastHost montado no App.vue.
export const useToastStore = defineStore('toast', () => {
  const toasts = ref<Toast[]>([])
  let seq = 0

  function push(message: string, type: ToastType = 'info', duration = 4000) {
    const id = ++seq
    toasts.value.push({ id, message, type })
    setTimeout(() => dismiss(id), duration)
  }

  function dismiss(id: number) {
    toasts.value = toasts.value.filter((t) => t.id !== id)
  }

  return { toasts, push, dismiss }
})
