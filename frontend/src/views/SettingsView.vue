<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/services/supabase'
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
} from '@lucide/vue'

const authStore = useAuthStore()

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
    <div class="max-w-[1000px] mx-auto space-y-6">

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
                            Conta não verificada
                        </span>
                        <span class="px-2.5 py-0.5 rounded-full bg-primary/10 text-primary text-xs font-semibold">
                            Email verificado
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

                <button class="flex items-center gap-3 px-4 py-3.5 bg-semantic-error/5 border border-semantic-error/20 rounded-xl text-sm font-medium hover:bg-semantic-error/10 w-full text-left transition-colors">
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
                            <select class="w-full h-11 rounded-lg border border-hairline bg-surface-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors text-ink">
                                <option value="">— Escolher —</option>
                                <option value="PS5">PS5</option>
                                <option value="Xbox Series">Xbox Series</option>
                                <option value="PC">PC</option>
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
                                <p class="text-xs text-ink-subtle">Configurado manualmente</p>
                            </div>
                        </div>
                        <span class="text-xs text-ink-subtle bg-surface-2 px-2 py-1 rounded">✓ Configurado</span>
                    </div>
                    
                    <div class="flex items-center justify-between p-4 border-b border-hairline">
                        <div class="flex items-center gap-4">
                            <div class="h-10 w-10 rounded-lg bg-surface-2 flex items-center justify-center">
                                <svg class="w-5 h-5" viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
                            </div>
                            <div>
                                <p class="font-semibold text-sm text-ink">Google</p>
                                <p class="text-xs text-ink-subtle">Conectado</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-2">
                            <span class="text-xs text-semantic-success">✓ Conectado</span>
                            <button class="text-xs text-semantic-error hover:text-red-400 font-medium ml-2">Desvincular</button>
                        </div>
                    </div>
                    
                    <div class="flex items-center justify-between p-4">
                        <div class="flex items-center gap-4">
                            <div class="h-10 w-10 rounded-lg bg-surface-2 flex items-center justify-center text-[#9146FF]">
                                <Tv :size="18" />
                            </div>
                            <div>
                                <p class="font-semibold text-sm text-ink">Twitch</p>
                                <p class="text-xs text-ink-subtle">Não conectado</p>
                            </div>
                        </div>
                        <button class="text-xs bg-purple-500/10 text-purple-400 px-3 py-1.5 rounded-lg font-bold hover:bg-purple-500/20 transition-colors">Vincular</button>
                    </div>
                </div>

                <!-- Identidade (KYC) Placeholder -->
                <div v-show="activeSection === 'identity'" class="bg-surface-1 border border-hairline rounded-xl p-6 animate-fade-in text-center">
                     <Fingerprint :size="36" class="text-ink-subtle mb-2" />
                     <h3 class="text-lg font-bold text-ink">Verificação de Identidade</h3>
                     <p class="text-sm text-ink-subtle mt-2 mb-6">Para processar saques, você precisa verificar sua identidade enviando um documento com foto.</p>
                     <button class="px-6 py-2.5 bg-surface-2 hover:bg-surface-2/80 text-primary border border-primary/20 rounded-lg font-bold text-sm transition-colors">
                         Iniciar Verificação (KYC)
                     </button>
                </div>

            </div>
        </div>

    </div>
  </div>
</template>
