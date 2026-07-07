import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'

export const useWalletStore = defineStore('wallet', () => {
  const id = ref<string | null>(null)
  const balance = ref(0)
  const lockedBalance = ref(0)
  const loaded = ref(false)

  let inFlight: Promise<void> | null = null

  // Compartilhada entre o header/sidebar (exibição) e a Home (extrato usa o
  // wallet.id) — evita buscar a carteira mais de uma vez por sessão. Chamada
  // simultânea de vários componentes no mount reaproveita a mesma promise.
  async function fetchWallet(force = false) {
    if (loaded.value && !force) return
    if (inFlight) return inFlight

    const authStore = useAuthStore()
    if (!authStore.user) return

    inFlight = (async () => {
      const { data } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', authStore.user!.id)
        .single()
      id.value = data?.id ?? null
      balance.value = Number(data?.balance ?? 0)
      lockedBalance.value = Number(data?.locked_balance ?? 0)
      loaded.value = true
    })()

    try {
      await inFlight
    } finally {
      inFlight = null
    }
  }

  return { id, balance, lockedBalance, loaded, fetchWallet }
})
