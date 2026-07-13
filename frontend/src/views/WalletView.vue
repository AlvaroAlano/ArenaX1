<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { api } from '@/services/api'
import { txMeta } from '@/utils/transactions'
import ResponsibleGamingNote from '@/components/ui/ResponsibleGamingNote.vue'

const authStore = useAuthStore()
const toast = useToastStore()
const route = useRoute()
const activeTab = ref<'deposit' | 'withdraw'>(route.query.tab === 'withdraw' ? 'withdraw' : 'deposit')
const wallet = ref<any>(null)
const transactions = ref<any[]>([])
const loading = ref(true)

// Divisão do saldo: disponível (livre p/ jogar/sacar) vs. em jogo (congelado)
const availableBal = computed(() => wallet.value?.balance ?? 0)
const lockedBal = computed(() => wallet.value?.locked_balance ?? 0)
const totalBal = computed(() => availableBal.value + lockedBal.value)
const availablePct = computed(() => totalBal.value > 0 ? (availableBal.value / totalBal.value) * 100 : 100)

// Formulário de Depósito
const depositAmount = ref<number | null>(null)
const generatingPix = ref(false)
const pixData = ref<any>(null)
const depositSuccess = ref(false)

// Formulário de Saque
const withdrawAmount = ref<number | null>(null)
const pixKey = ref('')
const processingWithdraw = ref(false)
const withdrawError = ref('')
const withdrawSuccess = ref('')

const selectAmount = (value: number) => {
  depositAmount.value = value
}

// Carregar dados iniciais
const loadData = async () => {
  if (!authStore.user) return
  loading.value = true

  try {
    // 1. Buscar carteira
    const { data: walletData } = await supabase
      .from('wallets')
      .select('*')
      .eq('user_id', authStore.user.id)
      .single()
    wallet.value = walletData

    // 2. Buscar transações
    await loadTransactions()

    // 3. Detalhar o que compõe o saldo congelado (desafios + torneios em aberto)
    await loadLockedItems()
  } catch (err) {
    console.error('Erro ao carregar carteira:', err)
  } finally {
    loading.value = false
  }
}

// Detalhamento do locked_balance: de onde vem cada real congelado, pra não
// ficar só um número solto sem explicação (desafio aberto/em andamento +
// inscrição em torneio online com vagas abertas ou chave em andamento).
interface LockedItem { label: string; amount: number; to: string }
const lockedItems = ref<LockedItem[]>([])

const loadLockedItems = async () => {
  try {
    const [challenges, tournaments] = await Promise.all([
      api.get<any[]>('/api/challenges/my-challenges').catch(() => []),
      api.get<any[]>('/api/tournaments/online/my').catch(() => []),
    ])
    const items: LockedItem[] = []
    challenges
      .filter((c) => c.status === 'open' || c.status === 'in_progress')
      .forEach((c) => items.push({ label: `Desafio de ${c.game}`, amount: c.bet_amount, to: `/match/${c.id}` }))
    tournaments
      .filter((t: any) => t.status === 'registration_open' || t.status === 'in_progress')
      .forEach((t: any) => items.push({ label: `Torneio "${t.title}"`, amount: t.entry_fee, to: `/tournaments/${t.id}` }))
    lockedItems.value = items
  } catch {
    lockedItems.value = []
  }
}

const loadTransactions = async () => {
  if (!wallet.value) return
  const { data: txData } = await supabase
    .from('transactions')
    .select('*')
    .eq('wallet_id', wallet.value.id)
    .order('created_at', { ascending: false })
  
  transactions.value = txData || []
}

// Gerar depósito Pix
const handleGeneratePix = async () => {
  if (!depositAmount.value || depositAmount.value < 10) {
    toast.push('O valor mínimo de depósito é R$ 10,00.', 'error')
    return
  }

  generatingPix.value = false
  pixData.value = null
  depositSuccess.value = false

  generatingPix.value = true
  try {
    pixData.value = await api.post('/api/pix/deposit', { amount: depositAmount.value })
  } catch (err: any) {
    toast.push(err.message, 'error')
  } finally {
    generatingPix.value = false
  }
}

