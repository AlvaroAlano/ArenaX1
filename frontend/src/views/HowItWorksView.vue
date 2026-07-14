<script setup lang="ts">
import { Wallet, Gamepad2, Camera, Banknote, Hourglass, Gavel, WifiOff, ShieldCheck } from '@lucide/vue'
import FaqAccordion from '@/components/ui/FaqAccordion.vue'

/* Respostas ancoradas no termos-de-uso.md (Seções 1.3-A, 2, 5, 6, 9, 11.2) e
   em regras-do-sistema.md (rake, prazos, divisão de premiação, Fair Play,
   contador de abandono) — sem números ou regras que não estejam documentados
   em algum dos dois. */
const faqs = [
  {
    q: 'O que é a ArenaX1?',
    a: 'Uma plataforma brasileira de desafios e torneios de futebol virtual (EA FC e eFootball). Você desafia outro jogador num X1 valendo dinheiro de verdade, joga a partida no seu console ou PC e, se vencer, o pote cai direto na sua carteira.',
  },
  {
    q: 'Isso é aposta ou jogo de azar?',
    a: 'Não. A ArenaX1 é uma competição baseada 100% em habilidade: não operamos cassino, não sorteamos prêmios e não intermediamos apostas sobre eventos esportivos de terceiros. O que você recebe ao final de um desafio é consequência direta do seu próprio desempenho na partida que você mesmo jogou — nunca de sorte, aleatoriedade ou resultado alheio.',
  },
  {
    q: 'Como funciona um desafio 1v1?',
    a: 'Você cria um desafio (ou aceita um aberto) definindo jogo, plataforma e valor. Formada a dupla, o valor dos dois lados fica travado em custódia. Vocês combinam a sala pelo chat da partida, jogam no próprio jogo e cada um reporta o resultado na plataforma. Batendo os dois relatos, o vencedor recebe o pote imediatamente, descontada a comissão da plataforma.',
  },
  {
    q: 'Como sei que não vou ser passado pra trás no resultado?',
    a: 'Três camadas de proteção: o valor fica travado em custódia até o resultado sair; os dois jogadores precisam reportar o placar (duplo check); e é obrigatório registrar foto ou vídeo do placar final. Se os relatos divergirem, a partida entra em mediação e nossa equipe decide com base nas provas apresentadas. Quem reporta resultado falso perde reputação e pode ser banido.',
  },
  {
    q: 'Quanto tempo demora pra sacar?',
    a: 'O saque é feito via Pix para uma chave cadastrada no seu próprio CPF, sem taxa de saque. O tempo de processamento pode variar conforme o horário e a análise antifraude — como medida de segurança, podemos confirmar a titularidade da chave antes de liberar o valor.',
  },
  {
    q: 'Sou menor de idade, posso jogar?',
    a: 'Não. A ArenaX1 é restrita a maiores de 18 anos, sem exceção, com verificação de identidade obrigatória — a simples declaração de maioridade não é aceita. Contas identificadas como pertencentes a menores são imediatamente suspensas e encerradas.',
  },
  {
    q: 'A ArenaX1 tem vínculo com a EA ou a Konami?',
    a: 'Não. A ArenaX1 não é endossada, patrocinada ou afiliada à Electronic Arts, Konami, Sony, Microsoft ou Valve. EA Sports FC, eFootball, PlayStation, Xbox e Steam são marcas dos seus respectivos titulares — nós organizamos a competição entre os jogadores, sem qualquer vínculo comercial com essas empresas.',
  },
  {
    q: 'O que acontece se o adversário sumir sem reportar o resultado?',
    a: 'Se só você reportar, o resultado informado é aceito automaticamente após o prazo de 24 horas. O valor fica retido por 3 dias antes de se tornar sacável — a janela em que o outro jogador ainda pode contestar. Quem some repetidamente acumula registro de ausência na reputação.',
  },
  {
    q: 'Como funcionam os torneios?',
    a: 'Os torneios online pagos são mata-mata de 4, 8 ou 16 jogadores: a chave é sorteada quando as vagas fecham e a premiação é distribuída sobre o total arrecadado em inscrições, descontada a comissão da plataforma. Cada confronto segue as mesmas regras de reporte e mediação do X1. Também existe o Torneio de Sofá, 100% grátis, pra jogar com os amigos — só o anfitrião precisa de conta.',
  },
  {
    q: 'Existem "odds" ou multiplicadores que a plataforma define?',
    a: 'Não. O valor que você pode ganhar ou perder é fixo e conhecido antes de aceitar o desafio — a ArenaX1 não define probabilidades, cotações ou multiplicadores variáveis por jogador ou por partida. Não existe uma "casa" fixando odds contra você: o resultado é só entre você e seu adversário.',
  },
  {
    q: 'Qual o valor mínimo pra depositar e pra criar um desafio?',
    a: 'O depósito mínimo via Pix é R$ 10,00. Já o valor mínimo de um desafio 1v1 é R$ 1,00 — a interface sugere atalhos de R$ 5, 10, 20 ou 50, mas dá pra digitar outro valor dentro do permitido.',
  },
  {
    q: 'Como é dividida a premiação nos torneios pagos?',
    a: 'Depende do número de vagas: com 4 jogadores, o campeão leva 100% do pote; com 8, a divisão é 55% para o 1º lugar, 30% para o 2º e 15% para o 3º; com 16, é 50% / 25% / 15% / 10% para os quatro primeiros colocados — sempre sobre o valor líquido, já descontada a comissão da plataforma.',
  },
  {
    q: 'Posso ter mais de uma conta?',
    a: 'Não. Cada CPF pode estar associado a apenas uma conta na plataforma — é uma regra antifraude, já que múltiplas contas poderiam ser usadas pra manipular resultados entre si.',
  },
  {
    q: 'O que é a nota de Fair Play e como ela funciona?',
    a: 'É a sua reputação de conduta na plataforma, numa escala de 0 a 5 que começa em 5,0. Ela só cai quando uma mediação comprova má conduta — mentir sobre o resultado, trapacear ou se comportar mal — nunca por silêncio ou por não reportar a tempo, que é considerado comportamento passivo, não falta de conduta.',
  },
  {
    q: 'O que é o selo de "histórico de abandono" no perfil?',
    a: 'É um indicador separado da nota de Fair Play, que conta quantas vezes você aceitou um desafio e não confirmou presença a tempo. Ele só fica visível no seu perfil público depois de acumular 3 ausências, e você é avisado com 48h de antecedência pra contestar antes da publicação, caso tenha tido um motivo justo.',
  },
  {
    q: 'Quanto tempo tenho pra confirmar presença depois que meu desafio é aceito?',
    a: 'Quinze minutos. Depois que o oponente é escolhido, os dois precisam clicar em "Iniciar partida" dentro desse prazo. Se alguém não confirmar, o desafio é cancelado, o valor de ambos é devolvido integralmente e só quem não confirmou recebe uma marcação no contador de ausência — nunca uma penalidade financeira.',
  },
  {
    q: 'Posso cancelar um desafio que eu criei?',
    a: 'Sim, mas só enquanto ele ainda estiver aberto, sem nenhum oponente escolhido, com devolução integral do valor reservado. Depois que alguém é selecionado pra jogar contra você, o desafio segue o fluxo normal até o resultado ou até o prazo de confirmação vencer.',
  },
  {
    q: 'Em quais plataformas dá pra jogar?',
    a: 'PS5, Xbox e PC — incluindo desafios Crossplay, pra encontrar adversário em qualquer plataforma, jogando EA FC 25, EA FC 26 ou eFootball.',
  },
  {
    q: 'Posso desativar ou excluir minha conta?',
    a: 'Sim, existem dois caminhos. Desativar é reversível e instantâneo: sua conta some das listagens públicas, mas nada é apagado e basta fazer login de novo pra reativar. Excluir é definitivo: primeiro é preciso sacar qualquer saldo livre disponível, depois há uma carência de 30 dias — logar novamente dentro desse prazo cancela o pedido automaticamente.',
  },
]
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
                  Crie a sua conta na ArenaX1 em poucos segundos. Adicione fundos à sua carteira de forma instantânea e segura para começar a disputar partidas e provar sua habilidade.
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

    <div class="space-y-8">
        <h2 class="border-b border-hairline pb-4 font-display text-headline font-bold text-ink">Perguntas Frequentes</h2>
        <div class="grid gap-10 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)] lg:gap-14">
            <div class="space-y-4">
                <p class="text-body-lg leading-relaxed text-ink-subtle">
                  Respostas diretas sobre dinheiro, segurança e regras — sem letra miúda.
                </p>
                <p class="text-body-sm text-ink-tertiary">
                  Ainda ficou com dúvida? Fale com a gente pelo canal de
                  <router-link to="/support" class="font-semibold text-primary hover:text-primary-hover">suporte</router-link>
                  ou confira os
                  <router-link to="/termos" class="font-semibold text-primary hover:text-primary-hover">Termos de Uso</router-link>.
                </p>
            </div>
            <FaqAccordion :items="faqs" />
        </div>
    </div>

  </div>
</template>
