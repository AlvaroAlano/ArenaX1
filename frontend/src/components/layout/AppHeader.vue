<template>
  <header class="fixed top-0 left-0 right-0 z-50 bg-canvas/80 backdrop-blur-lg border-b border-hairline" style="padding-top: env(safe-area-inset-top)">
    <div class="flex items-center justify-between px-6 h-16 md:h-[76px] lg:px-20">
        <router-link to="/" class="flex items-center gap-2.5 no-underline">
            <span class="grid size-8 place-items-center rounded-md bg-primary text-[15px] font-black tracking-tighter text-canvas">X1</span>
            <span class="font-display text-lg font-black tracking-tight text-ink">ARENA<span class="text-primary">X1</span></span>
        </router-link>
        <div class="hidden md:flex items-center gap-7 lg:gap-8">
            <router-link active-class="text-primary" class="text-base font-extrabold text-ink hover:text-primary transition-colors lg:text-lg" to="/desafios">Desafios</router-link>
            <router-link :class="['text-base font-extrabold transition-colors lg:text-lg', $route.path.startsWith('/torneios') ? 'text-primary' : 'text-ink hover:text-primary']" to="/torneios">Torneios</router-link>
            <router-link active-class="text-primary" class="text-base font-extrabold text-ink hover:text-primary transition-colors lg:text-lg" to="/classificacao">Classificação</router-link>
            <router-link active-class="text-primary" class="text-base font-extrabold text-ink hover:text-primary transition-colors lg:text-lg" to="/como-funciona">Como Funciona</router-link>
        </div>
        <div class="flex gap-3 items-center">
            <button @click="mobileMenuOpen = !mobileMenuOpen" class="md:hidden text-ink-subtle hover:text-ink transition-colors">
                <Menu :size="24" />
            </button>
            <router-link to="/login" class="hidden md:inline-block px-4 py-2.5 text-base font-bold text-ink hover:bg-surface-2 rounded-lg transition-colors no-underline lg:px-5 lg:text-lg">Entrar</router-link>
            <router-link to="/register" class="hidden md:inline-block bg-primary text-canvas px-5 py-2.5 text-base font-extrabold rounded-lg hover:bg-primary-hover transition-all no-underline lg:px-7 lg:text-lg">Cadastrar</router-link>
        </div>
    </div>

    <!-- Mobile Menu -->
    <div v-show="mobileMenuOpen" class="md:hidden border-t border-hairline bg-canvas">
        <nav class="flex flex-col px-6 py-4 space-y-1">
            <router-link @click="mobileMenuOpen = false" active-class="text-primary bg-surface-2" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-ink hover:bg-surface-2 transition-colors no-underline" to="/desafios">
                <Swords :size="20" class="text-primary" /> Desafios
            </router-link>
            <router-link @click="mobileMenuOpen = false" :class="['flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-ink hover:bg-surface-2 transition-colors no-underline', $route.path.startsWith('/torneios') ? 'text-primary bg-surface-2' : '']" to="/torneios">
                <Award :size="20" :class="$route.path.startsWith('/torneios') ? 'text-primary' : ''" /> Torneios
            </router-link>
            <router-link @click="mobileMenuOpen = false" active-class="text-primary bg-surface-2" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-ink hover:bg-surface-2 transition-colors no-underline" to="/classificacao">
                <Trophy :size="20" class="text-primary" /> Classificação
            </router-link>
            <router-link @click="mobileMenuOpen = false" active-class="text-primary bg-surface-2" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-ink hover:bg-surface-2 transition-colors no-underline" to="/como-funciona">
                <HelpCircle :size="20" class="text-primary" /> Como Funciona
            </router-link>
            <InstallPwaButton variant="ghost" class="!justify-center" />
            <hr class="border-hairline my-2">
            <router-link @click="mobileMenuOpen = false" class="flex items-center justify-center rounded-lg px-3 py-2.5 text-sm font-bold text-ink hover:bg-surface-2 transition-colors no-underline" to="/login">Entrar</router-link>
            <router-link @click="mobileMenuOpen = false" class="flex items-center justify-center rounded-lg px-3 py-2.5 text-sm font-extrabold bg-primary text-canvas hover:bg-primary-hover transition-all no-underline" to="/register">Cadastrar</router-link>
        </nav>
    </div>
  </header>
</template>
<script setup lang="ts">
import { ref } from 'vue'
import { Menu, Swords, Award, Trophy, HelpCircle } from '@lucide/vue'
import InstallPwaButton from '@/components/ui/InstallPwaButton.vue'
const mobileMenuOpen = ref(false)
</script>
