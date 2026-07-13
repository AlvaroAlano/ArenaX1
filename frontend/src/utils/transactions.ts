// Rótulos amigáveis para os tipos de transação do backend.
//
// Fonte da verdade dos tipos: coluna `type` da tabela `transactions`
// (ver backend/schema.sql e as funções em 04/07/08/18/24/26/27). O objetivo
// aqui é traduzir o código técnico (ex.: `bet_refund`) num texto que o
// usuário entenda de imediato no extrato/histórico. A `description` da própria
// transação, quando existe, complementa com os detalhes (ex.: qual desafio).

export interface TxMeta {
  /** Texto exibido como rótulo da transação. */
  label: string
  /** Se o valor entra (crédito) na carteira. Usado para sinal e cor. */
  positive: boolean
}

const TX_META: Record<string, TxMeta> = {
  // Movimentações de carteira
  deposit: { label: 'Depósito', positive: true },
  withdraw: { label: 'Saque', positive: false },

  // Aposta reservada / devolvida (cobre tanto desafio 1v1 quanto inscrição
  // em torneio online — os dois congelam saldo via `bet_freeze`).
  bet_freeze: { label: 'Valor reservado', positive: false },
  bet_refund: { label: 'Reembolso', positive: true },

  // Resultados de desafio
  challenge_win: { label: 'Vitória no desafio', positive: true },
  challenge_loss: { label: 'Derrota no desafio', positive: false },

  // Torneios
  tournament_prize: { label: 'Prêmio de torneio', positive: true },

  // Prêmio genérico (nome legado) e comissão da plataforma
  win_prize: { label: 'Prêmio recebido', positive: true },
  rake: { label: 'Taxa da plataforma', positive: false },
}

/** Rótulo + sinal para um tipo de transação; fallback seguro se desconhecido. */
export function txMeta(type: string): TxMeta {
  return TX_META[type] || { label: 'Movimentação', positive: false }
}
