import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface ConfirmOptions {
  title?: string
  message: string
  confirmText?: string
  cancelText?: string
  tone?: 'default' | 'danger'
}

type ResolvedOptions = Required<ConfirmOptions>

// Confirmação global baseada em promise — substitui o confirm() nativo do
// navegador (que trava a thread e ignora a estética do app). Mesmo padrão do
// toast store: um estado único, renderizado pelo ConfirmDialog montado no App.
// Uso: `if (!(await confirm.ask({ message: '...' }))) return`.
export const useConfirmStore = defineStore('confirm', () => {
  const open = ref(false)
  const options = ref<ResolvedOptions>({
    title: 'Confirmar',
    message: '',
    confirmText: 'Confirmar',
    cancelText: 'Cancelar',
    tone: 'default',
  })
  let resolver: ((value: boolean) => void) | null = null

  function ask(opts: ConfirmOptions): Promise<boolean> {
    // Se já havia um diálogo aberto (raro), resolve o anterior como cancelado
    // pra nunca deixar uma promise pendurada.
    if (resolver) resolver(false)

    options.value = {
      title: opts.title ?? 'Confirmar',
      message: opts.message,
      confirmText: opts.confirmText ?? 'Confirmar',
      cancelText: opts.cancelText ?? 'Cancelar',
      tone: opts.tone ?? 'default',
    }
    open.value = true

    return new Promise<boolean>((resolve) => {
      resolver = resolve
    })
  }

  function respond(result: boolean) {
    open.value = false
    if (resolver) {
      resolver(result)
      resolver = null
    }
  }

  return { open, options, ask, respond }
})
