<script setup lang="ts">
import { ref, onMounted } from 'vue'

const isNavOpen = ref(false)
const scrolled = ref(false)

onMounted(() => {
  window.addEventListener('scroll', () => {
    scrolled.value = window.scrollY > 20
  })
})

const features = [
  {
    icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />`,
    title: 'Pix Instantâneo',
    description: 'Deposite e saque em segundos. Sem taxas de conversão, sem espera. Seu dinheiro na hora.'
  },
  {
    icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />`,
    title: 'Anti-Fraude Robusto',
    description: 'Sistema de duplo check de resultados com chat de mediação e análise de provas em tempo real.'
  },
  {
    icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />`,
    title: 'Desafie Seus Amigos',
    description: 'Gere links privados de desafio e compartilhe direto no WhatsApp, Discord ou Telegram.'
  },
  {
    icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`,
    title: 'Rake Justo',
    description: 'Zero taxa de depósito e saque. Cobramos apenas uma pequena taxa sobre o pote da partida.'
  },
  {
    icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />`,
    title: 'PC, Console & Mobile',
    description: 'Jogue no PS5, Xbox, PC ou Steam. Acesse a plataforma de qualquer dispositivo, em qualquer lugar.'
  },
  {
    icon: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />`,
    title: 'Torneios & Rankings',
    description: 'Participe de torneios com premiações reais e suba no ranking da comunidade brasileira.'
  }
]

const steps = [
  { number: '01', title: 'Crie sua Conta', description: 'Cadastre-se em segundos e vincule seu EA ID, PSN ou Xbox Live.' },
  { number: '02', title: 'Deposite via Pix', description: 'Gere um QR Code Pix e seu saldo atualiza instantaneamente.' },
  { number: '03', title: 'Desafie ou Aceite', description: 'Crie uma sala pública ou envie um link privado para seu amigo.' },
  { number: '04', title: 'Jogue & Ganhe', description: 'Vença a partida, confirme o resultado e receba o prêmio na hora.' }
]
</script>

