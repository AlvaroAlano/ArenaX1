import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '@/services/supabase'
import { api } from '@/services/api'
import { useToastStore } from '@/stores/toast'
import type { User } from '@supabase/supabase-js'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const loading = ref(true)
  const isAdmin = ref(false)
  const username = ref<string | null>(null)

  // Leitura direta via Supabase (RLS de profiles permite select pra qualquer
  // autenticado) — is_admin decide se mostra a entrada "Administração" no menu
  // (o acesso de verdade é sempre reconferido no backend, /api/admin/*);
  // deletion_requested_at dispara o auto-cancelamento da exclusão ao logar.
  // username fica aqui (em vez de cada componente buscar sozinho) pra Sidebar
  // e Menu mostrarem o nome real — user_metadata.username só existe pra quem
  // veio do cadastro por e-mail/senha, contas criadas de outro jeito (ex.:
  // direto no painel do Supabase) não têm esse metadata e caíam sempre no
  // fallback genérico "Jogador".
  async function loadProfileFlags(userId: string) {
    const { data, error } = await supabase
      .from('profiles')
      .select('username, is_admin, deletion_requested_at, deactivated_at, anonymized_at')
      .eq('id', userId)
      .single()

    // Sessão órfã: o token do Supabase Auth ainda é válido no navegador, mas
    // a conta foi apagada do banco por fora (ex.: limpeza de contas de teste)
    // — PGRST116 = "nenhuma linha encontrada". Sem isso, o app renderizava um
    // usuário "fantasma" (saldo zerado, nome genérico "Jogador", sem
    // partidas) em vez de perceber que a conta não existe mais e desconectar.
    if (error?.code === 'PGRST116') {
      await supabase.auth.signOut()
      user.value = null
      isAdmin.value = false
      username.value = null
      useToastStore().push('Sua sessão expirou. Faça login novamente.', 'error', 6000)
      return
    }

    isAdmin.value = data?.is_admin || false
    username.value = data?.username || null

    if (data?.anonymized_at) return

    // Logar de novo restaura a conta: cancela um pedido de exclusão dentro da
    // carência e/ou reativa uma conta desativada. Não bloqueia o login se o
    // backend estiver fora — dá pra reprocessar no próximo login.
    if (data?.deletion_requested_at) {
      api.post('/api/account/cancel-deletion')
        .then(() => useToastStore().push('Que bom te ver! Seu pedido de exclusão de conta foi cancelado.', 'success', 6000))
        .catch(() => {})
    }
    if (data?.deactivated_at) {
      api.post('/api/account/reactivate')
        .then(() => useToastStore().push('Bem-vindo de volta! Sua conta foi reativada.', 'success', 6000))
        .catch(() => {})
    }
  }

  async function fetchSession() {
    loading.value = true
    const { data } = await supabase.auth.getSession()
    user.value = data.session?.user || null
    if (user.value) await loadProfileFlags(user.value.id)
    else { isAdmin.value = false; username.value = null }
    loading.value = false
  }

  // Inicializar escuta ativa de sessão
  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
    loading.value = false
    if (user.value) loadProfileFlags(user.value.id)
    else { isAdmin.value = false; username.value = null }
  })

  return {
    user,
    loading,
    isAdmin,
    username,
    fetchSession
  }
})
