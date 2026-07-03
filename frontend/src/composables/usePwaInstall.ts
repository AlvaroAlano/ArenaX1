import { ref, computed, onMounted } from 'vue'

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

const deferredPrompt = ref<BeforeInstallPromptEvent | null>(null)
const isInstalled = ref(false)
const isIos = ref(false)

function checkStandalone() {
  const standalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as unknown as { standalone?: boolean }).standalone === true
  isInstalled.value = standalone
}

function handleBeforeInstallPrompt(event: Event) {
  event.preventDefault()
  deferredPrompt.value = event as BeforeInstallPromptEvent
}

function handleAppInstalled() {
  deferredPrompt.value = null
  isInstalled.value = true
}

let listenersAttached = false

export function usePwaInstall() {
  onMounted(() => {
    checkStandalone()
    isIos.value = /iphone|ipad|ipod/i.test(window.navigator.userAgent)

    if (!listenersAttached) {
      window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
      window.addEventListener('appinstalled', handleAppInstalled)
      listenersAttached = true
    }
  })

  const canInstall = computed(() => !isInstalled.value && deferredPrompt.value !== null)

  const install = async () => {
    if (!deferredPrompt.value) return
    await deferredPrompt.value.prompt()
    await deferredPrompt.value.userChoice
    deferredPrompt.value = null
  }

  return {
    deferredPrompt,
    isInstalled,
    isIos,
    canInstall,
    install,
  }
}
