<template>
  <footer class="border-t border-hairline px-6 py-12 lg:px-20 bg-surface-1/40 mt-auto">
    <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between gap-12">
        <div class="flex flex-col gap-4">
            <router-link to="/" class="flex items-center gap-2.5 no-underline">
                <span class="grid size-7 place-items-center rounded-md bg-primary text-xs font-black text-canvas">X1</span>
                <span class="font-display text-base font-black tracking-tight text-ink">ARENA<span class="text-primary">X1</span></span>
            </router-link>
            <p class="text-sm text-ink-subtle max-w-xs">A arena competitiva de EA FC e eFootball do Brasil. X1, torneios e mata-mata entre amigos. Você fala, prova valendo grana.</p>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-12">
            <div class="flex flex-col gap-4">
                <h4 class="text-xs font-bold uppercase tracking-widest text-ink-tertiary">Plataforma</h4>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/desafios">Desafios</router-link>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/torneios">Torneios</router-link>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/classificacao">Classificação</router-link>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/como-funciona">Como Funciona</router-link>
            </div>
            <div class="flex flex-col gap-4">
                <h4 class="text-xs font-bold uppercase tracking-widest text-ink-tertiary">Suporte</h4>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/termos">Termos de Utilização</router-link>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/privacidade">Política de Privacidade</router-link>
                <router-link class="text-sm text-ink-subtle hover:text-primary" to="/support">Fale Conosco</router-link>
            </div>
        </div>
    </div>
    <!-- Aviso legal — conteúdo institucional discreto (skill-based + marcas de terceiros) -->
    <div class="max-w-7xl mx-auto mt-12 pt-8 border-t border-hairline">
        <h4 class="mb-3 text-[11px] font-bold uppercase tracking-widest text-ink-tertiary">Aviso legal</h4>
        <div class="max-w-4xl space-y-2.5">
            <p class="text-caption leading-relaxed text-ink-tertiary">
              A ArenaX1 é uma plataforma de competição baseada 100% em habilidade. Não operamos cassino, não sorteamos prêmios e não intermediamos apostas sobre eventos esportivos de terceiros — o resultado financeiro de cada desafio decorre exclusivamente do desempenho do próprio jogador na partida que ele disputou.
            </p>
            <p class="text-caption leading-relaxed text-ink-tertiary">
              A ArenaX1 não é endossada, patrocinada ou afiliada à Electronic Arts (EA Sports FC), Konami (eFootball), Sony (PlayStation), Microsoft (Xbox) ou Valve (Steam). Todas as marcas citadas pertencem aos seus respectivos titulares e não existe vínculo comercial entre essas empresas e a operação da Plataforma.
            </p>
        </div>
    </div>
    <div class="max-w-7xl mx-auto mt-8 pt-6 border-t border-hairline flex flex-col md:flex-row items-center justify-between gap-4">
        <p class="text-xs text-ink-tertiary order-last md:order-first">&copy; 2026 ArenaX1.</p>
        <ResponsibleGamingNote />
        <div class="flex items-center gap-3">
            <div class="flex items-center gap-1.5 bg-surface-2 border border-hairline rounded px-2.5 py-1">
                <Lock :size="14" class="text-semantic-success" />
                <span class="text-xs font-bold text-ink-subtle">Pagamento seguro</span>
            </div>
        </div>
    </div>
  </footer>
</template>
<script setup lang="ts">
import { Lock } from '@lucide/vue'
import ResponsibleGamingNote from '@/components/ui/ResponsibleGamingNote.vue'
</script>
