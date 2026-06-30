<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  challengeId: string
}>()

const authStore = useAuthStore()
const toast = useToast()

const dispute = ref<any>(null)
const messages = ref<any[]>([])
const newMessage = ref('')
const loading = ref(true)
const sending = ref(false)
const uploading = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)

let realtimeSub: any = null
const messagesContainer = ref<HTMLElement | null>(null)

// 1. Buscar a Disputa
const loadDispute = async () => {
  try {
    const { data, error } = await supabase
      .from('disputes')
      .select('*')
      .eq('challenge_id', props.challengeId)
      .single()

    if (error && error.code !== 'PGRST116') throw error
    dispute.value = data
  } catch (err) {
    console.error('Erro ao buscar disputa:', err)
  }
}

// 2. Buscar Mensagens
const loadMessages = async () => {
  if (!dispute.value) return
  
  try {
    const { data, error } = await supabase
      .from('dispute_messages')
      .select('*, sender:sender_id(username)')
      .eq('dispute_id', dispute.value.id)
      .order('created_at', { ascending: true })

    if (error) throw error
    messages.value = data || []
    scrollToBottom()
  } catch (err) {
    console.error('Erro ao buscar mensagens:', err)
  } finally {
    loading.value = false
  }
}

// 3. Enviar Mensagem
const sendMessage = async (attachmentUrl: string | null = null) => {
  if (!newMessage.value.trim() && !attachmentUrl) return
  if (!dispute.value) return

  sending.value = true
  try {
    const { error } = await supabase.from('dispute_messages').insert({
      dispute_id: dispute.value.id,
      sender_id: authStore.user?.id,
      message: newMessage.value.trim(),
      attachment_url: attachmentUrl
    })

    if (error) throw error
    newMessage.value = ''
  } catch (err) {
    console.error('Erro ao enviar mensagem:', err)
    toast.error('Erro ao enviar mensagem.')
  } finally {
    sending.value = false
  }
}

// 4. Upload de Arquivo
const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  if (file.size > 5 * 1024 * 1024) {
    toast.error('Arquivo muito grande. O limite é 5MB.')
    return
  }

  uploading.value = true
  try {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Math.random()}.${fileExt}`
    const filePath = `${dispute.value.id}/${fileName}`

    // Faz upload para o bucket 'disputes'
    const { error: uploadError } = await supabase.storage
      .from('disputes')
      .upload(filePath, file)

    if (uploadError) throw uploadError

    // Pega a URL pública
    const { data } = supabase.storage.from('disputes').getPublicUrl(filePath)
    
    // Envia como mensagem
    await sendMessage(data.publicUrl)

  } catch (err) {
    console.error('Erro no upload:', err)
    toast.error('Erro ao enviar anexo.')
  } finally {
    uploading.value = false
    if (fileInput.value) fileInput.value.value = ''
  }
}

// 5. Configurar Realtime
const setupRealtime = () => {
  if (!dispute.value) return

  realtimeSub = supabase
    .channel(`dispute-${dispute.value.id}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'dispute_messages', filter: `dispute_id=eq.${dispute.value.id}` },
      async (payload) => {
        // Buscar o username para a nova mensagem (já que o trigger Realtime não traz joins automáticos)
        const { data: userData } = await supabase
          .from('profiles')
          .select('username')
          .eq('id', payload.new.sender_id)
          .single()

        messages.value.push({
          ...payload.new,
          sender: userData
        })
        scrollToBottom()
      }
    )
    .subscribe()
}

const scrollToBottom = () => {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
}

onMounted(async () => {
  await loadDispute()
  await loadMessages()
  setupRealtime()
})

onUnmounted(() => {
  if (realtimeSub) supabase.removeChannel(realtimeSub)
})
</script>

