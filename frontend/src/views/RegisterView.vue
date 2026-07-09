<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { User, Hash, Mail, Lock, Eye, EyeOff, Users, AlertCircle, CheckCircle2, LoaderCircle, Swords, Trophy, ShieldCheck, BadgeCheck } from '@lucide/vue'

const fullName = ref('')
const username = ref('')
const eaId = ref('')
const email = ref('')
const password = ref('')
const referralCode = ref('')
const acceptedTerms = ref(false)
const showPassword = ref(false)

const loading = ref(false)
const googleLoading = ref(false)
const errorMessage = ref('')
const successMessage = ref('')

const router = useRouter()

/* Cadastro com Google via Supabase: cria a conta e já autentica em um único passo,
   sem passar pelo formulário — mesmo fluxo usado no login. */
const handleGoogleAuth = async () => {
  googleLoading.value = true
  errorMessage.value = ''

  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: `${window.location.origin}/dashboard` }
  })

  if (error) {
    errorMessage.value = 'Não foi possível continuar com o Google. Tente novamente.'
    googleLoading.value = false
  }
}

const handleRegister = async () => {
  if (!fullName.value || !username.value || !email.value || !password.value || !eaId.value) {
    errorMessage.value = 'Preencha todos os campos obrigatórios.'
    return
  }

  if (!acceptedTerms.value) {
    errorMessage.value = 'Você deve aceitar os Termos de Utilização.'
    return
  }

  if (password.value.length < 6) {
    errorMessage.value = 'A palavra-passe precisa ter pelo menos 6 caracteres.'
    return
  }

  loading.value = true
  errorMessage.value = ''
  successMessage.value = ''

  try {
    const { data, error } = await supabase.auth.signUp({
      email: email.value,
      password: password.value,
      options: {
        data: {
          username: username.value,
          full_name: fullName.value,
          ea_id: eaId.value,
          referral_code: referralCode.value
        },
        emailRedirectTo: `${window.location.origin}/login`
      }
    })

    if (error) {
      errorMessage.value = error.message
      return
    }

    if (!data.session) {
      // Projeto tem confirmação de e-mail habilitada: não há sessão ainda,
      // então redirecionar pro /dashboard só bateria de volta no /login sem
      // explicação nenhuma. Avisar o usuário e não navegar.
      successMessage.value = 'Cadastro realizado! Confirme o seu e-mail para poder entrar.'
      return
    }

    successMessage.value = 'Cadastro realizado! Redirecionando para a Arena...'

    setTimeout(() => {
      router.push('/dashboard')
    }, 2000)

  } catch (err: any) {
    errorMessage.value = 'Ocorreu um erro ao tentar realizar o cadastro.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="relative flex flex-1 flex-col">

    <!-- Barra superior -->
    <header class="relative z-10 flex items-center justify-between px-6 py-6 lg:px-12">
      <router-link to="/" class="flex items-center gap-2.5 no-underline transition-opacity hover:opacity-80">
        <span class="grid size-9 place-items-center rounded-md bg-primary text-base font-black tracking-tighter text-canvas">X1</span>
        <span class="font-display text-xl font-black tracking-tight text-ink">ARENA<span class="text-primary">X1</span></span>
      </router-link>
      <router-link to="/login" class="text-button font-medium text-ink-subtle transition-colors hover:text-ink">
        Entrar
      </router-link>
    </header>

    <!-- Conteúdo -->
    <main class="relative z-10 flex flex-1 items-center justify-center p-4 lg:p-12">
      <div class="grid w-full max-w-[1200px] grid-cols-1 items-center gap-12 lg:grid-cols-2 lg:gap-20">

        <!-- Coluna esquerda: proposta de valor (desktop) -->
        <div class="mx-auto hidden w-full max-w-lg flex-col gap-10 lg:flex">
          <div>
            <span class="text-eyebrow uppercase tracking-widest text-accent">Comunidade competitiva</span>
            <h1 class="mt-3 font-display text-display-lg font-semibold leading-tight text-ink">
              Crie sua conta.<br />Comece a competir.
            </h1>
            <p class="mt-4 max-w-md text-body-lg leading-relaxed text-ink-subtle">
              Monte seu perfil de jogador e entre em desafios e torneios de EA FC e eFootball hoje mesmo.
            </p>
          </div>

          <div class="flex flex-col gap-5">
            <div class="flex items-start gap-4">
              <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
                <Swords :size="20" />
              </span>
              <div>
                <p class="font-semibold text-ink">Desafios 1v1 por dinheiro real</p>
                <p class="text-body-sm text-ink-subtle">Encontre um adversário do seu nível e prove sua habilidade.</p>
              </div>
            </div>
            <div class="flex items-start gap-4">
              <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-accent/10 text-accent">
                <Trophy :size="20" />
              </span>
              <div>
                <p class="font-semibold text-ink">Torneios com premiação garantida</p>
                <p class="text-body-sm text-ink-subtle">Competições estruturadas, chaveamento automático e prêmios reais.</p>
              </div>
            </div>
            <div class="flex items-start gap-4">
              <span class="grid size-11 shrink-0 place-items-center rounded-xl bg-semantic-success/10 text-semantic-success">
                <ShieldCheck :size="20" />
              </span>
              <div>
                <p class="font-semibold text-ink">Fair play com mediação de disputas</p>
                <p class="text-body-sm text-ink-subtle">Resultados divergentes são analisados pela nossa equipe.</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Coluna direita: formulário (full-bleed no mobile, card a partir do lg) -->
        <div class="mx-auto w-full p-6 lg:max-w-[440px] lg:rounded-2xl lg:border lg:border-hairline lg:bg-surface-1/60 lg:p-10 lg:backdrop-blur">
          <div class="mb-6">
            <h2 class="font-display text-display-md font-semibold tracking-tight text-ink">Criar uma conta</h2>
            <p class="mt-1 text-body-sm text-ink-subtle">Junte-se à comunidade EA FC / eFootball de elite</p>
          </div>

          <div v-if="errorMessage" class="mb-6 flex items-start gap-2.5 rounded-xl border border-semantic-error/20 bg-semantic-error/10 p-4 text-body-sm text-ink">
            <AlertCircle :size="18" class="mt-0.5 shrink-0 text-semantic-error" />
            <span>{{ errorMessage }}</span>
          </div>
          <div v-if="successMessage" class="mb-6 flex items-start gap-2.5 rounded-xl border border-semantic-success/20 bg-semantic-success/10 p-4 text-body-sm text-ink">
            <CheckCircle2 :size="18" class="mt-0.5 shrink-0 text-semantic-success" />
            <span>{{ successMessage }}</span>
          </div>

          <button
            type="button"
            @click="handleGoogleAuth"
            :disabled="googleLoading"
            class="mb-5 flex h-12 w-full items-center justify-center gap-3 rounded-lg border border-hairline bg-surface-2 text-body-sm font-semibold text-ink transition-colors hover:bg-surface-3 disabled:cursor-wait disabled:opacity-60"
          >
            <LoaderCircle v-if="googleLoading" :size="18" class="animate-spin" />
            <svg v-else class="size-5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
            </svg>
            {{ googleLoading ? 'Redirecionando...' : 'Continuar com Google' }}
          </button>

          <div class="mb-5 flex items-center gap-4">
            <div class="h-px flex-1 bg-hairline"></div>
            <span class="text-[10px] font-semibold uppercase tracking-widest text-ink-subtle">ou com e-mail</span>
            <div class="h-px flex-1 bg-hairline"></div>
          </div>

          <form @submit.prevent="handleRegister" class="space-y-4">

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div class="group relative">
                <User :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
                <input
                  v-model="fullName"
                  type="text"
                  autocomplete="name"
                  placeholder="Nome completo"
                  required
                  class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
                />
              </div>

              <div class="group relative">
                <BadgeCheck :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
                <input
                  v-model="username"
                  type="text"
                  autocomplete="nickname"
                  placeholder="Apelido (como vão te ver na Arena)"
                  required
                  class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
                />
              </div>
            </div>

            <div class="group relative">
              <Hash :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
              <input
                v-model="eaId"
                type="text"
                placeholder="EA ID"
                required
                class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
              />
            </div>

            <div class="group relative">
              <Mail :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
              <input
                v-model="email"
                type="email"
                autocomplete="email"
                placeholder="Endereço de e-mail"
                required
                class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
              />
            </div>

            <div class="group relative">
              <Lock :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                autocomplete="new-password"
                placeholder="Senha"
                required
                class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-11 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                class="absolute right-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors hover:text-ink"
              >
                <component :is="showPassword ? EyeOff : Eye" :size="18" />
              </button>
            </div>

            <div class="group relative">
              <Users :size="18" class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-tertiary transition-colors group-focus-within:text-primary" />
              <input
                v-model="referralCode"
                type="text"
                placeholder="Código de indicação (opcional)"
                class="h-12 w-full rounded-lg border border-hairline bg-surface-1 pl-11 pr-4 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
              />
            </div>

            <label class="flex cursor-pointer items-start gap-3 py-1">
              <input
                type="checkbox"
                v-model="acceptedTerms"
                required
                class="mt-0.5 size-4 cursor-pointer rounded border-hairline-strong bg-surface-2 text-primary focus:ring-primary focus:ring-offset-canvas"
              />
              <span class="text-caption leading-relaxed text-ink-subtle">
                Aceito os Termos de Utilização e a Política de Privacidade.
              </span>
            </label>

            <button
              type="submit"
              :disabled="loading"
              class="mt-2 flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3.5 text-button font-semibold text-canvas shadow-glow-primary transition-all hover:bg-primary-hover disabled:cursor-wait disabled:opacity-60"
            >
              <LoaderCircle v-if="loading" :size="18" class="animate-spin" />
              {{ loading ? 'Criando conta...' : 'Criar uma conta' }}
            </button>
          </form>

          <p class="mt-6 px-2 text-center text-[11px] leading-relaxed text-ink-tertiary">
            Ao se registrar, você aceita receber novidades de torneios e comunicados da ArenaX1.
          </p>

          <div class="mt-6 border-t border-hairline pt-6 text-center">
            <p class="text-caption text-ink-subtle">
              Já é membro?
              <router-link to="/login" class="font-semibold text-ink transition-colors hover:text-primary">
                Entrar
              </router-link>
            </p>
          </div>
        </div>

      </div>
    </main>
  </div>
</template>
