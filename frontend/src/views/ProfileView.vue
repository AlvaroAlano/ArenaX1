<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { CalendarDays, Star, Gamepad2, Hash, SearchX, Pencil, ArrowLeft, PowerOff, AlertTriangle } from '@lucide/vue'

const props = defineProps<{ username: string }>()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

/**
 * Perfil público: username é o apelido (mostrado em todo canto — cards de
 * desafio, ranking); full_name só aparece aqui, no perfil detalhado. RLS de
 * profiles libera select pra qualquer autenticado (ver backend/policies.sql),
 * então dá pra ler direto pelo client, sem endpoint novo no backend.
 */
interface Profile {
  id: string
  username: string
  full_name: string | null
  ea_id: string | null
  main_platform: string | null
  fair_play_rating: number
  abandoned_matches: number
  abandonment_badge_public_at: string | null
  deactivated_at: string | null
  created_at: string
}

const loading = ref(true)
const notFound = ref(false)
const profile = ref<Profile | null>(null)

const loadProfile = async (username: string) => {
    loading.value = true
    notFound.value = false
    profile.value = null

    const { data } = await supabase.from('profiles')
        .select('id, username, full_name, ea_id, main_platform, fair_play_rating, abandoned_matches, abandonment_badge_public_at, deactivated_at, created_at')
        .eq('username', username)
        .maybeSingle()

    if (!data) notFound.value = true
    else profile.value = data
    loading.value = false
}

loadProfile(props.username)
watch(() => route.params.username, (u) => { if (typeof u === 'string') loadProfile(u) })

const isOwnProfile = computed(() => authStore.user?.id === profile.value?.id)

const initials = computed(() => (profile.value?.username || '??').substring(0, 2).toUpperCase())

const mainPlatform = computed(() => profile.value?.main_platform || null)

// Selo de alerta de abandono (punição reputacional, não-financeira). Não basta
// cruzar o limiar de abandonos: o backend agenda a publicação 48h depois (janela
// de contestação, regra 1.4) em abandonment_badge_public_at. O selo só aparece
// quando esse instante já passou — nada de comparar abandoned_matches direto.
const showAbandonBadge = computed(() => {
    const at = profile.value?.abandonment_badge_public_at
    return at != null && new Date(at).getTime() <= Date.now()
})

const memberSince = computed(() => {
    if (!profile.value) return ''
    return new Date(profile.value.created_at).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
})

const ratingLabel = computed(() => {
    const r = profile.value?.fair_play_rating ?? 5
    if (r >= 4.5) return 'Reputação exemplar'
    if (r >= 3.5) return 'Boa reputação'
    if (r >= 2.5) return 'Reputação regular'
    return 'Reputação baixa'
})
const ratingColor = computed(() => {
    const r = profile.value?.fair_play_rating ?? 5
    if (r >= 4.5) return 'text-accent'
    if (r >= 3.5) return 'text-emerald-400'
    if (r >= 2.5) return 'text-amber-400'
    return 'text-red-400'
})
const ratingIconClass = computed(() => {
    const r = profile.value?.fair_play_rating ?? 5
    if (r >= 4.5) return 'bg-accent/10 text-accent'
    if (r >= 3.5) return 'bg-emerald-400/10 text-emerald-400'
    if (r >= 2.5) return 'bg-amber-400/10 text-amber-400'
    return 'bg-red-400/10 text-red-400'
})
</script>

