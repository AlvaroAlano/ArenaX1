<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useWalletStore } from '@/stores/wallet'
import { supabase } from '@/services/supabase'
import { api } from '@/services/api'
import {
  AlertTriangle,
  User,
  ChevronRight,
  Link2,
  BadgeCheck,
  Shield,
  Goal,
  Tv,
  Fingerprint,
  LoaderCircle,
  X,
  PowerOff,
} from '@lucide/vue'

const router = useRouter()
const authStore = useAuthStore()
const walletStore = useWalletStore()

const isEmailVerified = computed(() => !!authStore.user?.email_confirmed_at)
const isGoogleLinked = computed(() => (authStore.user?.app_metadata?.providers as string[] | undefined)?.includes('google') ?? false)

const fmtBRL = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

/* ── Exclusão de conta: exclusão = anonimização com carência de 30 dias (ver
   backend/22_account_deletion.sql + account.py). O pedido é bloqueado pelo
   backend se houver saldo livre ou partida/torneio em andamento; aqui a gente
   já avisa sobre o saldo antes de deixar confirmar. ── */
const showDeleteModal = ref(false)
const deleteAck = ref(false)
const deleting = ref(false)
const deleteError = ref('')
const deleteDone = ref(false)

const hasFreeBalance = computed(() => walletStore.loaded && walletStore.balance > 0)

const openDeleteModal = () => {
    deleteAck.value = false
    deleteError.value = ''
    deleteDone.value = false
    showDeleteModal.value = true
    walletStore.fetchWallet(true)
}

const confirmDeletion = async () => {
    if (!deleteAck.value || deleting.value) return
    deleting.value = true
    deleteError.value = ''
    try {
        await api.post('/api/account/request-deletion')
        deleteDone.value = true
        // Desloga na hora (evita que um refresh de token na sequência dispare o
        // auto-cancelamento por engano) e manda pra landing.
        await supabase.auth.signOut()
        setTimeout(() => router.push('/'), 1800)
    } catch (err: any) {
        deleteError.value = err?.message || 'Não foi possível excluir a conta. Tente novamente.'
    } finally {
        deleting.value = false
    }
}

/* ── Desativar: irmão temporário e reversível do excluir. Some da vitrine e
   volta ao normal quando a pessoa logar de novo (ver stores/auth.ts). ── */
const showDeactivateModal = ref(false)
const deactivating = ref(false)
const deactivateError = ref('')
const deactivateDone = ref(false)

const openDeactivateModal = () => {
    deactivateError.value = ''
    deactivateDone.value = false
    showDeactivateModal.value = true
}

const confirmDeactivation = async () => {
    if (deactivating.value) return
    deactivating.value = true
    deactivateError.value = ''
    try {
        await api.post('/api/account/deactivate')
        deactivateDone.value = true
        await supabase.auth.signOut()
        setTimeout(() => router.push('/'), 1800)
    } catch (err: any) {
        deactivateError.value = err?.message || 'Não foi possível desativar a conta. Tente novamente.'
    } finally {
        deactivating.value = false
    }
}

const activeSection = ref('profile')

const setActiveSection = (section: string) => {
    activeSection.value = section
}

/* ── Perfil: profiles.username é o apelido exibido em todo canto (cards,
   ranking); full_name é o nome completo, mais "privado", mostrado só no
   próprio perfil e no perfil público. Carrega da tabela real (não do
   user_metadata do signup, que fica desatualizado assim que o usuário edita
   aqui). ── */
const profileLoading = ref(true)
const fullName = ref('')
const username = ref('')
const eaId = ref('')
const mainPlatform = ref('')
const saving = ref(false)
const saveError = ref('')
const saveSuccess = ref(false)

const loadProfile = async () => {
    if (!authStore.user) return
    profileLoading.value = true
    const { data } = await supabase.from('profiles').select('*').eq('id', authStore.user.id).single()
    fullName.value = data?.full_name || ''
    username.value = data?.username || ''
    eaId.value = data?.ea_id || ''
    mainPlatform.value = data?.main_platform || ''
    profileLoading.value = false
}
onMounted(loadProfile)

