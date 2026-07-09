<script setup lang="ts">
import { computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import {
  LayoutDashboard,
  Swords,
  PlusCircle,
  Award,
  Trophy,
  Wallet,
  Settings,
  UserPlus,
  Headset,
  LogOut,
  ShieldCheck,
  ArrowLeft,
  LayoutGrid,
  ShieldAlert,
} from '@lucide/vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useWalletStore } from '@/stores/wallet'
import InstallPwaButton from '@/components/ui/InstallPwaButton.vue'
import NotificationBell from '@/components/ui/NotificationBell.vue'

const props = defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  (e: 'update:isOpen', value: boolean): void
}>()

const authStore = useAuthStore()
const walletStore = useWalletStore()
const router = useRouter()
const route = useRoute()

const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

// Ao entrar em /admin (ou qualquer sub-tela dele), o menu lateral troca de
// conjunto de opções — mesma sidebar, dois "modos" diferentes, alternados
// por transição. Baseado na rota (não num toggle manual) pra sobreviver a
// reload/link direto.
const isAdminSection = computed(() => route.path.startsWith('/admin'))

const handleLogout = async () => {
  await supabase.auth.signOut()
  router.push('/')
}

const closeSidebar = () => {
  emit('update:isOpen', false)
}
</script>

<template>
  <!-- Overlay Mobile -->
  <div
    v-if="isOpen"
    @click="closeSidebar"
    class="md:hidden fixed inset-0 bg-black/60 z-[9994]"
  ></div>

  <!-- Sidebar -->
  <aside
    :class="isOpen ? 'translate-x-0' : '-translate-x-full'"
    class="fixed inset-y-0 left-0 z-[9995] flex w-64 flex-col bg-surface-1 border-r border-hairline transition-transform duration-200 md:translate-x-0"
  >
      <!-- Logo Area -->
      <div class="flex h-16 items-center justify-between gap-3 border-b border-hairline px-6 shrink-0">
          <router-link to="/dashboard" @click="closeSidebar" class="flex items-center gap-2.5 no-underline">
              <span class="grid size-8 place-items-center rounded-md bg-primary text-[15px] font-black tracking-tighter text-canvas">X1</span>
              <span class="font-display text-lg font-black tracking-tight text-ink">ARENA<span class="text-primary">X1</span></span>
          </router-link>
          <NotificationBell align="left" />
      </div>

      <nav class="flex-1 overflow-y-auto overflow-x-hidden custom-scrollbar px-4 py-6">
          <Transition name="nav-slide" mode="out-in">
            <!-- Modo normal -->
            <div v-if="!isAdminSection" key="main" class="space-y-1">
                <div class="px-2 pb-2 text-[10px] font-bold text-ink-subtle uppercase tracking-wider">Principal</div>

                <router-link to="/dashboard" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors font-medium" active-class="bg-primary/10 text-primary" exact-active-class="bg-primary/10 text-primary">
                    <LayoutDashboard :size="20" />
                    Painel
                </router-link>

                <router-link to="/challenges" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <Swords :size="20" />
                    Desafios
                </router-link>

                <router-link to="/create-challenge" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-primary bg-primary/5 hover:bg-primary/10 font-bold border border-primary/20" active-class="bg-primary/20">
                    <PlusCircle :size="20" />
                    Criar um Desafio
                </router-link>

                <router-link to="/tournaments" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <Award :size="20" />
                    Torneios
                </router-link>

                <router-link to="/create-tournament" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-primary bg-primary/5 hover:bg-primary/10 font-bold border border-primary/20" active-class="bg-primary/20">
                    <PlusCircle :size="20" />
                    Criar Torneio Local
                </router-link>

                <router-link to="/ranking" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <Trophy :size="20" />
                    Classificação
                </router-link>

                <div class="px-2 pb-2 pt-6 text-[10px] font-bold text-ink-subtle uppercase tracking-wider">Finanças</div>

                <router-link to="/wallet" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <Wallet :size="20" />
                    Carteira
                </router-link>

                <div class="px-2 pb-2 pt-6 text-[10px] font-bold text-ink-subtle uppercase tracking-wider">Conta</div>

                <router-link to="/settings" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <Settings :size="20" />
                    Configurações
                </router-link>

                <router-link to="/referrals" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <UserPlus :size="20" />
                    Indicação
                </router-link>

                <router-link to="/support" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <Headset :size="20" />
                    Suporte
                </router-link>

                <template v-if="authStore.isAdmin">
                    <div class="px-2 pb-2 pt-6 text-[10px] font-bold text-ink-subtle uppercase tracking-wider">Administração</div>
                    <router-link to="/admin" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium">
                        <ShieldCheck :size="20" />
                        Painel Admin
                    </router-link>
                </template>
            </div>

            <!-- Modo admin -->
            <div v-else key="admin" class="space-y-1">
                <router-link
                  to="/dashboard"
                  @click="closeSidebar"
                  class="mb-3 flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold text-ink-subtle transition-colors hover:bg-surface-2 hover:text-ink"
                >
                    <ArrowLeft :size="18" />
                    Voltar ao menu
                </router-link>

                <div class="px-2 pb-2 text-[10px] font-bold text-ink-subtle uppercase tracking-wider">Administração</div>

                <router-link to="/admin" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors font-medium" active-class="bg-primary/10 text-primary" exact-active-class="bg-primary/10 text-primary">
                    <LayoutGrid :size="20" />
                    Visão Geral
                </router-link>

                <router-link to="/admin/disputes" @click="closeSidebar" class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors text-ink-subtle hover:bg-surface-2 hover:text-ink font-medium" active-class="bg-primary/10 text-primary">
                    <ShieldAlert :size="20" />
                    Disputas
                </router-link>
            </div>
          </Transition>

          <InstallPwaButton variant="ghost" class="w-full !justify-start mt-1" />

          <!-- Card Resumo Saldo -->
          <div class="mt-8 rounded-xl bg-surface-2 border border-hairline p-5">
              <p class="text-[10px] font-bold text-ink-subtle uppercase tracking-wider mb-1">Saldo Total</p>
              <p class="text-2xl font-bold font-display tabular-nums text-ink">
                {{ walletStore.loaded ? fmtBRL(walletStore.balance + walletStore.lockedBalance) : '···' }}
              </p>
              <router-link to="/wallet" @click="closeSidebar" class="mt-4 w-full py-2.5 text-xs font-bold uppercase tracking-wider bg-primary/10 text-primary rounded-lg hover:bg-primary/20 transition-colors block text-center no-underline">
                  Depositar
              </router-link>
          </div>
      </nav>

      <!-- User Profile Bottom -->
      <div class="border-t border-hairline p-5 shrink-0">
          <div class="flex items-center gap-3">
              <div class="h-10 w-10 rounded-full bg-primary/20 flex items-center justify-center text-sm font-black text-primary shrink-0 uppercase border border-primary/30">
                  {{ authStore.user?.email?.charAt(0) || 'U' }}
              </div>
              <div class="flex-1 min-w-0">
                  <p class="truncate text-sm font-bold text-ink">{{ authStore.user?.user_metadata?.username || 'Jogador' }}</p>
                  <p class="truncate text-xs text-ink-subtle">{{ authStore.user?.email }}</p>
              </div>
          </div>
          <button @click="handleLogout" class="mt-4 w-full flex items-center justify-center gap-2 text-xs font-bold text-semantic-error/80 hover:text-semantic-error hover:bg-semantic-error/10 py-2 rounded-md transition-colors no-underline">
              <LogOut :size="16" />
              Sair da Conta
          </button>
      </div>
  </aside>
</template>

<style scoped>
/* custom-scrollbar aqui usa só a regra global de main.css (barra 100%
   escondida) — um scoped override mostrando uma barra fina faz o
   Chrome/Android reservar aquele espaço físico em vez de sobrepor o
   conteúdo, ver DashboardLayout.vue pro caso confirmado desse bug. */

.nav-slide-enter-active,
.nav-slide-leave-active {
  transition: transform 0.22s ease, opacity 0.22s ease;
}
.nav-slide-enter-from {
  opacity: 0;
  transform: translateX(28px);
}
.nav-slide-leave-to {
  opacity: 0;
  transform: translateX(-28px);
}
</style>