// Copiar código copia e cola
const copyCopiaCola = () => {
  if (!pixData.value?.copia_e_cola) return
  navigator.clipboard.writeText(pixData.value.copia_e_cola)
  toast.push('Código Pix copiado para a área de transferência!', 'success')
}

// Simular confirmação de pagamento para teste em desenvolvimento.
// Usa a rota /dev/simulate-deposit (exige o login do próprio usuário) em vez
// do /webhook real, que agora exige a assinatura do gateway de pagamento e
// nunca deve receber segredos vindos do navegador.
const simulatePaymentWebhook = async () => {
  if (!pixData.value?.external_id) return
  try {
    await api.post('/api/pix/dev/simulate-deposit', {
      external_id: pixData.value.external_id,
      amount: pixData.value.amount,
      status: 'completed'
    })
    depositSuccess.value = true
    pixData.value = null
    depositAmount.value = null
    await loadData()
  } catch (err: any) {
    toast.push(err.message || 'Erro ao simular pagamento.', 'error')
  }
}

// Realizar saque
const handleWithdraw = async () => {
  if (!withdrawAmount.value || withdrawAmount.value <= 0) {
    withdrawError.value = 'Insira um valor válido.'
    return
  }

  if (!pixKey.value) {
    withdrawError.value = 'Insira uma chave Pix para receber o saldo.'
    return
  }

  if (wallet.value && wallet.value.balance < withdrawAmount.value) {
    withdrawError.value = 'Saldo insuficiente.'
    return
  }

  processingWithdraw.value = true
  withdrawError.value = ''
  withdrawSuccess.value = ''

  try {
    const resData = await api.post<{ new_balance: number }>('/api/pix/withdraw', {
      amount: withdrawAmount.value,
      pix_key: pixKey.value
    })

    withdrawSuccess.value = 'Saque realizado com sucesso!'
    withdrawAmount.value = null
    pixKey.value = ''
    
    // Atualizar carteira localmente caso o canal demore
    if (wallet.value) {
      wallet.value.balance = resData.new_balance
    }
    await loadTransactions()
  } catch (err: any) {
    withdrawError.value = err.message
  } finally {
    processingWithdraw.value = false
  }
}

// Canais Realtime para atualizações em tempo real
let walletSub: any = null
let txSub: any = null

const setupRealtime = () => {
  if (!authStore.user) return

  // 1. Escutar alterações na carteira
  walletSub = supabase
    .channel('wallet-channel')
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'wallets', filter: `user_id=eq.${authStore.user.id}` },
      (payload) => {
        wallet.value = payload.new
        loadTransactions() // Recarregar extrato quando o saldo alterar
      }
    )
    .subscribe()

  // 2. Escutar inserções/updates de transações
  txSub = supabase
    .channel('tx-channel')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'transactions' },
      () => {
        loadTransactions()
      }
    )
    .subscribe()
}

onMounted(() => {
  loadData().then(() => {
    setupRealtime()
  })
})

onUnmounted(() => {
  if (walletSub) supabase.removeChannel(walletSub)
  if (txSub) supabase.removeChannel(txSub)
})
</script>

