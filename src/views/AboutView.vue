<script setup lang="ts">
const steps = [
  {
    title: 'Ambos reportam o resultado',
    description: 'Ao final da partida, criador e adversário acessam a sala e clicam em "Eu Venci" ou "Eu Perdi".'
  },
  {
    title: 'Os resultados são comparados',
    description: 'Se as duas declarações baterem, o sistema confirma a partida automaticamente.'
  },
  {
    title: 'Caminho feliz: pagamento na hora',
    description: 'O vencedor recebe o pote (descontado o rake da plataforma) imediatamente, sem precisar de suporte.'
  },
  {
    title: 'Divergência: abre-se mediação',
    description: 'Se os resultados não baterem, o pote fica retido e um chat de disputa é aberto para anexar provas.'
  }
]

const punishments = [
  'Reportes falsos comprovados resultam em perda total do valor apostado na partida.',
  'Reincidência leva a banimento permanente da plataforma.',
  'O Fair Play Rating do jogador cai a cada disputa perdida, afetando sua posição no ranking e a confiança de outros jogadores ao aceitar desafios.'
]
</script>

<template>
  <div class="flex-1 p-6 md:p-10 max-w-4xl mx-auto w-full space-y-12">

    <div>
      <span class="text-eyebrow text-primary uppercase tracking-widest mb-3 block">Como Funciona</span>
      <h1 class="text-display-md font-display font-semibold tracking-tight text-ink mb-3">Regras da Arena</h1>
      <p class="text-body-lg text-ink-subtle leading-relaxed">
        Entenda como funciona o duplo check de resultados, o que acontece em caso de disputa e como acionar o suporte.
      </p>
    </div>

    <section>
      <h2 class="text-headline font-display font-semibold text-ink mb-6">O Duplo Check</h2>
      <div class="space-y-4">
        <div
          v-for="(step, index) in steps"
          :key="step.title"
          class="bg-surface-1 border border-hairline rounded-lg p-6 flex gap-5"
        >
          <span class="text-card-title font-display font-semibold text-ink-tertiary shrink-0">
            {{ String(index + 1).padStart(2, '0') }}
          </span>
          <div>
            <h3 class="text-card-title font-display font-medium text-ink mb-1">{{ step.title }}</h3>
            <p class="text-body-sm text-ink-subtle leading-relaxed">{{ step.description }}</p>
          </div>
        </div>
      </div>
    </section>

    <section>
      <h2 class="text-headline font-display font-semibold text-ink mb-6">Punições por Fraude</h2>
      <div class="bg-surface-1 border border-hairline rounded-lg p-6">
        <ul class="space-y-3">
          <li v-for="item in punishments" :key="item" class="flex gap-3 text-body-sm text-ink-subtle leading-relaxed">
            <span class="text-semantic-danger shrink-0">&bull;</span>
            {{ item }}
          </li>
        </ul>
      </div>
    </section>

    <section class="bg-surface-1 border border-hairline rounded-lg p-8 text-center">
      <h2 class="text-card-title font-display font-medium text-ink mb-2">Precisa de ajuda em uma disputa?</h2>
      <p class="text-body-sm text-ink-subtle max-w-md mx-auto mb-6">
        Abra o desafio em disputa e use o chat de mediação para anexar prints ou vídeos comprovando o resultado real.
      </p>
      <router-link
        to="/challenges"
        class="inline-block bg-primary hover:bg-primary-hover text-on-primary px-6 py-3 rounded-md text-button font-medium transition-colors"
      >
        Ir para Meus Desafios
      </router-link>
    </section>

  </div>
</template>