<template>
  <div class="min-h-screen bg-canvas text-ink relative overflow-hidden">

    <!-- ═══════════════════════════════════════════ -->
    <!-- NAVEGAÇÃO FIXA                              -->
    <!-- ═══════════════════════════════════════════ -->
    <nav 
      :class="[
        'fixed top-0 left-0 right-0 z-50 transition-all duration-300',
        scrolled ? 'bg-canvas/90 backdrop-blur-xl border-b border-hairline' : 'bg-transparent'
      ]"
    >
      <div class="max-w-[1280px] mx-auto px-6 lg:px-12 h-14 flex items-center justify-between">
        <!-- Logo -->
        <div class="flex items-center gap-3">
          <svg class="w-7 h-7 text-primary" fill="currentColor" viewBox="0 0 24 24">
            <path d="M21.58 6.91a2 2 0 0 0-1.28-1.12c-2.31-.76-7.85-1.52-8.3-1.52s-5.99.76-8.3 1.52A2 2 0 0 0 2.42 6.91C1.04 10.97 1 15.68 1 15.68a2 2 0 0 0 1.28 1.55c1.33.44 4.09.87 6.44 1.15.54.06.94.57.87 1.11-.06.49-.48.86-.97.86h-1.18a.75.75 0 0 0 0 1.5h9.12a.75.75 0 0 0 0-1.5h-1.18c-.49 0-.91-.37-.97-.86-.07-.54.33-1.05.87-1.11 2.35-.28 5.11-.71 6.44-1.15a2 2 0 0 0 1.28-1.55s.04-4.71-1.34-8.77zM9.5 12a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z" />
          </svg>
          <span class="font-display font-semibold text-body-lg tracking-tight">Arena X1</span>
        </div>

        <!-- Links Desktop -->
        <div class="hidden md:flex items-center gap-8 text-body-sm text-ink-subtle">
          <a href="#como-funciona" class="hover:text-ink transition-colors">Como Funciona</a>
          <a href="#recursos" class="hover:text-ink transition-colors">Recursos</a>
          <a href="#faq" class="hover:text-ink transition-colors">FAQ</a>
        </div>

        <!-- CTAs Desktop -->
        <div class="hidden md:flex items-center gap-3">
          <router-link to="/login" class="bg-surface-1 hover:bg-surface-2 border border-hairline text-ink px-4 py-2 rounded-md text-button font-medium transition-colors">
            Entrar
          </router-link>
          <router-link to="/register" class="bg-primary hover:bg-primary-hover text-ink px-4 py-2 rounded-md text-button font-medium transition-colors">
            Criar Conta
          </router-link>
        </div>

        <!-- Hamburger Mobile -->
        <button @click="isNavOpen = !isNavOpen" class="md:hidden text-ink p-2 -mr-2">
          <svg v-if="!isNavOpen" class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
          <svg v-else class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
        </button>
      </div>

      <!-- Menu Mobile -->
      <transition
        enter-active-class="transition duration-200 ease-out"
        enter-from-class="opacity-0 -translate-y-2"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition duration-150 ease-in"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 -translate-y-2"
      >
        <div v-if="isNavOpen" class="md:hidden bg-surface-1 border-b border-hairline px-6 py-6 space-y-4">
          <a href="#como-funciona" @click="isNavOpen = false" class="block text-body-sm text-ink-subtle hover:text-ink transition-colors">Como Funciona</a>
          <a href="#recursos" @click="isNavOpen = false" class="block text-body-sm text-ink-subtle hover:text-ink transition-colors">Recursos</a>
          <a href="#faq" @click="isNavOpen = false" class="block text-body-sm text-ink-subtle hover:text-ink transition-colors">FAQ</a>
          <div class="pt-4 border-t border-hairline flex flex-col gap-3">
            <router-link to="/login" class="bg-surface-2 border border-hairline text-ink text-center px-4 py-3 rounded-md text-button font-medium">Entrar</router-link>
            <router-link to="/register" class="bg-primary text-ink text-center px-4 py-3 rounded-md text-button font-medium">Criar Conta</router-link>
          </div>
        </div>
      </transition>
    </nav>

    <!-- ═══════════════════════════════════════════ -->
    <!-- HERO                                        -->
    <!-- ═══════════════════════════════════════════ -->
    <section class="relative pt-32 pb-20 lg:pt-44 lg:pb-32 px-6 lg:px-12">
      <!-- Efeito de gradiente de fundo sutil -->
      <div class="absolute inset-0 pointer-events-none overflow-hidden">
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-primary/[0.04] rounded-full blur-[120px]"></div>
      </div>

      <div class="max-w-[1280px] mx-auto relative z-10">
        <div class="max-w-3xl mx-auto text-center">
          <!-- Eyebrow -->
          <div class="inline-flex items-center gap-2 bg-surface-1 border border-hairline rounded-pill px-4 py-1.5 mb-8">
            <span class="w-2 h-2 rounded-full bg-semantic-success animate-pulse"></span>
            <span class="text-caption text-ink-subtle font-medium">Plataforma aberta — Cadastre-se agora</span>
          </div>

          <!-- Título Principal -->
          <h1 class="text-display-lg md:text-display-xl font-display font-semibold tracking-tight leading-tight mb-6">
            O X1 de Futebol<br class="hidden sm:block" /> Virtual com <span class="text-primary">Dinheiro Real</span>
          </h1>

          <!-- Subtítulo -->
          <p class="text-body-lg md:text-subhead text-ink-subtle max-w-xl mx-auto mb-10 leading-relaxed">
            Desafie jogadores, aposte no seu talento e saque seus ganhos instantaneamente via Pix. EA FC e eFootball. PS5, Xbox e PC.
          </p>

          <!-- CTAs do Hero -->
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
            <router-link to="/register" class="w-full sm:w-auto bg-primary hover:bg-primary-hover text-ink px-8 py-4 rounded-md text-button font-medium transition-all text-center">
              Começar Agora — É Grátis
            </router-link>
            <a href="#como-funciona" class="w-full sm:w-auto bg-surface-1 hover:bg-surface-2 border border-hairline text-ink px-8 py-4 rounded-md text-button font-medium transition-colors text-center">
              Como Funciona
            </a>
          </div>

          <!-- Social proof micro -->
          <div class="mt-12 flex items-center justify-center gap-6 text-caption text-ink-tertiary">
            <div class="flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" /></svg>
              <span>Saldo Protegido</span>
            </div>
            <div class="w-px h-3 bg-hairline"></div>
            <div class="flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>
              <span>Pix Instantâneo</span>
            </div>
            <div class="w-px h-3 bg-hairline hidden sm:block"></div>
            <div class="hidden sm:flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
              <span>Anti-Fraude</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════════ -->
    <!-- COMO FUNCIONA                               -->
    <!-- ═══════════════════════════════════════════ -->
    <section id="como-funciona" class="py-20 lg:py-28 px-6 lg:px-12">
      <div class="max-w-[1280px] mx-auto">
        <!-- Header da Seção -->
        <div class="text-center mb-16">
          <span class="text-eyebrow text-primary uppercase tracking-widest mb-3 block">Como Funciona</span>
          <h2 class="text-display-md font-display font-semibold tracking-tight mb-4">Do cadastro ao saque em 4 passos</h2>
          <p class="text-body-lg text-ink-subtle max-w-lg mx-auto">Simples, rápido e seguro. Crie sua conta e comece a jogar em minutos.</p>
        </div>

        <!-- Steps Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <div 
            v-for="(step, index) in steps" 
            :key="index"
            class="bg-surface-1 border border-hairline rounded-lg p-6 relative group hover:border-primary/30 transition-all duration-300"
          >
            <span class="text-display-lg font-display font-semibold text-surface-3 group-hover:text-primary/20 transition-colors absolute top-4 right-6">
              {{ step.number }}
            </span>
            <div class="relative z-10">
              <h3 class="text-card-title font-display font-medium mb-2 mt-8">{{ step.title }}</h3>
              <p class="text-body-sm text-ink-subtle leading-relaxed">{{ step.description }}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════════ -->
    <!-- RECURSOS / FEATURES                         -->
    <!-- ═══════════════════════════════════════════ -->
    <section id="recursos" class="py-20 lg:py-28 px-6 lg:px-12">
      <div class="max-w-[1280px] mx-auto">
        <!-- Header da Seção -->
        <div class="text-center mb-16">
          <span class="text-eyebrow text-primary uppercase tracking-widest mb-3 block">Recursos</span>
          <h2 class="text-display-md font-display font-semibold tracking-tight mb-4">Tudo que você precisa para competir</h2>
          <p class="text-body-lg text-ink-subtle max-w-lg mx-auto">Construímos cada detalhe pensando na experiência do jogador brasileiro.</p>
        </div>

        <!-- Features Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <div 
            v-for="(feature, index) in features" 
            :key="index"
            class="bg-surface-1 border border-hairline rounded-lg p-6 group hover:border-primary/30 transition-all duration-300"
          >
            <div class="w-10 h-10 rounded-md bg-surface-2 border border-hairline flex items-center justify-center mb-5 group-hover:border-primary/40 transition-colors">
              <svg class="w-5 h-5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" v-html="feature.icon"></svg>
            </div>
            <h3 class="text-card-title font-display font-medium mb-2">{{ feature.title }}</h3>
            <p class="text-body-sm text-ink-subtle leading-relaxed">{{ feature.description }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════════ -->
    <!-- CTA BANNER                                  -->
    <!-- ═══════════════════════════════════════════ -->
    <section class="py-20 lg:py-28 px-6 lg:px-12">
      <div class="max-w-[1280px] mx-auto">
        <div class="bg-surface-1 border border-hairline rounded-lg p-10 md:p-16 text-center relative overflow-hidden">
          <!-- Efeito decorativo de fundo -->
          <div class="absolute inset-0 pointer-events-none">
            <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[300px] bg-primary/[0.03] rounded-full blur-[80px]"></div>
          </div>

          <div class="relative z-10">
            <h2 class="text-display-md md:text-display-lg font-display font-semibold tracking-tight mb-4">
              Pronto para entrar na Arena?
            </h2>
            <p class="text-body-lg text-ink-subtle max-w-md mx-auto mb-8">
              Crie sua conta em segundos, deposite via Pix e comece a competir agora mesmo.
            </p>
            <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
              <router-link to="/register" class="w-full sm:w-auto bg-primary hover:bg-primary-hover text-ink px-8 py-4 rounded-md text-button font-medium transition-all text-center">
                Criar Conta Grátis
              </router-link>
              <router-link to="/login" class="w-full sm:w-auto bg-surface-2 hover:bg-surface-3 border border-hairline text-ink px-8 py-4 rounded-md text-button font-medium transition-colors text-center">
                Já tenho conta
              </router-link>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════════ -->
    <!-- FAQ                                         -->
    <!-- ═══════════════════════════════════════════ -->
    <section id="faq" class="py-20 lg:py-28 px-6 lg:px-12">
      <div class="max-w-[800px] mx-auto">
        <div class="text-center mb-16">
          <span class="text-eyebrow text-primary uppercase tracking-widest mb-3 block">FAQ</span>
          <h2 class="text-display-md font-display font-semibold tracking-tight">Perguntas Frequentes</h2>
        </div>

        <div class="space-y-4">
          <details class="group bg-surface-1 border border-hairline rounded-lg">
            <summary class="cursor-pointer px-6 py-5 flex items-center justify-between text-body font-medium text-ink list-none">
              Como funciona o depósito e saque?
              <svg class="w-5 h-5 text-ink-subtle group-open:rotate-180 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
            </summary>
            <div class="px-6 pb-5 text-body-sm text-ink-subtle leading-relaxed">
              Tudo é feito via Pix. Para depositar, você gera um QR Code na plataforma e paga pelo app do seu banco. O saldo atualiza em segundos. Para sacar, informe sua chave Pix e o dinheiro cai na hora. Sem taxas de depósito ou saque.
            </div>
          </details>

          <details class="group bg-surface-1 border border-hairline rounded-lg">
            <summary class="cursor-pointer px-6 py-5 flex items-center justify-between text-body font-medium text-ink list-none">
              Quais jogos são suportados?
              <svg class="w-5 h-5 text-ink-subtle group-open:rotate-180 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
            </summary>
            <div class="px-6 pb-5 text-body-sm text-ink-subtle leading-relaxed">
              Atualmente suportamos EA FC (FIFA) e eFootball (PES) em todas as plataformas: PlayStation 5, Xbox Series X|S, PC (Steam e EA App).
            </div>
          </details>

          <details class="group bg-surface-1 border border-hairline rounded-lg">
            <summary class="cursor-pointer px-6 py-5 flex items-center justify-between text-body font-medium text-ink list-none">
              O que acontece se houver uma disputa no resultado?
              <svg class="w-5 h-5 text-ink-subtle group-open:rotate-180 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
            </summary>
            <div class="px-6 pb-5 text-body-sm text-ink-subtle leading-relaxed">
              Se os resultados reportados divergirem, o pote fica retido e um chat de mediação é aberto. Os jogadores podem enviar fotos ou vídeos comprovando o placar real. A equipe de suporte analisa as provas e libera o prêmio para o vencedor legítimo. Fraudadores são banidos e perdem o saldo.
            </div>
          </details>

          <details class="group bg-surface-1 border border-hairline rounded-lg">
            <summary class="cursor-pointer px-6 py-5 flex items-center justify-between text-body font-medium text-ink list-none">
              Quanto custa usar a plataforma?
              <svg class="w-5 h-5 text-ink-subtle group-open:rotate-180 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
            </summary>
            <div class="px-6 pb-5 text-body-sm text-ink-subtle leading-relaxed">
              Não há taxa para depósito nem para saque. Cobramos apenas uma pequena taxa (rake) sobre o pote total de cada partida ou torneio. Transparente e justo.
            </div>
          </details>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════════ -->
    <!-- FOOTER                                      -->
    <!-- ═══════════════════════════════════════════ -->
    <footer class="border-t border-hairline py-12 px-6 lg:px-12">
      <div class="max-w-[1280px] mx-auto">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-10 mb-12">
          <!-- Brand Column -->
          <div class="md:col-span-2">
            <div class="flex items-center gap-3 mb-4">
              <svg class="w-7 h-7 text-primary" fill="currentColor" viewBox="0 0 24 24">
                <path d="M21.58 6.91a2 2 0 0 0-1.28-1.12c-2.31-.76-7.85-1.52-8.3-1.52s-5.99.76-8.3 1.52A2 2 0 0 0 2.42 6.91C1.04 10.97 1 15.68 1 15.68a2 2 0 0 0 1.28 1.55c1.33.44 4.09.87 6.44 1.15.54.06.94.57.87 1.11-.06.49-.48.86-.97.86h-1.18a.75.75 0 0 0 0 1.5h9.12a.75.75 0 0 0 0-1.5h-1.18c-.49 0-.91-.37-.97-.86-.07-.54.33-1.05.87-1.11 2.35-.28 5.11-.71 6.44-1.15a2 2 0 0 0 1.28-1.55s.04-4.71-1.34-8.77zM9.5 12a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z" />
              </svg>
              <span class="font-display font-semibold text-body-lg tracking-tight">Arena X1</span>
            </div>
            <p class="text-caption text-ink-subtle max-w-xs leading-relaxed">
              A plataforma definitiva de X1 de futebol virtual com dinheiro real para o público brasileiro.
            </p>
          </div>

          <!-- Links Column -->
          <div>
            <h4 class="text-eyebrow text-ink-muted uppercase tracking-wider mb-4">Plataforma</h4>
            <ul class="space-y-3 text-body-sm text-ink-subtle">
              <li><a href="#como-funciona" class="hover:text-ink transition-colors">Como Funciona</a></li>
              <li><a href="#recursos" class="hover:text-ink transition-colors">Recursos</a></li>
              <li><a href="#faq" class="hover:text-ink transition-colors">FAQ</a></li>
            </ul>
          </div>

          <!-- Legal Column -->
          <div>
            <h4 class="text-eyebrow text-ink-muted uppercase tracking-wider mb-4">Legal</h4>
            <ul class="space-y-3 text-body-sm text-ink-subtle">
              <li><a href="#" class="hover:text-ink transition-colors">Termos de Uso</a></li>
              <li><a href="#" class="hover:text-ink transition-colors">Política de Privacidade</a></li>
              <li><a href="#" class="hover:text-ink transition-colors">Suporte</a></li>
            </ul>
          </div>
        </div>

        <!-- Copyright -->
        <div class="border-t border-hairline pt-8 flex flex-col md:flex-row items-center justify-between gap-4">
          <p class="text-caption text-ink-tertiary">© 2026 Arena X1. Todos os direitos reservados.</p>
          <div class="flex items-center gap-4 text-ink-tertiary">
            <a href="#" class="hover:text-ink transition-colors">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M24 4.557c-.883.392-1.832.656-2.828.775 1.017-.609 1.798-1.574 2.165-2.724-.951.564-2.005.974-3.127 1.195-.897-.957-2.178-1.555-3.594-1.555-3.179 0-5.515 2.966-4.797 6.045-4.091-.205-7.719-2.165-10.148-5.144-1.29 2.213-.669 5.108 1.523 6.574-.806-.026-1.566-.247-2.229-.616-.054 2.281 1.581 4.415 3.949 4.89-.693.188-1.452.232-2.224.084.626 1.956 2.444 3.379 4.6 3.419-2.07 1.623-4.678 2.348-7.29 2.04 2.179 1.397 4.768 2.212 7.548 2.212 9.142 0 14.307-7.721 13.995-14.646.962-.695 1.797-1.562 2.457-2.549z"/></svg>
            </a>
            <a href="#" class="hover:text-ink transition-colors">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
            </a>
            <a href="#" class="hover:text-ink transition-colors">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M20.317 4.37a19.791 19.791 0 00-4.885-1.515.074.074 0 00-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 00-5.487 0 12.64 12.64 0 00-.617-1.25.077.077 0 00-.079-.037A19.736 19.736 0 003.677 4.37a.07.07 0 00-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 00.031.057 19.9 19.9 0 005.993 3.03.078.078 0 00.084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 00-.041-.106 13.107 13.107 0 01-1.872-.892.077.077 0 01-.008-.128 10.2 10.2 0 00.372-.292.074.074 0 01.077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 01.078.01c.12.098.246.198.373.292a.077.077 0 01-.006.127 12.299 12.299 0 01-1.873.892.077.077 0 00-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 00.084.028 19.839 19.839 0 006.002-3.03.077.077 0 00.032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 00-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z"/></svg>
            </a>
          </div>
        </div>
      </div>
    </footer>

  </div>
</template>

<style scoped>
.bg-canvas {
  background-image: radial-gradient(circle at center, #1b202c 0%, #0d0e12 100%);
}

details summary::-webkit-details-marker {
  display: none;
}
</style>
