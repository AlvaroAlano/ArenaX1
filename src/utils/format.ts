const currencyFormatter = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
})

const dateTimeFormatter = new Intl.DateTimeFormat('pt-BR', {
  dateStyle: 'short',
  timeStyle: 'short',
})

export function formatCurrency(value: number | string | null | undefined): string {
  const amount = typeof value === 'string' ? parseFloat(value) : value
  return currencyFormatter.format(amount || 0)
}

export function formatDateTime(value: string | Date): string {
  return dateTimeFormatter.format(new Date(value))
}
