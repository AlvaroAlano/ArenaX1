import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '@/services/supabase'
import type { User } from '@supabase/supabase-js'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const loading = ref(true)

  async function fetchSession() {
    loading.value = true
    const { data } = await supabase.auth.getSession()
    user.value = data.session?.user || null
    loading.value = false
  }

  // Inicializar escuta ativa de sessão
  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null
    loading.value = false
  })

  return {
    user,
    loading,
    fetchSession
  }
})