<template>
  <div class="mx-auto w-full max-w-6xl space-y-6 p-6 lg:p-10">

    <!-- Voltar pra onde quer que o usuário estivesse antes (lista de
         solicitações de um desafio, lobby, ranking...) — sempre router.back()
         em vez de um destino fixo, já que esse perfil é acessado de vários
         lugares diferentes do app. -->
    <button
      type="button"
      @click="router.back()"
      class="inline-flex w-fit items-center gap-1.5 text-body-sm text-ink-subtle transition-colors hover:text-primary"
    >
      <ArrowLeft :size="14" />
      Voltar
    </button>

    <!-- Carregando -->
    <div v-if="loading" class="animate-pulse space-y-6">
      <div class="h-24 rounded-2xl bg-surface-2"></div>
      <div class="h-40 rounded-2xl bg-surface-2"></div>
    </div>

    <!-- Não encontrado -->
    <div v-else-if="notFound" class="flex flex-col items-center gap-3 py-24 text-center">
        <span class="grid size-14 place-items-center rounded-2xl bg-surface-2 text-ink-tertiary">
            <SearchX :size="26" />
        </span>
        <p class="font-semibold text-ink">Jogador não encontrado</p>
        <p class="max-w-xs text-body-sm text-ink-subtle">Não existe ninguém com o apelido "{{ props.username }}" na Arena.</p>
    </div>

    <!-- Conta desativada (some da vitrine pra quem não é o dono) -->
    <div v-else-if="profile && profile.deactivated_at && !isOwnProfile" class="flex flex-col items-center gap-3 py-24 text-center">
        <span class="grid size-14 place-items-center rounded-2xl bg-surface-2 text-ink-tertiary">
            <PowerOff :size="26" />
        </span>
        <p class="font-semibold text-ink">Conta desativada</p>
        <p class="max-w-xs text-body-sm text-ink-subtle">Este jogador desativou a conta temporariamente e não está disponível na Arena agora.</p>
    </div>

    <template v-else-if="profile">
      <!-- Cabeçalho -->
      <div class="flex flex-col gap-6 rounded-2xl border border-hairline bg-surface-1 p-6 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-5">
            <div class="grid size-16 shrink-0 place-items-center rounded-2xl border border-primary/30 bg-primary/10 font-display text-xl font-bold uppercase text-primary">
                {{ initials }}
            </div>
            <div>
                <h1 class="font-display text-2xl font-bold text-ink">{{ profile.username }}</h1>
                <p v-if="profile.full_name" class="text-body-sm text-ink-subtle">{{ profile.full_name }}</p>
                <p class="mt-1 flex items-center gap-1.5 text-caption text-ink-tertiary">
                    <CalendarDays :size="13" /> Na Arena desde {{ memberSince }}
                </p>
            </div>
        </div>
        <router-link
            v-if="isOwnProfile"
            to="/settings"
            class="inline-flex w-fit items-center gap-2 rounded-lg border border-hairline-strong bg-surface-2 px-4 py-2 text-body-sm font-semibold text-ink no-underline transition-colors hover:bg-surface-3"
        >
            <Pencil :size="14" /> Editar perfil
        </router-link>
      </div>

      <!-- Plataforma / EA ID / alerta de abandono -->
      <div v-if="mainPlatform || profile.ea_id || showAbandonBadge" class="flex flex-wrap items-center gap-2">
        <span v-if="mainPlatform" class="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle">
            <Gamepad2 :size="14" class="text-accent" /> {{ mainPlatform }}
        </span>
        <span v-if="profile.ea_id" class="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle">
            <Hash :size="13" /> EA ID: <span class="text-ink">{{ profile.ea_id }}</span>
        </span>
        <span v-if="showAbandonBadge" class="inline-flex items-center gap-1.5 rounded-full border border-amber-500/30 bg-amber-500/10 px-3 py-1.5 text-caption font-semibold text-amber-500" title="Abandonou partidas recentemente">
            <AlertTriangle :size="13" /> Histórico de abandono
        </span>
      </div>

      <!-- Reputação -->
      <div class="flex flex-col justify-between rounded-2xl border border-hairline bg-surface-1 p-6 sm:max-w-xs">
        <div class="flex items-start justify-between">
            <p class="text-caption font-semibold uppercase tracking-widest text-ink-tertiary">Reputação</p>
            <span class="grid size-9 place-items-center rounded-lg transition-colors" :class="ratingIconClass">
                <Star :size="18" fill="currentColor" />
            </span>
        </div>
        <div class="mt-4">
            <p class="font-display text-4xl font-bold tabular-nums text-ink">
                {{ profile.fair_play_rating.toFixed(1) }}<span class="text-xl text-ink-tertiary">/5.0</span>
            </p>
            <p class="mt-1 text-body-sm font-medium transition-colors" :class="ratingColor">{{ ratingLabel }}</p>
        </div>
      </div>
    </template>

  </div>
</template>
