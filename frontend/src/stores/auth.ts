import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '@/services/supabase'
import type { User } from '@supabase/supabase-js'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const loading = ref(true)
  const isAdmin = ref(false)

  // Leitura direta via Supabase (RLS de profiles permite select pra qualquer
  // autenticado) — só usada pra decidir se mostra a entrada "Administração"
  // no menu; o acesso de verdade é sempre reconferido no backend (/api/admin/*).
  async function loadIsAdmin(userId: string) {
    const { data } = await supabase.from('profiles').select('is_admin').eq('id', userId).single()
    isAdmin.value = data?.is_admin || false
  }

  async function fetchSession() {
    loading.value = true
    const { data } = await supabase.auth.getSession()
    user.value = data.session?.user || null
    if (user.value) await loadIsAdmin(user.value.id)
    else isAdmin.value = false
    loading.value = false
  }

  // Inicializar escuta ativa de sessão
  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
    loading.value = false
    if (user.value) loadIsAdmin(user.value.id)
    else isAdmin.value = false
  })

  return {
    user,
    loading,
    isAdmin,
    fetchSession
  }
})