<template>
  <div class="bg-surface-1 border border-hairline rounded-xxl overflow-hidden flex flex-col h-[600px]">
    
    <!-- Header -->
    <div class="bg-surface-2 border-b border-hairline p-5 flex items-center justify-between">
      <div>
        <h3 class="text-ink font-semibold uppercase tracking-wider flex items-center gap-2">
          <span class="w-3 h-3 rounded-full bg-red-500 "></span>
          Chat de Mediação
        </h3>
        <p class="text-ink-subtle text-caption mt-1">Nossa equipe acompanhará esta disputa.</p>
      </div>
      <span class="text-caption font-bold px-3 py-1 bg-surface-3 border border-hairline-strong rounded-full text-ink-muted">
        Status: Aberto
      </span>
    </div>

    <!-- Messages Area -->
    <div ref="messagesContainer" class="flex-1 overflow-y-auto p-5 space-y-4 bg-canvas">
      <div v-if="loading" class="text-center py-10 text-ink-subtle text-sm">
        Carregando mensagens...
      </div>
      
      <div v-else-if="messages.length === 0" class="text-center py-10 text-ink-subtle text-sm italic">
        Envie os comprovantes (prints/vídeos) que comprovem sua vitória.
      </div>

      <div 
        v-for="msg in messages" 
        :key="msg.id"
        class="flex flex-col max-w-[80%]"
        :class="msg.sender_id === authStore.user?.id ? 'self-end items-end' : 'self-start items-start'"
      >
        <span class="text-[10px] text-ink-tertiary mb-1 px-1">
          {{ msg.sender?.username || 'Usuário' }}
        </span>
        
        <div 
          class="px-4 py-3 rounded-lg text-sm"
          :class="msg.sender_id === authStore.user?.id ? 'bg-primary text-on-primary rounded-tr-none' : 'bg-surface-2 text-ink border border-hairline rounded-tl-none'"
        >
          <p v-if="msg.message">{{ msg.message }}</p>
          
          <a v-if="msg.attachment_url" :href="msg.attachment_url" target="_blank" class="block mt-2">
            <img 
              v-if="msg.attachment_url.match(/\.(jpeg|jpg|gif|png)$/i)" 
              :src="msg.attachment_url" 
              class="max-w-full h-auto rounded-lg border border-hairline" 
            />
            <div v-else class="flex items-center gap-2 bg-black/20 p-2 rounded-lg text-caption font-bold">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
              </svg>
              Ver Anexo
            </div>
          </a>
        </div>
      </div>
    </div>

    <!-- Input Area -->
    <div class="p-4 bg-surface-2 border-t border-hairline">
      <form @submit.prevent="sendMessage()" class="flex items-end gap-3">
        
        <input 
          type="file" 
          ref="fileInput" 
          @change="handleFileUpload" 
          accept="image/*,video/mp4" 
          class="hidden" 
        />
        
        <button 
          type="button" 
          @click="fileInput?.click()"
          :disabled="uploading"
          class="p-3.5 bg-surface-3 hover:bg-surface-4 border border-hairline-strong rounded-lg text-ink-subtle hover:text-primary transition-colors disabled:opacity-50"
          title="Anexar Comprovante (Imagem/Vídeo)"
          aria-label="Anexar comprovante (imagem ou vídeo)"
        >
          <svg v-if="uploading" class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          <svg v-else class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
          </svg>
        </button>

        <textarea 
          v-model="newMessage"
          rows="1"
          placeholder="Escreva sua mensagem..."
          class="flex-1 bg-canvas border border-hairline rounded-lg px-4 py-3.5 text-ink placeholder-ink-tertiary focus:outline-none focus:border-primary transition-colors resize-none overflow-hidden"
          @keydown.enter.prevent="sendMessage()"
        ></textarea>

        <button
          type="submit"
          :disabled="sending || (!newMessage.trim())"
          aria-label="Enviar mensagem"
          class="bg-primary hover:bg-primary-hover text-on-primary font-semibold px-6 py-3.5 rounded-lg disabled:opacity-50 transition-colors flex items-center justify-center"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </button>
      </form>
    </div>
  </div>
</template>
