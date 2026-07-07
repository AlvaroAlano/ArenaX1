import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router'

// Após um novo deploy, abas já abertas podem referenciar chunks JS que não
// existem mais no servidor (hash mudou), causando "Failed to fetch dynamically
// imported module". Nesse caso, recarrega a página uma vez para pegar a versão
// atual em vez de deixar o usuário travado numa tela quebrada.
function reloadOnce(reason: string) {
  const key = 'arenax1:reloaded-after-chunk-error'
  if (sessionStorage.getItem(key)) return
  sessionStorage.setItem(key, reason)
  window.location.reload()
}

window.addEventListener('vite:preloadError', () => {
  reloadOnce('vite:preloadError')
})

router.onError((error) => {
  if (/Failed to fetch dynamically imported module|Importing a module script failed/i.test(error.message)) {
    reloadOnce('router:chunk-load-failed')
  }
})

const app = createApp(App)

app.use(createPinia())
app.use(router)

app.mount('#app')
