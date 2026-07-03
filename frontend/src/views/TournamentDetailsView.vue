<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ArrowLeft, Lock, Medal, Gavel, Landmark, User, BadgeCheck, LogIn } from '@lucide/vue'

const route = useRoute()

// Mock data baseada na rota (ainda não existe backend de torneios — ver TODO.md)
const tournament = ref({
    id: route.params.id || '1',
    title: 'Copa de Final de Semana EA FC',
    host: 'ArenaX1 Oficial',
    game: 'EA FC 25',
    platform: 'PS5 / Xbox Series',
    entryFee: 10.00,
    prizePool: 80.00,
    currentPlayers: 4,
    maxPlayers: 8,
    format: 'Eliminação Direta',
    private: false,
})

onMounted(() => {
    if (route.params.id === '2') {
        tournament.value = {
            id: '2',
            title: 'Torneio Noturno eFootball',
            host: 'Liga BR',
            game: 'eFootball 2024',
            platform: 'PC / Consoles',
            entryFee: 5.00,
            prizePool: 80.00,
            currentPlayers: 12,
            maxPlayers: 16,
            format: 'Fase de Grupos + Mata-mata',
            private: false,
        }
    }
})
</script>

<template>
  <div class="px-6 lg:px-20 py-8 space-y-6">
    <router-link to="/torneios" class="inline-flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle no-underline transition-colors hover:text-primary">
        <ArrowLeft :size="14" />
        Voltar aos torneios
    </router-link>

    <!-- Cabeçalho do Torneio -->
    <div class="relative overflow-hidden rounded-2xl border border-primary/25 bg-gradient-to-br from-primary/[0.14] via-surface-2 to-surface-1 p-8 text-ink shadow-glow-primary">
        <div class="absolute -bottom-8 -right-8 size-48 rounded-full bg-primary/10 blur-3xl"></div>
        <div class="relative z-10">
            <div class="mb-4 flex items-start justify-between gap-4">
                <div>
                    <div class="mb-2 flex items-center gap-2">
                        <span v-if="tournament.private" class="inline-flex items-center gap-1 rounded-full border border-hairline bg-surface-3 px-2 py-0.5 text-[10px] font-bold uppercase text-ink-muted">
                            <Lock :size="12" /> Privado
                        </span>
                        <span class="rounded-full border border-primary/30 bg-primary/15 px-2 py-0.5 text-[10px] font-bold uppercase text-primary">
                            Inscrição aberta
                        </span>
                    </div>
                    <h1 class="font-display text-headline font-bold uppercase tracking-tight">{{ tournament.title }}</h1>
                    <p class="mt-1 text-body-sm text-ink-subtle">por {{ tournament.host }} · {{ tournament.game }} · {{ tournament.platform }}</p>
                </div>
                <div class="hidden flex-col items-center rounded-xl border border-hairline bg-surface-2 px-6 py-4 backdrop-blur md:flex">
                    <span class="font-display text-2xl font-black text-primary">R$ {{ tournament.prizePool.toFixed(2) }}</span>
                    <span class="mt-1 text-[10px] uppercase tracking-wider text-ink-subtle">Premiação</span>
                </div>
            </div>

            <div class="mt-8 flex flex-wrap gap-6">
                <div class="flex flex-col">
                    <span class="text-[10px] uppercase tracking-widest text-ink-tertiary">Taxa de inscrição</span>
                    <span class="text-lg font-bold text-ink">R$ {{ tournament.entryFee.toFixed(2) }}</span>
                </div>
                <div class="w-px self-stretch bg-hairline"></div>
                <div class="flex flex-col">
                    <span class="text-[10px] uppercase tracking-widest text-ink-tertiary">Jogadores</span>
                    <span class="text-lg font-bold text-ink">{{ tournament.currentPlayers }}/{{ tournament.maxPlayers }}</span>
                </div>
                <div class="w-px self-stretch bg-hairline"></div>
                <div class="flex flex-col">
                    <span class="text-[10px] uppercase tracking-widest text-ink-tertiary">Formato</span>
                    <span class="text-lg font-bold text-ink">{{ tournament.format }}</span>
                </div>
            </div>
        </div>
    </div>

    <!-- Layout Dividido -->
    <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- Coluna Esquerda -->
        <div class="space-y-6 lg:col-span-2">
            <!-- Prêmios -->
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <h3 class="mb-4 flex items-center gap-2 text-lg font-bold text-ink">
                    <Medal :size="22" class="text-primary" />
                    Prêmios
                </h3>
                <div class="grid grid-cols-3 gap-4">
                    <div class="rounded-xl border border-hairline bg-surface-2 p-4 text-center">
                        <span class="text-2xl drop-shadow-md">🥇</span>
                        <p class="mt-2 text-lg font-bold text-semantic-success">R$ {{ (tournament.prizePool * 0.5).toFixed(2) }}</p>
                        <p class="mt-1 text-caption font-bold uppercase tracking-widest text-ink-tertiary">1º Lugar</p>
                    </div>
                    <div class="rounded-xl border border-hairline bg-surface-2 p-4 text-center">
                        <span class="text-2xl drop-shadow-md">🥈</span>
                        <p class="mt-2 text-lg font-bold text-ink-muted">R$ {{ (tournament.prizePool * 0.3).toFixed(2) }}</p>
                        <p class="mt-1 text-caption font-bold uppercase tracking-widest text-ink-tertiary">2º Lugar</p>
                    </div>
                    <div class="rounded-xl border border-hairline bg-surface-2 p-4 text-center">
                        <span class="text-2xl drop-shadow-md">🥉</span>
                        <p class="mt-2 text-lg font-bold text-accent">R$ {{ (tournament.prizePool * 0.2).toFixed(2) }}</p>
                        <p class="mt-1 text-caption font-bold uppercase tracking-widest text-ink-tertiary">3º Lugar</p>
                    </div>
                </div>
            </div>

            <!-- Regras -->
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <h3 class="mb-4 flex items-center gap-2 text-lg font-bold text-ink">
                    <Gavel :size="22" class="text-primary" />
                    Regras
                </h3>
                <ul class="list-inside list-disc space-y-3 text-body-sm text-ink-subtle">
                    <li>Ambos os jogadores devem marcar-se como prontos antes do início da partida.</li>
                    <li>Ambos os jogadores devem declarar o resultado após a partida, obrigatoriamente anexando a foto do placar final.</li>
                    <li>Em caso de conflito, a moderação da ArenaX1 analisará as provas. Quem não enviar foto perde.</li>
                    <li>Um jogador ausente 15 minutos após o horário programado perde por desistência (W.O.).</li>
                    <li>Qualquer comportamento antidesportivo, ofensas ou catimba excessiva pode levar à desqualificação.</li>
                </ul>
            </div>
        </div>

        <!-- Coluna Direita -->
        <div class="space-y-6">
            <!-- Detalhes de Pagamento -->
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <h3 class="mb-4 flex items-center gap-2 text-body-sm font-bold text-ink">
                    <Landmark :size="16" class="text-primary" />
                    Detalhes Financeiros
                </h3>

                <div class="space-y-3">
                    <div class="flex items-center justify-between text-body-sm">
                        <span class="text-ink-subtle">Taxa de inscrição</span>
                        <span class="font-bold text-ink">R$ {{ tournament.entryFee.toFixed(2) }}</span>
                    </div>
                    <div class="flex items-center justify-between text-body-sm">
                        <span class="text-ink-subtle">Arrecadação total</span>
                        <span class="font-medium text-ink">{{ tournament.maxPlayers }} × R$ {{ tournament.entryFee.toFixed(2) }}</span>
                    </div>
                    <hr class="border-hairline">
                    <div class="flex items-center justify-between text-body-sm">
                        <span class="text-ink-subtle">Premiação em Jogo</span>
                        <span class="font-bold text-semantic-success">R$ {{ tournament.prizePool.toFixed(2) }}</span>
                    </div>
                </div>

                <div class="mt-4 rounded-lg border border-accent/20 bg-accent/10 p-3">
                    <div class="flex items-start gap-2">
                        <Lock :size="14" class="mt-0.5 text-accent" />
                        <div>
                            <p class="text-caption font-bold text-accent">Custódia ArenaX1</p>
                            <p class="mt-1 text-[11px] leading-relaxed text-ink-subtle">As taxas de inscrição são retidas com segurança pela ArenaX1 até o encerramento do torneio. O prêmio é distribuído automaticamente aos vencedores.</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Organizador -->
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <h3 class="mb-4 flex items-center gap-2 text-body-sm font-bold text-ink">
                    <User :size="16" class="text-primary" />
                    Organizador
                </h3>
                <div class="mb-4 flex items-center gap-3">
                    <div class="grid size-10 place-items-center rounded-full bg-surface-3 font-bold uppercase text-ink-tertiary">
                        {{ tournament.host.charAt(0) }}
                    </div>
                    <div>
                        <p class="text-body-sm font-bold text-ink">{{ tournament.host }}</p>
                        <p class="text-[10px] text-ink-tertiary">Organizador Oficial</p>
                    </div>
                </div>
                <div class="flex items-center gap-2 text-caption">
                    <BadgeCheck :size="14" class="text-semantic-success" />
                    <span class="font-medium text-semantic-success">Identidade verificada</span>
                </div>
            </div>

            <!-- Ação -->
            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-6 text-center backdrop-blur">
                <button class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 font-bold text-canvas shadow-glow-primary transition-all hover:bg-primary-hover">
                    <LogIn :size="20" />
                    Entrar no Torneio
                </button>
                <p class="mt-3 text-[10px] text-ink-tertiary">Você precisará fazer login para participar.</p>
            </div>
        </div>
    </div>
  </div>
</template>
