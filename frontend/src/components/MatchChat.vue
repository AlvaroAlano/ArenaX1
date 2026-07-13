<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { MessageCircle, Send } from '@lucide/vue'

const props = defineProps<{
  challengeId: string
}>()

const authStore = useAuthStore()
const toast = useToastStore()

const messages = ref<any[]>([])
const newMessage = ref('')
const loading = ref(true)
const sending = ref(false)

let realtimeSub: any = null
const messagesContainer = ref<HTMLElement | null>(null)

const loadMessages = async () => {
  try {
    const { data, error } = await supabase
      .from('challenge_messages')
      .select('*, sender:sender_id(username)')
      .eq('challenge_id', props.challengeId)
      .order('created_at', { ascending: true })

    if (error) throw error
    messages.value = data || []
    scrollToBottom()
  } catch (err) {
    console.error('Erro ao buscar mensagens da partida:', err)
  } finally {
    loading.value = false
  }
}

// Evita duplicar quando o realtime ecoa uma mensagem que já está na lista
// (ex.: a própria mensagem que acabei de inserir de forma otimista).
const pushUnique = (msg: any) => {
  if (msg?.id && messages.value.some((m) => m.id === msg.id)) return
  messages.value.push(msg)
  scrollToBottom()
}

const sendMessage = async () => {
  if (!newMessage.value.trim()) return
  const body = newMessage.value.trim()

  sending.value = true
  try {
    // .select() retorna a linha inserida pra append IMEDIATO — o usuário vê a
    // própria mensagem na hora, sem depender do round-trip do realtime.
    const { data, error } = await supabase
      .from('challenge_messages')
      .insert({ challenge_id: props.challengeId, sender_id: authStore.user?.id, message: body })
      .select('*, sender:sender_id(username)')
      .single()

    if (error) throw error
    newMessage.value = ''
    pushUnique(data)
  } catch (err) {
    console.error('Erro ao enviar mensagem:', err)
    toast.push('Erro ao enviar mensagem.', 'error')
  } finally {
    sending.value = false
  }
}

const setupRealtime = () => {
  realtimeSub = supabase
    .channel(`challenge-chat-${props.challengeId}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'challenge_messages', filter: `challenge_id=eq.${props.challengeId}` },
      async (payload) => {
        if (messages.value.some((m) => m.id === payload.new.id)) return
        const { data: userData } = await supabase
          .from('profiles')
          .select('username')
          .eq('id', payload.new.sender_id)
          .single()

        pushUnique({ ...payload.new, sender: userData })
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
  await loadMessages()
  setupRealtime()
})

onUnmounted(() => {
  if (realtimeSub) supabase.removeChannel(realtimeSub)
})
</script>

<template>
  <div class="flex h-[420px] flex-col overflow-hidden rounded-2xl border border-hairline bg-surface-1">

    <!-- Header -->
    <div class="flex items-center gap-2 border-b border-hairline bg-surface-2 p-4">
      <span class="grid size-8 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
        <MessageCircle :size="16" />
      </span>
      <div>
        <h3 class="text-body-sm font-bold uppercase tracking-wider text-ink">Chat da partida</h3>
        <p class="text-caption text-ink-tertiary">Combine sala, horário e regras com o adversário.</p>
      </div>
    </div>

    <!-- Mensagens -->
    <div ref="messagesContainer" class="flex-1 space-y-3 overflow-y-auto bg-canvas p-4">
      <div v-if="loading" class="py-8 text-center text-body-sm text-ink-subtle">Carregando conversa...</div>

      <div v-else-if="messages.length === 0" class="flex flex-col items-center gap-2 py-10 text-center">
        <MessageCircle :size="24" class="text-ink-tertiary" />
        <p class="text-body-sm text-ink-subtle">Nenhuma mensagem ainda. Chama o adversário pra combinar a partida.</p>
      </div>

      <div
        v-for="msg in messages"
        :key="msg.id"
        class="flex max-w-[80%] flex-col"
        :class="msg.sender_id === authStore.user?.id ? 'ml-auto items-end' : 'items-start'"
      >
        <span class="mb-1 px-1 text-[10px] text-ink-tertiary">{{ msg.sender?.username || 'Jogador' }}</span>
        <div
          class="rounded-lg px-4 py-2.5 text-body-sm"
          :class="msg.sender_id === authStore.user?.id ? 'rounded-tr-none bg-primary text-canvas' : 'rounded-tl-none border border-hairline bg-surface-2 text-ink'"
        >
          {{ msg.message }}
        </div>
      </div>
    </div>

    <!-- Enviar -->
    <form @submit.prevent="sendMessage" class="flex items-end gap-2 border-t border-hairline bg-surface-2 p-3">
      <input
        v-model="newMessage"
        type="text"
        placeholder="Escreva uma mensagem..."
        maxlength="500"
        class="h-11 flex-1 rounded-lg border border-hairline bg-canvas px-4 text-body-sm text-ink placeholder-ink-tertiary outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary"
      />
      <button
        type="submit"
        :disabled="sending || !newMessage.trim()"
        class="grid size-11 shrink-0 place-items-center rounded-lg bg-primary text-canvas transition-all hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50"
      >
        <svg v-if="sending" class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
        </svg>
        <Send v-else :size="17" />
      </button>
    </form>
  </div>
</template>
