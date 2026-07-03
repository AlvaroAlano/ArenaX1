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
                <a class="text-sm text-ink-subtle hover:text-primary" href="#">Termos de Utilização</a>
                <a class="text-sm text-ink-subtle hover:text-primary" href="#">Política de Privacidade</a>
                <a class="text-sm text-ink-subtle hover:text-primary" href="#">Fale Conosco</a>
            </div>
        </div>
    </div>
    <div class="max-w-7xl mx-auto mt-12 pt-8 border-t border-hairline flex flex-col md:flex-row items-center justify-between gap-4">
        <p class="text-xs text-ink-tertiary order-last md:order-first">&copy; 2026 ArenaX1.</p>
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
</script>