const handleSaveProfile = async () => {
    if (!authStore.user) return
    if (!username.value.trim()) {
        saveError.value = 'O apelido não pode ficar em branco.'
        return
    }

    saving.value = true
    saveError.value = ''
    saveSuccess.value = false
    try {
        const { error } = await supabase.from('profiles').update({
            full_name: fullName.value.trim() || null,
            username: username.value.trim(),
            ea_id: eaId.value.trim() || null,
            main_platform: mainPlatform.value || null,
            updated_at: new Date().toISOString(),
        }).eq('id', authStore.user.id)

        if (error) {
            saveError.value = error.code === '23505'
                ? 'Esse apelido já está em uso por outro jogador.'
                : 'Não foi possível salvar. Tente novamente.'
            return
        }
        saveSuccess.value = true
        setTimeout(() => { saveSuccess.value = false }, 3000)
    } finally {
        saving.value = false
    }
}
</script>

<template>
  <div class="flex-1 p-6 lg:p-10 w-full overflow-y-auto custom-scrollbar">
    <div class="max-w-[1400px] mx-auto space-y-6">

        <!-- Cabeçalho do Perfil -->
        <div class="flex flex-col gap-6 md:flex-row md:items-center justify-between bg-surface-1 p-6 rounded-xl border border-hairline">
            <div class="flex gap-5 items-center">
                <div class="relative">
                    <div class="h-20 w-20 rounded-full bg-primary/10 border-4 border-primary/30 flex items-center justify-center">
                        <span class="font-bold text-2xl text-primary">{{ (username || '??').substring(0,2).toUpperCase() }}</span>
                    </div>
                </div>
                <div class="flex flex-col">
                    <h1 class="text-2xl font-bold text-ink">{{ profileLoading ? '···' : (username || 'Sem apelido') }}</h1>
                    <p class="text-ink-subtle text-sm">{{ authStore.user?.email }}</p>
                    <div class="mt-2 flex gap-2 flex-wrap">
                        <span class="px-2.5 py-0.5 rounded-full bg-surface-3 text-ink-tertiary text-xs font-semibold flex items-center gap-1">
                            <AlertTriangle :size="14" />
                            Identidade não verificada
                        </span>
                        <span
                            class="px-2.5 py-0.5 rounded-full text-xs font-semibold"
                            :class="isEmailVerified ? 'bg-primary/10 text-primary' : 'bg-surface-3 text-ink-tertiary'"
                        >
                            {{ isEmailVerified ? 'Email verificado' : 'Email não verificado' }}
                        </span>
                    </div>
                </div>
            </div>
        </div>

        <div class="flex flex-col md:flex-row gap-6">
            <!-- Menu de Configurações Lateral -->
            <div class="md:w-64 shrink-0 space-y-3">
                <nav class="bg-surface-1 border border-hairline rounded-xl overflow-hidden">
                    <button @click="setActiveSection('profile')" :class="activeSection === 'profile' ? 'bg-surface-2' : ''" class="flex items-center gap-3 px-4 py-3.5 border-b border-hairline text-sm font-medium hover:bg-surface-2 w-full text-left transition-colors">
                        <User :size="18" class="text-primary" />
                        <span class="text-ink flex-1">Perfil</span>
                        <ChevronRight :size="14" class="text-ink-subtle" />
                    </button>
                    <button @click="setActiveSection('linked')" :class="activeSection === 'linked' ? 'bg-surface-2' : ''" class="flex items-center gap-3 px-4 py-3.5 border-b border-hairline text-sm font-medium hover:bg-surface-2 w-full text-left transition-colors">
                        <Link2 :size="18" class="text-primary" />
                        <span class="text-ink flex-1">Contas Vinculadas</span>
                        <ChevronRight :size="14" class="text-ink-subtle" />
                    </button>
                    <button @click="setActiveSection('identity')" :class="activeSection === 'identity' ? 'bg-surface-2' : ''" class="flex items-center gap-3 px-4 py-3.5 border-b border-hairline text-sm font-medium hover:bg-surface-2 w-full text-left transition-colors">
                        <BadgeCheck :size="18" class="text-primary" />
                        <span class="text-ink flex-1">Verificação KYC</span>
                        <ChevronRight :size="14" class="text-ink-subtle" />
                    </button>
                    <button @click="setActiveSection('security')" :class="activeSection === 'security' ? 'bg-surface-2' : ''" class="flex items-center gap-3 px-4 py-3.5 text-sm font-medium hover:bg-surface-2 w-full text-left transition-colors">
                        <Shield :size="18" class="text-primary" />
                        <span class="text-ink flex-1">Segurança (2FA)</span>
                        <ChevronRight :size="14" class="text-ink-subtle" />
                    </button>
                </nav>

                <button @click="setActiveSection('danger')" :class="activeSection === 'danger' ? 'bg-semantic-error/15' : 'bg-semantic-error/5'" class="flex items-center gap-3 px-4 py-3.5 border border-semantic-error/20 rounded-xl text-sm font-medium hover:bg-semantic-error/10 w-full text-left transition-colors">
                    <AlertTriangle :size="18" class="text-semantic-error" />
                    <span class="text-semantic-error font-bold flex-1">Zona de Perigo</span>
                    <ChevronRight :size="14" class="text-semantic-error" />
                </button>
            </div>

            <!-- Conteúdo Dinâmico -->
            <div class="flex-1">
                
                <!-- Informações do Perfil -->
                <div v-show="activeSection === 'profile'" class="bg-surface-1 border border-hairline rounded-xl p-6 space-y-5 animate-fade-in">
                    <h3 class="font-bold flex items-center gap-2 text-ink">
                        <User class="text-primary" />
                        Informações do Perfil
                    </h3>
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div>
                            <label class="block text-xs text-ink-subtle mb-1">Nome Completo</label>
                            <input v-model="fullName" type="text" placeholder="Seu nome completo" :disabled="profileLoading" class="w-full h-11 rounded-lg border border-hairline bg-surface-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors text-ink disabled:opacity-60">
                        </div>
                        <div>
                            <label class="block text-xs text-ink-subtle mb-1">Apelido <span class="text-ink-tertiary normal-case">(exibido pra outros jogadores)</span></label>
                            <input v-model="username" type="text" placeholder="Como quer ser visto na Arena" :disabled="profileLoading" class="w-full h-11 rounded-lg border border-hairline bg-surface-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors text-ink disabled:opacity-60">
                        </div>
                        <div>
                            <label class="block text-xs text-ink-subtle mb-1">EA Sports ID / Gamertag</label>
                            <input v-model="eaId" type="text" placeholder="O seu ID..." :disabled="profileLoading" class="w-full h-11 rounded-lg border border-hairline bg-surface-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors text-ink disabled:opacity-60">
                        </div>
                        <div>
                            <label class="block text-xs text-ink-subtle mb-1">Plataforma Principal</label>
                            <select v-model="mainPlatform" :disabled="profileLoading" class="w-full h-11 rounded-lg border border-hairline bg-surface-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors text-ink disabled:opacity-60">
                                <option value="">— Escolher —</option>
                                <option value="PS5">PS5</option>
                                <option value="Xbox">Xbox</option>
                                <option value="PC">PC</option>
                                <option value="Crossplay">Crossplay</option>
                            </select>
                        </div>
                        <div>
                            <label class="block text-xs text-ink-subtle mb-1">E-mail</label>
                            <input type="email" :value="authStore.user?.email" disabled class="w-full h-11 rounded-lg border border-hairline bg-surface-2/50 px-3 text-sm text-ink-subtle cursor-not-allowed">
                        </div>
                    </div>
                    <p v-if="saveError" class="text-sm text-semantic-error">{{ saveError }}</p>
                    <p v-if="saveSuccess" class="text-sm text-semantic-success">Alterações salvas.</p>
                    <div class="flex justify-end pt-4">
                        <button
                            type="button"
                            @click="handleSaveProfile"
                            :disabled="saving || profileLoading"
                            class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-hover text-canvas rounded-lg font-bold text-sm transition-colors disabled:cursor-wait disabled:opacity-60"
                        >
                            <LoaderCircle v-if="saving" :size="16" class="animate-spin" />
                            {{ saving ? 'Salvando...' : 'Salvar Alterações' }}
                        </button>
                    </div>
                </div>

                <!-- Contas Vinculadas -->
                <div v-show="activeSection === 'linked'" class="bg-surface-1 border border-hairline rounded-xl overflow-hidden animate-fade-in">
                    <div class="p-5 border-b border-hairline">
                        <h3 class="font-bold flex items-center gap-2 text-ink">
                            <Link2 class="text-primary" />
                            Contas Vinculadas
                        </h3>
                    </div>
                    
                    <div class="flex items-center justify-between p-4 border-b border-hairline">
                        <div class="flex items-center gap-4">
                            <div class="h-10 w-10 rounded-lg bg-surface-2 flex items-center justify-center text-primary">
                                <Goal :size="18" />
                            </div>
                            <div>
                                <p class="font-semibold text-sm text-ink">EA Sports ID</p>
                                <p class="text-xs text-ink-subtle">{{ eaId ? 'Configurado manualmente' : 'Ainda não configurado' }}</p>
                            </div>
                        </div>
                        <span
                            class="text-xs px-2 py-1 rounded"
                            :class="eaId ? 'text-ink-subtle bg-surface-2' : 'text-ink-tertiary bg-surface-3'"
                        >{{ eaId ? '✓ Configurado' : 'Pendente' }}</span>
                    </div>

                    <div class="flex items-center justify-between p-4 border-b border-hairline">
                        <div class="flex items-center gap-4">
                            <div class="h-10 w-10 rounded-lg bg-surface-2 flex items-center justify-center">
                                <svg class="w-5 h-5" viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
                            </div>
                            <div>
                                <p class="font-semibold text-sm text-ink">Google</p>
                                <p class="text-xs text-ink-subtle">{{ isGoogleLinked ? 'Conectado' : 'Não conectado' }}</p>
                            </div>
                        </div>
                        <span v-if="isGoogleLinked" class="text-xs text-semantic-success">✓ Conectado</span>
                        <span v-else class="text-xs text-ink-tertiary">Login feito com email e senha</span>
                    </div>

                    <div class="flex items-center justify-between p-4">
                        <div class="flex items-center gap-4">
                            <div class="h-10 w-10 rounded-lg bg-surface-2 flex items-center justify-center text-[#9146FF]">
                                <Tv :size="18" />
                            </div>
                            <div>
                                <p class="font-semibold text-sm text-ink">Twitch</p>
                                <p class="text-xs text-ink-subtle">Em breve</p>
                            </div>
                        </div>
                        <button disabled class="text-xs bg-surface-2 text-ink-tertiary px-3 py-1.5 rounded-lg font-bold cursor-not-allowed">Vincular</button>
                    </div>
                </div>

                <!-- Identidade (KYC) Placeholder -->
                <div v-show="activeSection === 'identity'" class="bg-surface-1 border border-hairline rounded-xl p-6 animate-fade-in text-center">
                     <Fingerprint :size="36" class="text-ink-subtle mb-2" />
                     <h3 class="text-lg font-bold text-ink">Verificação de Identidade</h3>
                     <p class="text-sm text-ink-subtle mt-2 mb-6">Para processar saques, você precisa verificar sua identidade enviando um documento com foto.</p>
                     <button disabled class="px-6 py-2.5 bg-surface-2 text-ink-tertiary border border-hairline rounded-lg font-bold text-sm cursor-not-allowed">
                         Em breve
                     </button>
                </div>

                <!-- Segurança (2FA) Placeholder -->
                <div v-show="activeSection === 'security'" class="bg-surface-1 border border-hairline rounded-xl p-6 animate-fade-in text-center">
                     <Shield :size="36" class="text-ink-subtle mb-2" />
                     <h3 class="text-lg font-bold text-ink">Autenticação em Duas Etapas</h3>
                     <p class="text-sm text-ink-subtle mt-2 mb-6">Uma camada extra de segurança pra sua conta e sua carteira. Ainda não disponível.</p>
                     <button disabled class="px-6 py-2.5 bg-surface-2 text-ink-tertiary border border-hairline rounded-lg font-bold text-sm cursor-not-allowed">
                         Em breve
                     </button>
                </div>

                <!-- Zona de Perigo: desativar (temporário) vs excluir (definitivo) -->
                <div v-show="activeSection === 'danger'" class="space-y-4 animate-fade-in">
                    <!-- Desativar -->
                    <div class="bg-surface-1 border border-hairline rounded-xl p-6 flex flex-col sm:flex-row sm:items-center gap-4">
                        <div class="flex-1">
                            <h3 class="font-bold text-ink flex items-center gap-2">
                                <PowerOff :size="18" class="text-amber-400" />
                                Desativar temporariamente
                            </h3>
                            <p class="text-sm text-ink-subtle mt-1.5">Sua conta some da vitrine e ninguém consegue te desafiar. Seu saldo e histórico ficam guardados — é só fazer login de novo pra voltar ao normal, sem prazo.</p>
                        </div>
                        <button @click="openDeactivateModal" class="shrink-0 px-5 py-2.5 rounded-lg border border-amber-400/30 bg-amber-400/10 text-amber-400 font-bold text-sm hover:bg-amber-400/20 transition-colors">
                            Desativar
                        </button>
                    </div>

                    <!-- Excluir -->
                    <div class="bg-surface-1 border border-semantic-error/20 rounded-xl p-6 flex flex-col sm:flex-row sm:items-center gap-4">
                        <div class="flex-1">
                            <h3 class="font-bold text-ink flex items-center gap-2">
                                <AlertTriangle :size="18" class="text-semantic-error" />
                                Excluir minha conta
                            </h3>
                            <p class="text-sm text-ink-subtle mt-1.5">Seus dados são anonimizados após 30 dias. Reversível só dentro desse prazo (logando de novo); depois é permanente.</p>
                        </div>
                        <button @click="openDeleteModal" class="shrink-0 px-5 py-2.5 rounded-lg border border-semantic-error/30 bg-semantic-error/10 text-semantic-error font-bold text-sm hover:bg-semantic-error/20 transition-colors">
                            Excluir
                        </button>
                    </div>
                </div>

            </div>
        </div>

    </div>

    <!-- Modal de desativação (temporária, reversível — sem checkbox de alarme) -->
    <Teleport to="body">
    <Transition name="fade">
      <div v-if="showDeactivateModal" class="fixed inset-0 z-[9995] flex items-end sm:items-center justify-center p-0 sm:p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="!deactivating && !deactivateDone && (showDeactivateModal = false)"></div>
        <div class="relative w-full sm:max-w-lg bg-surface-1 border border-hairline rounded-t-2xl sm:rounded-2xl shadow-card-premium">
          <div v-if="deactivateDone" class="p-8 text-center">
            <div class="mx-auto mb-4 grid size-14 place-items-center rounded-full bg-amber-400/10 text-amber-400">
              <PowerOff :size="28" />
            </div>
            <h3 class="text-lg font-bold text-ink">Conta desativada</h3>
            <p class="text-sm text-ink-subtle mt-2">Sua conta ficou invisível na plataforma. Quando quiser voltar, é só fazer login de novo — tudo estará como você deixou. Você será desconectado agora.</p>
          </div>
          <div v-else>
            <div class="flex items-start justify-between gap-4 p-5 border-b border-hairline">
              <div class="flex items-center gap-3">
                <div class="grid size-10 shrink-0 place-items-center rounded-xl bg-amber-400/10 text-amber-400">
                  <PowerOff :size="20" />
                </div>
                <h3 class="text-lg font-bold text-ink">Desativar temporariamente</h3>
              </div>
              <button @click="showDeactivateModal = false" :disabled="deactivating" class="text-ink-subtle hover:text-ink transition-colors disabled:opacity-40">
                <X :size="20" />
              </button>
            </div>
            <div class="p-5 space-y-3 text-sm text-ink-subtle">
              <p>Enquanto desativada, sua conta:</p>
              <ul class="space-y-2">
                <li class="flex gap-3"><span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span><span>Some da vitrine — seus desafios abertos não aparecem e ninguém pode te desafiar.</span></li>
                <li class="flex gap-3"><span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span><span>Mantém <strong class="text-ink">saldo e histórico intactos</strong>. Nada é apagado.</span></li>
                <li class="flex gap-3"><span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span><span>Volta ao normal <strong class="text-ink">assim que você fizer login</strong> de novo, sem prazo nenhum.</span></li>
              </ul>
              <p v-if="deactivateError" class="font-semibold text-semantic-error">{{ deactivateError }}</p>
            </div>
            <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-2 p-5 border-t border-hairline">
              <button @click="showDeactivateModal = false" :disabled="deactivating" class="px-5 py-2.5 rounded-lg border border-hairline bg-surface-2 text-ink font-bold text-sm hover:bg-surface-3 transition-colors disabled:opacity-50">
                Voltar
              </button>
              <button @click="confirmDeactivation" :disabled="deactivating" class="flex items-center justify-center gap-2 px-5 py-2.5 rounded-lg bg-amber-400 text-canvas font-bold text-sm hover:bg-amber-400/90 transition-colors disabled:opacity-50">
                <LoaderCircle v-if="deactivating" :size="16" class="animate-spin" />
                {{ deactivating ? 'Desativando...' : 'Desativar conta' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
    </Teleport>

    <!-- Modal de exclusão de conta. Teleport pro body pra escapar do contexto
         de stacking/overflow do <main> — senão o rodapé flutuante (bottom nav)
         vaza por cima dos botões. Mesmo padrão do PullToRefresh e do glow. -->
    <Teleport to="body">
    <Transition name="fade">
      <div v-if="showDeleteModal" class="fixed inset-0 z-[9995] flex items-end sm:items-center justify-center p-0 sm:p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="!deleting && !deleteDone && (showDeleteModal = false)"></div>

        <div class="relative w-full sm:max-w-lg bg-surface-1 border border-hairline rounded-t-2xl sm:rounded-2xl shadow-card-premium max-h-[92vh] overflow-y-auto custom-scrollbar">

          <!-- Estado final: pedido feito -->
          <div v-if="deleteDone" class="p-8 text-center">
            <div class="mx-auto mb-4 grid size-14 place-items-center rounded-full bg-semantic-success/10 text-semantic-success">
              <BadgeCheck :size="28" />
            </div>
            <h3 class="text-lg font-bold text-ink">Exclusão agendada</h3>
            <p class="text-sm text-ink-subtle mt-2">Sua conta será excluída em <strong class="text-ink">30 dias</strong>. Mudou de ideia? É só fazer login de novo dentro desse prazo que tudo volta ao normal. Você será desconectado agora.</p>
          </div>

          <!-- Formulário de confirmação -->
          <div v-else>
            <div class="flex items-start justify-between gap-4 p-5 border-b border-hairline">
              <div class="flex items-center gap-3">
                <div class="grid size-10 shrink-0 place-items-center rounded-xl bg-semantic-error/10 text-semantic-error">
                  <AlertTriangle :size="20" />
                </div>
                <h3 class="text-lg font-bold text-ink">Excluir minha conta</h3>
              </div>
              <button @click="showDeleteModal = false" :disabled="deleting" class="text-ink-subtle hover:text-ink transition-colors disabled:opacity-40">
                <X :size="20" />
              </button>
            </div>

            <div class="p-5 space-y-4">
              <!-- Bloqueio por saldo (aviso amigável antes do backend recusar) -->
              <div v-if="hasFreeBalance" class="flex items-start gap-3 rounded-xl border border-semantic-error/25 bg-semantic-error/5 p-4">
                <AlertTriangle :size="18" class="mt-0.5 shrink-0 text-semantic-error" />
                <p class="text-sm text-ink">
                  Você ainda tem <strong class="text-semantic-error">{{ fmtBRL(walletStore.balance) }}</strong> em saldo livre. Saque tudo antes de excluir a conta — nunca ficamos com o seu dinheiro.
                </p>
              </div>

              <p class="text-sm text-ink-subtle">Antes de continuar, entenda o que acontece:</p>

              <ul class="space-y-3 text-sm">
                <li class="flex gap-3">
                  <span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span>
                  <span class="text-ink-subtle">Seus dados pessoais (nome, apelido e IDs de jogo) são substituídos por um identificador anônimo. Seu histórico de partidas continua existindo, mas <strong class="text-ink">sem o seu nome</strong>.</span>
                </li>
                <li class="flex gap-3">
                  <span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span>
                  <span class="text-ink-subtle">Você tem <strong class="text-ink">30 dias</strong> pra mudar de ideia: basta fazer login de novo nesse prazo que a exclusão é cancelada. Depois disso é <strong class="text-ink">definitivo</strong>.</span>
                </li>
                <li class="flex gap-3">
                  <span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span>
                  <span class="text-ink-subtle">Seu apelido <strong class="text-ink">{{ username || 'atual' }}</strong> fica reservado e não poderá ser usado por outra pessoa.</span>
                </li>
                <li class="flex gap-3">
                  <span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span>
                  <span class="text-ink-subtle">Disputas em análise <strong class="text-ink">seguem seu curso normal</strong> e ainda podem creditar saldo à sua conta, mesmo depois da exclusão.</span>
                </li>
                <li class="flex gap-3">
                  <span class="mt-1.5 size-1.5 shrink-0 rounded-full bg-ink-tertiary"></span>
                  <span class="text-ink-subtle">Não é possível excluir com <strong class="text-ink">partidas ou torneios em andamento</strong> — termine-os primeiro.</span>
                </li>
              </ul>

              <label class="flex items-start gap-3 rounded-xl border border-hairline bg-surface-2 p-4 cursor-pointer">
                <input type="checkbox" v-model="deleteAck" class="mt-0.5 size-4 shrink-0 accent-semantic-error" />
                <span class="text-sm text-ink">Li e entendo que, após 30 dias, a exclusão é permanente e não pode ser desfeita.</span>
              </label>

              <p v-if="deleteError" class="text-sm font-semibold text-semantic-error">{{ deleteError }}</p>
            </div>

            <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-2 p-5 border-t border-hairline">
              <button @click="showDeleteModal = false" :disabled="deleting" class="px-5 py-2.5 rounded-lg border border-hairline bg-surface-2 text-ink font-bold text-sm hover:bg-surface-3 transition-colors disabled:opacity-50">
                Cancelar
              </button>
              <button
                @click="confirmDeletion"
                :disabled="!deleteAck || deleting"
                class="flex items-center justify-center gap-2 px-5 py-2.5 rounded-lg bg-semantic-error text-white font-bold text-sm hover:bg-semantic-error/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <LoaderCircle v-if="deleting" :size="16" class="animate-spin" />
                {{ deleting ? 'Processando...' : 'Excluir minha conta' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
