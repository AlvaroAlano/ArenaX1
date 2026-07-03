export const GAME_OPTIONS = ['EA FC 25', 'EA FC 26', 'eFootball'] as const

export type Game = typeof GAME_OPTIONS[number]
