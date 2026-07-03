<script setup lang="ts">
import { Wallet, Gamepad2, Camera, Banknote, Hourglass, Gavel, WifiOff, ShieldCheck } from '@lucide/vue'
</script>

<template>
  <div class="space-y-20 px-6 py-16 lg:px-20">

    <div class="mx-auto max-w-2xl space-y-4 text-center">
        <h1 class="font-display text-display-md font-bold text-ink">Como Funciona a ArenaX1</h1>
        <p class="text-body-lg leading-relaxed text-ink-subtle">
          O ambiente mais seguro para partidas competitivas. Descubra como nosso sistema protege seu dinheiro através da validação rigorosa de resultados.
        </p>
    </div>

    <div class="space-y-8">
        <h2 class="border-b border-hairline pb-4 font-display text-headline font-bold text-ink">O Passo a Passo</h2>
        <div class="grid grid-cols-1 gap-6 md:grid-cols-2">

            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-8 backdrop-blur">
                <div class="mb-6 flex size-14 items-center justify-center rounded-xl border border-primary/20 bg-primary/10 text-primary">
                    <Wallet :size="24" />
                </div>
                <h3 class="mb-3 text-xl font-bold text-ink">1. Criar Conta e Depositar</h3>
                <p class="text-body-sm leading-relaxed text-ink-subtle">
                  Crie a sua conta na ArenaX1 em poucos segundos. Adicione fundos à sua carteira de forma instantânea e segura para começar a apostar nas suas habilidades.
                </p>
            </div>

            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-8 backdrop-blur">
                <div class="mb-6 flex size-14 items-center justify-center rounded-xl border border-primary/20 bg-primary/10 text-primary">
                    <Gamepad2 :size="24" />
                </div>
                <h3 class="mb-3 text-xl font-bold text-ink">2. O Desafio</h3>
                <p class="text-body-sm leading-relaxed text-ink-subtle">
                  Explore os desafios ativos ou crie o seu próprio. Quando um adversário aceita, o dinheiro de ambos é retido de forma segura pelo nosso sistema de custódia.
                </p>
            </div>

            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-8 backdrop-blur">
                <div class="mb-6 flex size-14 items-center justify-center rounded-xl border border-primary/20 bg-primary/10 text-primary">
                    <Camera :size="24" />
                </div>
                <h3 class="mb-3 text-xl font-bold text-ink">3. Jogar e Provar</h3>
                <p class="text-body-sm leading-relaxed text-ink-subtle">
                  Joguem a partida no console ou PC. Ao final, <strong class="text-ink">é obrigatório tirar uma foto ou gravar um clipe do placar final</strong>. Ambos reportam o resultado na plataforma anexando a prova.
                </p>
            </div>

            <div class="rounded-2xl border border-hairline bg-surface-1/60 p-8 backdrop-blur">
                <div class="mb-6 flex size-14 items-center justify-center rounded-xl border border-primary/20 bg-primary/10 text-primary">
                    <Banknote :size="24" />
                </div>
                <h3 class="mb-3 text-xl font-bold text-ink">4. Saque Instantâneo</h3>
                <p class="text-body-sm leading-relaxed text-ink-subtle">
                  Resultados confirmados? O vencedor recebe o pote imediatamente. Solicite o saque do seu saldo para a sua conta a qualquer momento.
                </p>
            </div>
        </div>
    </div>

    <div class="space-y-8">
        <h2 class="border-b border-hairline pb-4 font-display text-headline font-bold text-ink">Regras de Validação e Punições</h2>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">

            <div class="flex gap-4 rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <Hourglass :size="24" class="shrink-0 text-accent" />
                <div>
                    <h5 class="mb-1 font-bold text-ink">Omissão de Resultado (Ghosting)</h5>
                    <p class="text-caption text-ink-subtle">
                      Se você ganhou, enviou a foto do placar, e o perdedor "sumiu" e não reportou, não se preocupe. Após um tempo limite, você é declarado vencedor. O perdedor omisso perde pontos de reputação e sofre punições severas no sistema.
                    </p>
                </div>
            </div>

            <div class="flex gap-4 rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <Gavel :size="24" class="shrink-0 text-semantic-error" />
                <div>
                    <h5 class="mb-1 font-bold text-ink">Disputas (Resultados Divergentes)</h5>
                    <p class="text-caption text-ink-subtle">
                      Ambos disseram que ganharam? O pote fica congelado e a nossa moderação entra em ação. O jogador que não apresentar a foto/vídeo nítida do placar com as IDs perderá o valor e a conta poderá ser banida por fraude.
                    </p>
                </div>
            </div>

            <div class="flex gap-4 rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <WifiOff :size="24" class="shrink-0 text-semantic-error" />
                <div>
                    <h5 class="mb-1 font-bold text-ink">Desconexões e Rage Quit</h5>
                    <p class="text-caption text-ink-subtle">
                      O adversário quitou a partida? Grave a tela do console ou PC imediatamente mostrando a desconexão e envie como prova. Sair da partida de propósito resulta em derrota automática (forfait).
                    </p>
                </div>
            </div>

            <div class="flex gap-4 rounded-2xl border border-hairline bg-surface-1/60 p-6 backdrop-blur">
                <ShieldCheck :size="24" class="shrink-0 text-semantic-success" />
                <div>
                    <h5 class="mb-1 font-bold text-ink">O Ônus da Prova</h5>
                    <p class="text-caption text-ink-subtle">
                      A regra de ouro da ArenaX1 é: <strong class="text-ink">sem prova, não há vitória</strong>. Acostume-se a sempre capturar a tela final ou gravar os últimos 30 segundos pelo sistema do seu console para garantir seus lucros.
                    </p>
                </div>
            </div>

        </div>
    </div>

  </div>
</template>
