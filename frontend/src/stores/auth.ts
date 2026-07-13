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

  // Leitura direta via Supabase (RLS de profiles permite select pra qualquer
  // autenticado) — is_admin decide se mostra a entrada "Administração" no menu
  // (o acesso de verdade é sempre reconferido no backend, /api/admin/*);
  // deletion_requested_at dispara o auto-cancelamento da exclusão ao logar.
  async function loadProfileFlags(userId: string) {
    const { data } = await supabase
      .from('profiles')
      .select('is_admin, deletion_requested_at, deactivated_at, anonymized_at')
      .eq('id', userId)
      .single()
    isAdmin.value = data?.is_admin || false

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
    else isAdmin.value = false
    loading.value = false
  }

  // Inicializar escuta ativa de sessão
  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
    loading.value = false
    if (user.value) loadProfileFlags(user.value.id)
    else isAdmin.value = false
  })

  return {
    user,
    loading,
    isAdmin,
    fetchSession
  }
})