<template>
  <div class="flex-1 p-6 md:p-10 max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-3 gap-8">
    
    <!-- Lado Esquerdo: Painel de Ações Finanças (Depósito / Saque) -->
    <div class="lg:col-span-2 space-y-6">
      
      <!-- Seção Card de Saldo Atual -->
      <div class="bg-surface-1 border border-hairline p-8 rounded-lg shadow-none relative overflow-hidden group">

        <div class="flex justify-between items-start">
          <div>
            <h2 class="text-ink-subtle text-caption font-semibold uppercase tracking-wider mb-2">Saldo Disponível para Jogo</h2>
            <div v-if="loading" class="h-10 w-32 bg-[#262b35]  rounded-lg"></div>
            <div v-else class="text-4xl font-semibold text-ink">
              R$ {{ availableBal.toFixed(2) }}
            </div>
          </div>
          <div class="h-12 w-12 rounded-lg bg-primary flex items-center justify-center shadow-none shadow-none/20 shrink-0">
            <svg class="h-6 w-6 text-canvas" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
        </div>

        <!-- Barra disponível / em jogo -->
        <div v-if="!loading" class="mt-6">
          <div class="flex h-2 w-full overflow-hidden rounded-full bg-surface-3">
            <div class="bg-semantic-success transition-[width] duration-500" :style="{ width: availablePct + '%' }"></div>
            <div class="bg-amber-500 transition-[width] duration-500" :style="{ width: (100 - availablePct) + '%' }"></div>
          </div>
          <div class="mt-2.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-caption text-ink-subtle">
            <span class="inline-flex items-center gap-1.5">
              <span class="size-2 rounded-full bg-semantic-success"></span> Disponível: <span class="tabular-nums text-ink">R$ {{ availableBal.toFixed(2) }}</span>
            </span>
            <span v-if="lockedBal > 0" class="inline-flex items-center gap-1.5">
              <span class="size-2 rounded-full bg-amber-500"></span> Em jogo: <span class="tabular-nums text-ink">R$ {{ lockedBal.toFixed(2) }}</span>
            </span>
            <span class="ml-auto tabular-nums">Total: R$ {{ totalBal.toFixed(2) }}</span>
          </div>
        </div>
      </div>

      <!-- Detalhamento do saldo congelado (de onde vem cada real bloqueado) -->
      <div v-if="lockedItems.length > 0" class="bg-surface-1 border border-hairline rounded-lg p-5 space-y-2.5">
        <h3 class="text-caption font-semibold uppercase tracking-wider text-ink-subtle mb-1">Congelado em jogo</h3>
        <router-link
          v-for="(item, i) in lockedItems"
          :key="i"
          :to="item.to"
          class="flex items-center justify-between gap-3 rounded-lg bg-surface-2 px-3.5 py-2.5 no-underline hover:bg-surface-3 transition-colors"
        >
          <span class="text-body-sm text-ink truncate">{{ item.label }}</span>
          <span class="text-body-sm font-semibold text-ink-muted shrink-0">R$ {{ item.amount.toFixed(2) }}</span>
        </router-link>
      </div>

      <!-- Abas de Depósito e Saque -->
      <div class="bg-surface-1 border border-hairline rounded-lg overflow-hidden shadow-none ">
        <div class="flex border-b border-hairline">
          <button 
            @click="activeTab = 'deposit'"
            :class="[activeTab === 'deposit' ? 'border-[#00f2fe] text-primary bg-surface-2' : 'border-transparent text-ink-subtle hover:text-ink']"
            class="flex-1 py-4 text-center font-bold text-sm border-b-2 transition-all"
          >
            Depositar via Pix
          </button>
          <button 
            @click="activeTab = 'withdraw'"
            :class="[activeTab === 'withdraw' ? 'border-[#00f2fe] text-primary bg-surface-2' : 'border-transparent text-ink-subtle hover:text-ink']"
            class="flex-1 py-4 text-center font-bold text-sm border-b-2 transition-all"
          >
            Sacar via Pix
          </button>
        </div>

        <div class="p-6">
          <!-- CONTEÚDO DE DEPÓSITO -->
          <div v-if="activeTab === 'deposit'" class="space-y-6">
            <p class="text-sm text-ink-subtle">Selecione um valor rápido ou digite o valor que deseja depositar para começar a jogar.</p>

            <ResponsibleGamingNote variant="reminder" />

            <!-- Valores rápidos -->
            <div class="grid grid-cols-4 gap-3">
              <button 
                v-for="val in [10, 20, 50, 100]" 
                :key="val"
                @click="selectAmount(val)"
                :class="[depositAmount === val ? 'border-[#00f2fe] text-primary bg-[#00f2fe]/5' : 'border-hairline-strong text-ink hover:border-ink-subtle']"
                class="border py-3 rounded-lg font-bold transition-all text-sm"
              >
                R$ {{ val }}
              </button>
            </div>

            <!-- Input personalizado -->
            <div class="space-y-2">
              <label class="block text-caption font-semibold text-ink-subtle uppercase tracking-wider">Outro Valor (R$)</label>
              <input 
                v-model.number="depositAmount"
                type="number"
                placeholder="Valor mínimo R$ 10,00"
                class="w-full bg-surface-2 border border-hairline-strong rounded-lg px-4 py-3 text-ink placeholder-[#515c6e] focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
              />
            </div>

            <button 
              @click="handleGeneratePix"
              :disabled="generatingPix"
              class="w-full bg-primary text-canvas font-bold py-3.5 px-4 rounded-lg shadow-none transition-all text-sm disabled:opacity-50"
            >
              {{ generatingPix ? 'Gerando cobrança Pix...' : 'Gerar QR Code Pix' }}
            </button>

            <!-- Detalhes do Pix Gerado -->
            <div v-if="pixData" class="border border-hairline p-5 rounded-lg bg-surface-2 space-y-4 animate-fadeIn">
              <div class="flex flex-col md:flex-row items-center gap-6 justify-center">
                <img :src="pixData.qr_code_url" alt="QR Code Pix" class="w-44 h-44 border-4 border-white rounded-lg" />
                <div class="space-y-3 flex-1">
                  <h4 class="text-sm font-bold text-ink">Escaneie o QR Code ou copie o código abaixo:</h4>
                  <button 
                    @click="copyCopiaCola"
                    class="bg-surface-3 hover:bg-[#2e3543] border border-hairline-strong text-caption font-semibold py-2 px-3 rounded-lg text-primary transition-all flex items-center gap-1.5"
                  >
                    Copiar Código Pix Copia e Cola
                  </button>
                  <p class="text-caption text-ink-subtle">A compensação é instantânea. O saldo atualizará em tempo real.</p>
                </div>
              </div>

              <!-- Simular pagamento do Webhook (Somente Sandbox/Modo Teste) -->
              <div class="border-t border-hairline pt-4 flex flex-col md:flex-row justify-between items-center gap-3">
                <span class="text-caption text-ink-muted font-semibold bg-surface-2 px-3 py-1 rounded-full">Modo de Teste</span>
                <button 
                  @click="simulatePaymentWebhook"
                  class="bg-surface-2 hover:bg-green-500/20 border border-hairline text-semantic-success text-caption font-bold py-2 px-4 rounded-lg transition-all"
                >
                  Simular Confirmação de Pagamento
                </button>
              </div>
            </div>

            <!-- Sucesso de depósito -->
            <div v-if="depositSuccess" class="p-4 rounded-lg bg-surface-2 border border-hairline text-semantic-success text-sm font-semibold flex items-center justify-center gap-2">
              Depósito confirmado e creditado na sua carteira!
            </div>
          </div>

          <!-- CONTEÚDO DE SAQUE -->
          <div v-if="activeTab === 'withdraw'" class="space-y-5">
            <p class="text-sm text-ink-subtle">Retire seu saldo ganho nos desafios Pix direto para a sua conta bancária sem taxas.</p>
            
            <div class="space-y-2">
              <label class="block text-caption font-semibold text-ink-subtle uppercase tracking-wider">Chave Pix (CPF, Celular, E-mail ou Aleatória)</label>
              <input 
                v-model="pixKey"
                type="text"
                placeholder="Insira a chave do Pix"
                class="w-full bg-surface-2 border border-hairline-strong rounded-lg px-4 py-3 text-ink placeholder-[#515c6e] focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
              />
            </div>

            <div class="space-y-2">
              <label class="block text-caption font-semibold text-ink-subtle uppercase tracking-wider">Valor para Sacar (R$)</label>
              <input 
                v-model.number="withdrawAmount"
                type="number"
                placeholder="R$ 0,00"
                class="w-full bg-surface-2 border border-hairline-strong rounded-lg px-4 py-3 text-ink placeholder-[#515c6e] focus:outline-none focus:border-[#4facfe] transition-colors text-sm"
              />
            </div>

            <div v-if="withdrawError" class="p-3 bg-surface-2 border border-hairline text-ink-muted text-caption rounded-lg font-semibold">
              {{ withdrawError }}
            </div>

            <div v-if="withdrawSuccess" class="p-3 bg-surface-2 border border-hairline text-semantic-success text-caption rounded-lg font-semibold">
              {{ withdrawSuccess }}
            </div>

            <button 
              @click="handleWithdraw"
              :disabled="processingWithdraw"
              class="w-full bg-surface-3 border border-hairline-strong hover:bg-surface-4 text-ink font-bold py-3.5 px-4 rounded-lg shadow-none transition-all text-sm disabled:opacity-50"
            >
              {{ processingWithdraw ? 'Processando saque...' : 'Confirmar Saque Pix' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Lado Direito: Histórico de Transações (Extrato) -->
    <div class="bg-surface-1 border border-hairline p-6 rounded-lg shadow-none flex flex-col h-[550px] ">
      <h3 class="text-ink text-md font-bold mb-4">Extrato da Carteira</h3>
      
      <div v-if="loading" class="flex-1 flex items-center justify-center">
        <svg class="animate-spin h-8 w-8 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>

      <div v-else-if="transactions.length === 0" class="flex-1 flex flex-col items-center justify-center text-center space-y-2">
        <p class="text-ink-subtle text-sm">Nenhuma transação encontrada.</p>
        <p class="text-caption text-ink-tertiary">Seus depósitos e saques aparecerão aqui.</p>
      </div>

      <div v-else class="flex-1 overflow-y-auto space-y-3 pr-2 scrollbar">
        <div 
          v-for="tx in transactions" 
          :key="tx.id"
          class="bg-surface-2 border border-hairline p-4 rounded-lg flex justify-between items-center hover:border-hairline-strong transition-colors"
        >
          <div>
            <div class="flex items-center gap-2">
              <span
                :class="[
                  txMeta(tx.type).positive ? 'bg-surface-2 text-semantic-success' : 'bg-surface-2 text-ink-muted'
                ]"
                class="text-[10px] uppercase font-bold px-2 py-0.5 rounded-full"
              >
                {{ txMeta(tx.type).label }}
              </span>
              <span 
                :class="[
                  tx.status === 'completed' ? 'bg-surface-2 text-semantic-success' : tx.status === 'pending' ? 'bg-surface-2 text-ink-muted' : 'bg-surface-2 text-ink-muted'
                ]"
                class="text-[10px] uppercase font-bold px-2 py-0.5 rounded-full"
              >
                {{ tx.status === 'completed' ? 'Sucesso' : tx.status === 'pending' ? 'Pendente' : 'Falhou' }}
              </span>
            </div>
            <p class="text-caption text-ink-subtle mt-1.5">{{ tx.description }}</p>
            <span class="text-[10px] text-ink-tertiary block mt-0.5">{{ new Date(tx.created_at).toLocaleString() }}</span>
          </div>

          <div
            :class="[
              txMeta(tx.type).positive ? 'text-semantic-success' : 'text-ink-muted'
            ]"
            class="text-sm font-semibold"
          >
            {{ txMeta(tx.type).positive ? '+' : '' }}R$ {{ Math.abs(parseFloat(tx.amount)).toFixed(2) }}
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.scrollbar::-webkit-scrollbar {
  width: 4px;
}
.scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.scrollbar::-webkit-scrollbar-thumb {
  background: #2e3543;
  border-radius: 10px;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(5px); }
  to { opacity: 1; transform: translateY(0); }
}
.animate-fadeIn {
  animation: fadeIn 0.3s ease-out forwards;
}
</style>
