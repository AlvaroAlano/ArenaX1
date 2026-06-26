<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'

const email = ref('admin@arenax1.com')
const password = ref('123456')
const rememberMe = ref(false)
const showPassword = ref(false)
const loading = ref(false)
const errorMessage = ref('')

const router = useRouter()

const handleLogin = async () => {
  if (!email.value || !password.value) {
    errorMessage.value = 'Preencha todos os campos.'
    return
  }

  loading.value = true
  errorMessage.value = ''

  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value
    })

    if (error) {
      errorMessage.value = error.message === 'Invalid login credentials' 
        ? 'E-mail ou senha incorretos.' 
        : error.message
      return
    }

    router.push('/dashboard')
  } catch (err: any) {
    errorMessage.value = 'Ocorreu um erro ao tentar fazer login.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-canvas text-ink flex flex-col relative overflow-hidden">
    
    <!-- Barra de Navegação Superior -->
    <header class="px-6 lg:px-12 py-6 flex items-center justify-between z-10 relative">
      <div class="flex items-center gap-3">
        <svg class="w-8 h-8 text-primary" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path d="M21.58 6.91a2 2 0 0 0-1.28-1.12c-2.31-.76-7.85-1.52-8.3-1.52s-5.99.76-8.3 1.52A2 2 0 0 0 2.42 6.91C1.04 10.97 1 15.68 1 15.68a2 2 0 0 0 1.28 1.55c1.33.44 4.09.87 6.44 1.15.54.06.94.57.87 1.11-.06.49-.48.86-.97.86h-1.18a.75.75 0 0 0 0 1.5h9.12a.75.75 0 0 0 0-1.5h-1.18c-.49 0-.91-.37-.97-.86-.07-.54.33-1.05.87-1.11 2.35-.28 5.11-.71 6.44-1.15a2 2 0 0 0 1.28-1.55s.04-4.71-1.34-8.77zM9.5 12a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z" />
        </svg>
        <span class="font-display font-semibold text-headline tracking-tight">Arena X1</span>
      </div>
      <router-link to="/register" class="text-button text-ink-subtle hover:text-ink transition-colors font-medium">
        Criar Conta
      </router-link>
    </header>

    <!-- Conteúdo Principal -->
    <main class="flex-1 flex items-center justify-center p-4 lg:p-12 relative z-10">
      <div class="w-full max-w-[1280px] grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-24 items-center">
        
        <!-- Coluna Esquerda (Conteúdo Promocional - Desktop Only) -->
        <div class="hidden lg:flex flex-col gap-10 w-full max-w-xl mx-auto">
          <div class="relative rounded-xl overflow-hidden border border-hairline aspect-[4/3] group shadow-none">
            <img 
              src="https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=2070&q=80" 
              class="absolute inset-0 w-full h-full object-cover transition-transform duration-700 group-hover:scale-105" 
              alt="Estádio de Futebol" 
            />
            <div class="absolute inset-0 bg-gradient-to-t from-canvas via-canvas/40 to-transparent pointer-events-none"></div>
            <div class="absolute bottom-10 left-10 right-10">
              <span class="inline-block bg-primary text-ink text-[11px] font-bold px-3 py-1.5 rounded-sm uppercase tracking-widest mb-4">
                BEM-VINDO DE VOLTA
              </span>
              <h2 class="text-display-lg font-display font-semibold leading-tight text-ink">
                Domine o Campo.<br />Conquiste a Coroa.
              </h2>
            </div>
          </div>
          <div>
            <h3 class="text-headline font-display font-semibold mb-3">Junte-se à Arena X1</h3>
            <p class="text-body-lg text-ink-subtle leading-relaxed max-w-md">
              Acesse o seu perfil de jogador pro e continue competindo em torneios FIFA / eFootball mundiais.
            </p>
          </div>
        </div>

        <!-- Coluna Direita (Formulário de Login) -->
        <div class="w-full max-w-md mx-auto px-2 lg:mx-0 lg:max-w-[480px] lg:bg-surface-1 lg:border lg:border-hairline lg:rounded-lg lg:p-10">
          
          <!-- Cabeçalho do Formulário -->
          <div class="mb-6">
            <h1 class="text-display-md font-display font-semibold tracking-tight text-ink mb-2">Entrar na Arena</h1>
            <p class="text-ink-subtle text-caption">Acesse sua conta para continuar</p>
          </div>

          <!-- Alertas -->
          <div v-if="errorMessage" class="mb-6 p-4 rounded-md bg-surface-2 border border-hairline text-ink-muted text-caption flex items-center gap-2">
            <span class="font-semibold text-ink">Erro:</span> {{ errorMessage }}
          </div>

          <!-- Botões de Login Social -->
          <div class="grid grid-cols-2 gap-3 mb-6">
            <button class="bg-surface-2 hover:bg-surface-3 border border-hairline text-ink py-3 rounded-md flex items-center justify-center gap-3 transition-colors text-button font-medium">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
              </svg>
              Google
            </button>
            <button class="bg-surface-2 hover:bg-surface-3 border border-hairline text-ink py-3 rounded-md flex items-center justify-center gap-3 transition-colors text-button font-medium">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="#9146FF" xmlns="http://www.w3.org/2000/svg">
                <path d="M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z" />
              </svg>
              Twitch
            </button>
          </div>

          <!-- Divisor Centrado -->
          <div class="flex items-center gap-4 mb-6">
            <div class="flex-1 h-px bg-hairline"></div>
            <span class="text-[10px] text-ink-subtle uppercase tracking-widest font-semibold">OU COM O SEU E-MAIL</span>
            <div class="flex-1 h-px bg-hairline"></div>
          </div>

          <!-- Formulário -->
          <form @submit.prevent="handleLogin" class="space-y-4">
            
            <!-- Email -->
            <div class="relative group">
              <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ink-tertiary group-focus-within:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <input 
                v-model="email" 
                type="email" 
                placeholder="Endereço de E-mail" 
                required 
                class="w-full bg-surface-2 border border-hairline rounded-md pl-12 pr-4 py-3.5 text-ink placeholder-ink-tertiary focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all text-body-sm"
              />
            </div>

            <!-- Senha -->
            <div class="relative group">
              <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ink-tertiary group-focus-within:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
              <input 
                v-model="password" 
                :type="showPassword ? 'text' : 'password'" 
                placeholder="Palavra-passe" 
                required 
                class="w-full bg-surface-2 border border-hairline rounded-md pl-12 pr-12 py-3.5 text-ink placeholder-ink-tertiary focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all text-body-sm"
              />
              <button 
                type="button" 
                @click="showPassword = !showPassword"
                class="absolute right-4 top-1/2 -translate-y-1/2 text-ink-tertiary hover:text-ink transition-colors"
              >
                <svg v-if="!showPassword" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
                <svg v-else class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                </svg>
              </button>
            </div>

            <!-- Opções de Formulário -->
            <div class="flex items-center justify-between mb-2">
              <label class="flex items-center gap-3 cursor-pointer group">
                <input 
                  type="checkbox" 
                  v-model="rememberMe"
                  class="w-4 h-4 rounded-xs border-hairline bg-surface-2 text-primary focus:ring-primary focus:ring-offset-canvas cursor-pointer"
                />
                <span class="text-caption text-ink-subtle group-hover:text-ink transition-colors">Lembrar-me</span>
              </label>
              <a href="#" class="text-caption text-ink-subtle hover:text-ink transition-colors">Esqueceu a senha?</a>
            </div>

            <!-- Botão Principal -->
            <button 
              type="submit" 
              :disabled="loading" 
              class="w-full bg-primary hover:bg-primary-hover text-ink py-4 rounded-md font-medium text-button transition-all disabled:opacity-50 flex items-center justify-center gap-2 mt-4"
            >
              <svg v-if="loading" class="animate-spin h-4 w-4 text-ink" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              {{ loading ? 'Entrando...' : 'Entrar' }}
            </button>
          </form>

          <!-- Link de Criação de Conta de Rodapé -->
          <div class="mt-6 text-center border-t border-hairline pt-6">
            <p class="text-caption text-ink-subtle">
              Ainda não tem conta na Arena X1? 
              <router-link to="/register" class="text-ink font-medium hover:text-primary transition-colors">
                Criar uma Conta
              </router-link>
            </p>
          </div>

        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.bg-canvas {
  background-image: radial-gradient(circle at center, #1b202c 0%, #0d0e12 100%);
}
</style>
