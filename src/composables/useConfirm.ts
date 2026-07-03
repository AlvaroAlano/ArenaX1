import { reactive } from 'vue'

interface ConfirmOptions {
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
}

interface ConfirmState extends Required<ConfirmOptions> {
  open: boolean
  resolve: ((value: boolean) => void) | null
}

const state = reactive<ConfirmState>({
  open: false,
  title: '',
  message: '',
  confirmLabel: 'Confirmar',
  cancelLabel: 'Cancelar',
  danger: false,
  resolve: null,
})

function confirmAction(options: ConfirmOptions): Promise<boolean> {
  state.open = true
  state.title = options.title
  state.message = options.message
  state.confirmLabel = options.confirmLabel || 'Confirmar'
  state.cancelLabel = options.cancelLabel || 'Cancelar'
  state.danger = options.danger || false

  return new Promise((resolve) => {
    state.resolve = resolve
  })
}

function settle(value: boolean) {
  state.open = false
  state.resolve?.(value)
  state.resolve = null
}

export function useConfirm() {
  return {
    state,
    confirmAction,
    handleConfirm: () => settle(true),
    handleCancel: () => settle(false),
  }
}
