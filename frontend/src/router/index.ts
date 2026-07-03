import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import LandingView from '../views/LandingView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  scrollBehavior(to) {
    if (to.hash) {
      return { el: to.hash, behavior: 'smooth' }
    }
    return { top: 0 }
  },
  routes: [
    {
      path: '/',
      component: () => import('../layouts/PublicLayout.vue'),
      children: [
        {
          path: '',
          name: 'landing',
          component: () => import('../views/LandingViewV2.vue')
        },
        {
          // Landing antiga (azul/Lexend) mantida como backup pós-rebrand
          path: 'landing-classic',
          name: 'landing-classic',
          component: LandingView
        },
        {
          path: 'desafios',
          name: 'public-challenges',
          component: () => import('../views/ChallengesView.vue')
        },
        {
          path: 'torneios',
          name: 'public-tournaments',
          component: () => import('../views/TournamentsView.vue')
        },
        {
          path: 'torneios/:id',
          name: 'public-tournament-details',
          component: () => import('../views/TournamentDetailsView.vue')
        },
        {
          path: 'classificacao',
          name: 'public-ranking',
          component: () => import('../views/RankingView.vue')
        },
        {
          path: 'como-funciona',
          name: 'how-it-works',
          component: () => import('../views/HowItWorksView.vue')
        }
      ]
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/LoginView.vue')
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('../views/RegisterView.vue')
    },
    {
      path: '/about',
      name: 'about',
      component: () => import('../views/AboutView.vue')
    },
    {
      path: '/auth-layout',
      component: () => import('../layouts/DashboardLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '/dashboard',
          name: 'dashboard',
          component: () => import('../views/HomeView.vue')
        },
        {
          path: '/wallet',
          name: 'wallet',
          component: () => import('../views/WalletView.vue')
        },
        {
          path: '/settings',
          name: 'settings',
          component: () => import('../views/SettingsView.vue')
        },
        {
          // A tela antiga de saque (PayPal, mock) foi substituída pela aba
          // "Sacar" dentro da Carteira, que já fala com o Pix de verdade.
          path: '/withdraw',
          redirect: { path: '/wallet', query: { tab: 'withdraw' } }
        },
        {
          path: '/challenges',
          name: 'challenges',
          component: () => import('../views/ChallengesView.vue')
        },
        {
          path: '/tournaments',
          name: 'tournaments',
          component: () => import('../views/TournamentsView.vue')
        },
        {
          path: '/tournaments/:id',
          name: 'tournament-details',
          component: () => import('../views/TournamentDetailsView.vue')
        },
        {
          path: '/create-challenge',
          name: 'create-challenge',
          component: () => import('../views/CreateChallengeView.vue')
        },
        {
          path: '/create-tournament',
          name: 'create-tournament',
          component: () => import('../views/CreateTournamentView.vue')
        },
        {
          path: '/my-tournaments/:id',
          name: 'tournament-bracket',
          component: () => import('../views/TournamentBracketView.vue'),
          props: true
        },
        {
          path: '/ranking',
          name: 'ranking',
          component: () => import('../views/RankingView.vue')
        },
        {
          // Substitui o menu sanduíche no mobile: mesmo conteúdo da DashboardSidebar,
          // como tela própria em vez de painel deslizante. Acessada pelo botão "Menu"
          // do DashboardBottomNav (no lugar do antigo atalho "Carteira").
          path: '/menu',
          name: 'menu',
          component: () => import('../views/MenuView.vue')
        },
        {
          path: '/match/:id',
          name: 'match',
          component: () => import('../views/MatchView.vue'),
          props: true
        }
      ]
    }
  ]
})

router.beforeEach(async (to) => {
  const authStore = useAuthStore()

  if (authStore.loading) {
    await authStore.fetchSession()
  }

  const isAuthenticated = authStore.user !== null

  if (to.meta.requiresAuth && !isAuthenticated) {
    return '/login'
  }
  if ((to.name === 'login' || to.name === 'register') && isAuthenticated) {
    return '/dashboard'
  }
  return true
})

export default router

