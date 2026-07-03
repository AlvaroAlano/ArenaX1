import { reactive } from 'vue'

export type ToastType = 'success' | 'error' | 'info'

interface Toast {
  id: number
  type: ToastType
  message: string
}

const toasts = reactive<Toast[]>([])
let nextId = 0

function push(type: ToastType, message: string, duration = 5000) {
  const id = nextId++
  toasts.push({ id, type, message })
  setTimeout(() => remove(id), duration)
}

function remove(id: number) {
  const index = toasts.findIndex((t) => t.id === id)
  if (index !== -1) toasts.splice(index, 1)
}

export function useToast() {
  return {
    toasts,
    success: (message: string) => push('success', message),
    error: (message: string) => push('error', message),
    info: (message: string) => push('info', message),
    remove,
  }
}
