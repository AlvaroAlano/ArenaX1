<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { CalendarDays, Star, Gamepad2, Hash, SearchX, Pencil } from '@lucide/vue'

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
  psn_id: string | null
  xbox_id: string | null
  steam_id: string | null
  fair_play_rating: number
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
        .select('id, username, full_name, ea_id, psn_id, xbox_id, steam_id, fair_play_rating, created_at')
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

const mainPlatform = computed(() => {
    if (!profile.value) return null
    if (profile.value.psn_id) return 'PS5'
    if (profile.value.xbox_id) return 'Xbox'
    if (profile.value.steam_id) return 'PC'
    return null
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
</script>

<template>
  <div class="mx-auto w-full max-w-4xl space-y-6 p-6 lg:p-10">

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
        <button @click="router.back()" class="mt-2 text-body-sm font-semibold text-primary hover:underline">Voltar</button>
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

      <!-- Plataforma / EA ID -->
      <div v-if="mainPlatform || profile.ea_id" class="flex flex-wrap items-center gap-2">
        <span v-if="mainPlatform" class="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle">
            <Gamepad2 :size="14" class="text-accent" /> {{ mainPlatform }}
        </span>
        <span v-if="profile.ea_id" class="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-surface-1 px-3 py-1.5 text-caption font-semibold text-ink-subtle">
            <Hash :size="13" /> EA ID: <span class="text-ink">{{ profile.ea_id }}</span>
        </span>
      </div>

      <!-- Reputação -->
      <div class="flex flex-col justify-between rounded-2xl border border-hairline bg-surface-1 p-6 sm:max-w-xs">
        <div class="flex items-start justify-between">
            <p class="text-caption font-semibold uppercase tracking-widest text-ink-tertiary">Reputação</p>
            <span class="grid size-9 place-items-center rounded-lg bg-amber-400/10 text-amber-400">
                <Star :size="18" fill="currentColor" />
            </span>
        </div>
        <div class="mt-4">
            <p class="font-display text-4xl font-bold tabular-nums text-ink">
                {{ profile.fair_play_rating.toFixed(1) }}<span class="text-xl text-ink-tertiary">/5.0</span>
            </p>
            <p class="mt-1 text-body-sm font-medium text-amber-400">{{ ratingLabel }}</p>
        </div>
      </div>
    </template>

  </div>
</template>
