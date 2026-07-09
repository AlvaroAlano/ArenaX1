<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { Mail, Lock, Eye, EyeOff, AlertCircle, LoaderCircle, Swords, Trophy, ShieldCheck, Zap } from '@lucide/vue'

const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const showPassword = ref(false)
const loading = ref(false)
const googleLoading = ref(false)
const errorMessage = ref('')
const needsConfirmation = ref(false)
const resendingConfirmation = ref(false)
const resendSuccess = ref(false)

const router = useRouter()

/* Acesso rápido só em ambiente de dev (Vite troca DEV->false no build de
   produção, então isso nunca chega ao usuário final). Usa a conta de teste
   já existente no Supabase deste projeto. */
const isDev = import.meta.env.DEV
const DEV_EMAIL = 'admin@arenax1.com'
const DEV_PASSWORD = '123456'

const handleQuickAccess = () => {
  email.value = DEV_EMAIL
  password.value = DEV_PASSWORD
  handleLogin()
}

/* Login com Google via Supabase: se o e-mail ainda não tem conta, cria na hora
   e já autentica — não precisa passar pelo formulário de cadastro. */
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

const handleLogin = async () => {
  if (!email.value || !password.value) {
    errorMessage.value = 'Preencha todos os campos.'
    return
  }

  loading.value = true
  errorMessage.value = ''
  needsConfirmation.value = false
  resendSuccess.value = false

  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value
    })

    if (error) {
      if (error.message === 'Email not confirmed') {
        errorMessage.value = 'Confirme o seu e-mail antes de entrar. Verifique a caixa de entrada (e o spam).'
        needsConfirmation.value = true
      } else {
        errorMessage.value = error.message === 'Invalid login credentials'
          ? 'E-mail ou senha incorretos.'
          : error.message
      }
      return
    }

    router.push('/dashboard')
  } catch (err: any) {
    errorMessage.value = 'Ocorreu um erro ao tentar fazer login.'
  } finally {
    loading.value = false
  }
}

const handleResendConfirmation = async () => {
  if (!email.value) return
  resendingConfirmation.value = true
  resendSuccess.value = false
  try {
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email.value,
      options: { emailRedirectTo: `${window.location.origin}/login` }
    })
    if (error) {
      errorMessage.value = error.message
    } else {
      resendSuccess.value = true
    }
  } finally {
    resendingConfirmation.value = false
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
      <router-link to="/register" class="text-button font-medium text-ink-subtle transition-colors hover:text-ink">
        Criar Conta
      </router-link>
    </header>

    <!-- Conteúdo -->
    <main class="relative z-10 flex flex-1 items-center justify-center p-4 lg:p-12">
      <div class="grid w-full max-w-[1200px] grid-cols-1 items-center gap-12 lg:grid-cols-2 lg:gap-20">

        <!-- Coluna esquerda: proposta de valor (desktop) -->
        <div class="mx-auto hidden w-full max-w-lg flex-col gap-10 lg:flex">
          <div>
            <span class="text-eyebrow uppercase tracking-widest text-accent">Arena competitiva 1v1</span>
            <h1 class="mt-3 font-display text-display-lg font-semibold leading-tight text-ink">
              Entre na arena.<br />Prove que é o melhor.
            </h1>
            <p class="mt-4 max-w-md text-body-lg leading-relaxed text-ink-subtle">
              Acesse o seu perfil e volte a competir em desafios e torneios de EA FC e eFootball.
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
            <h2 class="font-display text-display-md font-semibold tracking-tight text-ink">Bem-vindo de volta</h2>
            <p class="mt-1 text-body-sm text-ink-subtle">Acesse sua conta para continuar</p>
          </div>

          <div v-if="errorMessage" class="mb-6 flex flex-col gap-2.5 rounded-xl border border-semantic-error/20 bg-semantic-error/10 p-4 text-body-sm text-ink">
            <div class="flex items-start gap-2.5">
              <AlertCircle :size="18" class="mt-0.5 shrink-0 text-semantic-error" />
              <span>{{ errorMessage }}</span>
            </div>
            <button
              v-if="needsConfirmation"
              type="button"
              @click="handleResendConfirmation"
              :disabled="resendingConfirmation"
              class="ml-[26px] self-start text-button font-semibold text-primary hover:underline disabled:opacity-60"
            >
              {{ resendingConfirmation ? 'Reenviando...' : 'Reenviar e-mail de confirmação' }}
            </button>
            <p v-if="resendSuccess" class="ml-[26px] text-semantic-success">E-mail reenviado! Confira a sua caixa de entrada.</p>
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

          <form @submit.prevent="handleLogin" class="space-y-4">
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
                autocomplete="current-password"
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

            <div class="flex items-center justify-between">
              <label class="group flex cursor-pointer items-center gap-2.5">
                <input
                  type="checkbox"
                  v-model="rememberMe"
                  class="size-4 cursor-pointer rounded border-hairline-strong bg-surface-2 text-primary focus:ring-primary focus:ring-offset-canvas"
                />
                <span class="text-caption text-ink-subtle transition-colors group-hover:text-ink">Lembrar-me</span>
              </label>
              <a href="#" class="text-caption text-ink-subtle transition-colors hover:text-primary">Esqueceu a senha?</a>
            </div>

            <button
              type="submit"
              :disabled="loading"
              class="mt-2 flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3.5 text-button font-semibold text-canvas shadow-glow-primary transition-all hover:bg-primary-hover disabled:cursor-wait disabled:opacity-60"
            >
              <LoaderCircle v-if="loading" :size="18" class="animate-spin" />
              {{ loading ? 'Entrando...' : 'Entrar' }}
            </button>
          </form>

          <div class="mt-6 border-t border-hairline pt-6 text-center">
            <p class="text-caption text-ink-subtle">
              Ainda não tem conta na ArenaX1?
              <router-link to="/register" class="font-semibold text-ink transition-colors hover:text-primary">
                Criar uma conta
              </router-link>
            </p>
          </div>

          <!-- Acesso rápido: só existe em ambiente de desenvolvimento -->
          <button
            v-if="isDev"
            type="button"
            @click="handleQuickAccess"
            :disabled="loading"
            class="mt-4 flex w-full items-center justify-center gap-2 rounded-lg border border-dashed border-accent/30 bg-accent/5 py-3 text-caption font-semibold text-accent transition-colors hover:bg-accent/10 disabled:cursor-wait disabled:opacity-60"
          >
            <Zap :size="14" />
            Acesso rápido (dev) — entrar como jogador de teste
          </button>
        </div>

      </div>
    </main>
  </div>
</template>
