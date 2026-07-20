<script setup lang="ts">
import { useRouter } from 'vue-router'
import {
  Swords,
  Award,
  Trophy,
  Wallet,
  Settings,
  UserPlus,
  Headset,
  LogOut,
  ChevronRight,
  ShieldCheck,
} from '@lucide/vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const router = useRouter()

const handleLogout = async () => {
  await supabase.auth.signOut()
  router.push('/')
}

const mainItems = [
  { to: '/challenges', icon: Swords, label: 'Desafios', desc: 'Encontre um adversário e prove em campo' },
  { to: '/tournaments', icon: Award, label: 'Torneios', desc: 'Mata-mata com premiação de verdade' },
  { to: '/ranking', icon: Trophy, label: 'Classificação', desc: 'O ranking nacional é o seu palco' },
]

const financeItems = [
  { to: '/wallet', icon: Wallet, label: 'Carteira', desc: 'Depósitos, saques e histórico' },
]

const accountItems = [
  { to: '/settings', icon: Settings, label: 'Configurações', desc: 'Perfil, senha e preferências' },
  { to: '/support', icon: Headset, label: 'Suporte', desc: 'Fale com a nossa equipe' },
]

// Ainda não existe programa de indicação no produto — mostrado desabilitado
// em vez de link morto (mesmo tratamento da sidebar desktop).
const comingSoonItems = [
  { icon: UserPlus, label: 'Indicação', desc: 'Convide amigos e ganhe' },
]
</script>

<template>
  <div class="mx-auto max-w-2xl space-y-6 p-6 md:p-10">
    <!-- Perfil -->
    <div class="flex items-center gap-4 rounded-2xl border border-hairline bg-surface-2 p-5">
      <div class="grid size-12 shrink-0 place-items-center rounded-full border border-primary/30 bg-primary/20 text-sm font-black uppercase text-primary">
        {{ authStore.user?.email?.charAt(0) || 'U' }}
      </div>
      <div class="min-w-0 flex-1">
        <p class="truncate font-bold text-ink">{{ authStore.username || authStore.user?.user_metadata?.username || 'Jogador' }}</p>
        <p class="truncate text-body-sm text-ink-subtle">{{ authStore.user?.email }}</p>
      </div>
    </div>

    <!-- Administração (só pra admins) -->
    <section v-if="authStore.isAdmin" class="space-y-2">
      <h2 class="px-1 text-[10px] font-bold uppercase tracking-wider text-ink-subtle">Administração</h2>
      <nav class="space-y-2">
        <router-link
          to="/admin"
          class="flex items-center gap-3.5 rounded-xl border border-primary/25 bg-primary/[0.06] p-4 no-underline transition-colors hover:border-primary/40"
        >
          <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-primary/15 text-primary">
            <ShieldCheck :size="19" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block text-body-sm font-bold text-ink">Painel Admin</span>
            <span class="block truncate text-caption text-ink-tertiary">Métricas e disputas de torneio</span>
          </span>
          <ChevronRight :size="18" class="shrink-0 text-ink-tertiary" />
        </router-link>
      </nav>
    </section>

    <!-- Principal -->
    <section class="space-y-2">
      <h2 class="px-1 text-[10px] font-bold uppercase tracking-wider text-ink-subtle">Principal</h2>
      <nav class="space-y-2">
        <router-link
          v-for="item in mainItems"
          :key="item.to"
          :to="item.to"
          class="flex items-center gap-3.5 rounded-xl border border-hairline bg-surface-2 p-4 no-underline transition-colors hover:border-hairline-strong"
        >
          <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-surface-3 text-ink-subtle">
            <component :is="item.icon" :size="19" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block text-body-sm font-bold text-ink">{{ item.label }}</span>
            <span class="block truncate text-caption text-ink-tertiary">{{ item.desc }}</span>
          </span>
          <ChevronRight :size="18" class="shrink-0 text-ink-tertiary" />
        </router-link>
      </nav>
    </section>

    <!-- Finanças -->
    <section class="space-y-2">
      <h2 class="px-1 text-[10px] font-bold uppercase tracking-wider text-ink-subtle">Finanças</h2>
      <nav class="space-y-2">
        <router-link
          v-for="item in financeItems"
          :key="item.to"
          :to="item.to"
          class="flex items-center gap-3.5 rounded-xl border border-hairline bg-surface-2 p-4 no-underline transition-colors hover:border-hairline-strong"
        >
          <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-surface-3 text-ink-subtle">
            <component :is="item.icon" :size="19" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block text-body-sm font-bold text-ink">{{ item.label }}</span>
            <span class="block truncate text-caption text-ink-tertiary">{{ item.desc }}</span>
          </span>
          <ChevronRight :size="18" class="shrink-0 text-ink-tertiary" />
        </router-link>
      </nav>
    </section>

    <!-- Conta -->
    <section class="space-y-2">
      <h2 class="px-1 text-[10px] font-bold uppercase tracking-wider text-ink-subtle">Conta</h2>
      <nav class="space-y-2">
        <router-link
          v-for="item in accountItems"
          :key="item.to"
          :to="item.to"
          class="flex items-center gap-3.5 rounded-xl border border-hairline bg-surface-2 p-4 no-underline transition-colors hover:border-hairline-strong"
        >
          <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-surface-3 text-ink-subtle">
            <component :is="item.icon" :size="19" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block text-body-sm font-bold text-ink">{{ item.label }}</span>
            <span class="block truncate text-caption text-ink-tertiary">{{ item.desc }}</span>
          </span>
          <ChevronRight :size="18" class="shrink-0 text-ink-tertiary" />
        </router-link>

        <div
          v-for="item in comingSoonItems"
          :key="item.label"
          class="flex cursor-not-allowed items-center gap-3.5 rounded-xl border border-hairline bg-surface-2 p-4 opacity-60"
        >
          <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-surface-3 text-ink-tertiary">
            <component :is="item.icon" :size="19" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block text-body-sm font-bold text-ink-tertiary">{{ item.label }}</span>
            <span class="block truncate text-caption text-ink-tertiary">{{ item.desc }}</span>
          </span>
          <span class="shrink-0 rounded-full border border-hairline-strong bg-surface-3 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-ink-tertiary">Em breve</span>
        </div>
      </nav>
    </section>

    <!-- Sair -->
    <button
      type="button"
      @click="handleLogout"
      class="flex w-full items-center justify-center gap-2 rounded-xl border border-semantic-error/20 bg-semantic-error/5 py-3.5 text-body-sm font-bold text-semantic-error/90 transition-colors hover:bg-semantic-error/10 hover:text-semantic-error"
    >
      <LogOut :size="17" />
      Sair da Conta
    </button>
  </div>
</template>
