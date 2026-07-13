<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { Wallet } from '@lucide/vue'
import DashboardSidebar from '@/components/layout/DashboardSidebar.vue'
import DashboardBottomNav from '@/components/layout/DashboardBottomNav.vue'
import NotificationBell from '@/components/ui/NotificationBell.vue'
import { useWalletStore } from '@/stores/wallet'

const walletStore = useWalletStore()
const route = useRoute()
onMounted(() => { walletStore.fetchWallet() })

// Logo = "subir um nível": no dashboard (home do painel) leva pra landing
// pública; em qualquer outra tela do painel, volta pro dashboard.
const logoTo = computed(() => route.path === '/dashboard' ? '/' : '/dashboard')

const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
</script>

<template>
  <div class="flex min-h-screen text-ink font-display overflow-x-hidden">

    <!-- Mobile Header (sem hambúrguer — navegação mobile é via bottom nav + tela /menu) -->
    <!-- padding-top do safe-area: no iPhone (notch/Dynamic Island) o header
         fixo ficava por baixo do relógio/bateria; o env() empurra o conteúdo
         pra baixo e o fundo preenche a faixa do topo. -->
    <div class="md:hidden fixed top-0 left-0 right-0 z-50 bg-surface-1/90 backdrop-blur border-b border-hairline" style="padding-top: env(safe-area-inset-top)">
      <div class="flex items-center justify-between px-4 h-14">
          <router-link :to="logoTo" class="flex items-center gap-2 no-underline">
            <span class="grid size-7 place-items-center rounded-md bg-primary text-xs font-black tracking-tighter text-canvas">X1</span>
            <span class="font-display text-lg font-black tracking-tight text-ink">ARENA<span class="text-primary">X1</span></span>
          </router-link>
          <div class="flex items-center gap-2.5">
            <router-link
              to="/wallet"
              class="flex items-center gap-1.5 rounded-xl border border-semantic-success/20 bg-semantic-success/10 px-3 py-2 text-sm font-bold tabular-nums text-semantic-success no-underline transition-colors active:bg-semantic-success/20"
            >
              <Wallet :size="15" />
              {{ walletStore.loaded ? fmtBRL(walletStore.balance) : '···' }}
            </router-link>
            <NotificationBell />
          </div>
      </div>
    </div>

    <!-- Sidebar Component (Desktop only agora — mobile usa a tela /menu) -->
    <DashboardSidebar :isOpen="false" />

    <!-- Spacer lateral para Desktop -->
    <div class="hidden md:block w-64 shrink-0"></div>

    <!-- Área de Conteúdo. custom-scrollbar aqui usa só a regra global de
         main.css (barra 100% escondida) — um scoped override mostrando uma
         barra fina fazia o Chrome/Android reservar aquele espaço físico em
         vez de sobrepor o conteúdo, empurrando tudo pra esquerda em
         qualquer tela alta o bastante pra rolar (mais visível no Menu). -->
    <!-- 80px = ~62px da barra fixa inferior (py-1.5 + botão de 50px, colada na
         base) + ~18px de respiro visual. A barra ainda adiciona o
         env(safe-area-inset-bottom) por dentro dela, e o env() abaixo cobre
         essa faixa; assim o último item nunca fica atrás da barra. -->
    <!-- h-dvh (não h-screen): 100vh mede contra o viewport com a barra de
         endereço recolhida, mas no load ela ainda está visível — como quem
         rola é esse <main> (não a página), o browser nunca ganha o gesto de
         scroll no documento que recolheria a barra, e o fim do conteúdo
         (ex.: tabela do Ranking) fica preso atrás dela. dvh acompanha o
         viewport visível de verdade. -->
    <main class="flex-1 flex flex-col relative overflow-y-auto overflow-x-hidden h-dvh custom-scrollbar pt-[calc(3.5rem+env(safe-area-inset-top))] md:pt-0 pb-[calc(80px+env(safe-area-inset-bottom))] md:pb-0">
        <router-view v-slot="{ Component, route }">
            <transition name="page" mode="out-in">
                <component :is="Component" :key="route.path" />
            </transition>
        </router-view>
    </main>

    <!-- Bottom Nav (Mobile) -->
    <DashboardBottomNav />

  </div>
</template>

<style scoped>
/* Bug real do Chromium: um filho width:auto de um flex-col com
   overflow-y:auto é "esticado" (align-items: stretch) usando um cálculo
   que ainda reserva a largura de uma scrollbar, mesmo com ela 100%
   escondida via CSS — sobra ~16px de largura fantasma, empurrando o
   conteúdo centralizado (mx-auto) pra fora da tela à direita. Só aparece
   em telas altas o bastante pra precisar rolar (ex.: Menu). width:100%
   explícito no filho não sofre desse cálculo. Aplicado aqui uma vez só
   pra cobrir toda página renderizada dentro do <main>, sem precisar
   mexer em cada view. */
main.custom-scrollbar > :deep(*) {
  width: 100%;
}
</style>
