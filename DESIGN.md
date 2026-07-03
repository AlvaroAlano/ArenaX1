# Documentação de Design: Landing Page "Network"

## 1. Visão Geral (Overview)
A landing page apresenta um design moderno, arrojado e focado no nicho de tecnologia, criptomoedas e fintechs (Web3/Crypto aesthetic). O layout utiliza o estilo **Dark Mode** como base, contrastando com elementos geométricos claros e uma cor de destaque vibrante (laranja/vermelho) para guiar a atenção do usuário. O design faz uso intenso de tipografia expressiva, incorporando ícones e "badges" (pílulas) diretamente no meio do texto (inline styling), criando uma leitura dinâmica e não linear.

## 2. Paleta de Cores
O esquema de cores é intencionalmente restrito para maximizar o contraste e o impacto visual:
* **Fundo Principal (Background):** Preto / Cinza muito escuro (Aprox. `#111111` ou `#1A1A1A`). Cria profundidade e um visual premium.
* **Cor de Destaque (Accent):** Laranja Vibrante / Vermelho Alaranjado (Aprox. `#FF5A36`). Usado em botões principais, ícones de destaque, textos enfatizados (como a palavra "crypto") e nos brilhos de fundo (glow effects).
* **Texto Principal:** Branco sólido (`#FFFFFF`) para títulos (H1, H2) garantindo legibilidade máxima contra o fundo escuro.
* **Texto Secundário / Labels:** Cinza claro/médio (Aprox. `#A0A0A0`). Usado para descrições, métricas e navegação, criando uma hierarquia visual onde não competem com os títulos principais.
* **Fundo Secundário (Cards):** Cinza muito claro / Off-white (Aprox. `#F2F2F2` a `#EAEAEA`). Utilizado nos cards da seção de "Features", criando um contraste fortíssimo e destacando as ilustrações.

## 3. Tipografia
* **Família Tipográfica:** Uma fonte Sans-Serif geométrica e moderna (similar a Inter, Helvetica Neue ou Roobert). Ela possui excelente legibilidade tanto em tamanhos muito pequenos (micro-copy) quanto em tamanhos gigantes.
* **Hierarquia e Comportamento:**
    * **Hero (H1):** Texto massivo e centralizado. O diferencial aqui é a quebra de padrão: inserção de ícones (como o raio) no meio das frases e o uso de cores de destaque em palavras específicas ("crypto" e "fintech").
    * **Títulos de Seção (H2):** Seguem o mesmo conceito do H1, misturando texto em branco com componentes UI embutidos (ex: botões e ícones laranjas que substituem palavras ou servem de pontuação).
    * **Corpo de Texto (Body) e Micro-copy:** Letras menores, em cinza. Há o uso de *uppercase* (caixa alta) com espaçamento entre letras (tracking) para pequenas tags ou sub-títulos (ex: "SHARE IT").

## 4. Estrutura de Layout e Componentes (Sections Breakdown)

### 4.1 Header (Navegação Superior)
* **Layout:** Disposto em linha horizontal, fixado no topo, com divisórias muito sutis (linhas finas cinzas) separando os elementos.
* **Logo (Esquerda):** "* Network".
* **Menu (Centro):** Links de navegação simples ("About", "Products", "Solutions", "Company") em cinza.
* **Ações (Direita):** Exibe a data atual ("Friday, June 16, 2023") e um botão de ação secundário "Log in >" com uma seta discreta.

### 4.2 Hero Section (Primeira Dobra)
* **Foco Visual:** Uma grande esfera com um gradiente/brilho suave em tons de vermelho/laranja escuro ao fundo do texto principal, dando um efeito de luz emanando do centro.
* **Top Label:** Texto pequeno, centralizado, explicando o propósito: "AI-powered system suggests...".
* **Headline:** "Next level of ⚡ crypto and # fintech product".
* **Métricas (Flancos):** Nas laterais extremas do texto central, há dados de prova social alinhados simetricamente:
    * Esquerda: "93m+ Total locked" | "3.2b Market size"
    * Direita: "1k+ Awards" | "221k Transactions"
    * Há botões redondos de setas (esquerda e direita) nas extremidades, sugerindo que este painel ou os dados podem ser um carrossel.
* **Bottom Widget:** Abaixo do título, há um painel interativo/informativo com um grande botão laranja ("The logo of the largest bubble company..."). Ele funciona como um *Call to Action* ou uma notificação de destaque.

### 4.3 Section 01: About & Features
* **Cabeçalho da Seção:** Inicia com o número "01" e uma "tag" em formato de pílula branca com texto escuro indicando o tema: "About * Network".
* **Título H2 Inline:** "Our team [ícone laranja] has been creating ⚡ a unique and powerful crypto and fintech product for [tag 'Network'] 5 years. A team of 20+ [ícone pessoa] people". Uma abordagem de design onde imagens e texto coexistem na mesma linha.
* **Cards de Funcionalidades (Grid de 3 colunas):**
    * **Card 1 (Esquerda):** "Constant monitoring". Fundo claro, ilustrando formas geométricas laranjas (representando domínio e website).
    * **Card 2 (Centro):** "AI-based detection". Fundo claro, apresentando um ícone de chapéu (incógnito) e um asterisco vermelho com a tag "Scam detected!". Acima dele, há um mini-card laranja sobreposto com o texto "SHARE IT".
    * **Card 3 (Direita):** "Automatic triage". Fundo claro, exibindo pílulas 3D rotuladas como "Threat" sendo neutralizadas em torno de um asterisco central.
    * **Estilo dos Cards:** Formatos com cantos muito arredondados (*border-radius* alto), fundo em tons de off-white, ilustrações abstratas e minimalistas, seguidos pelo título em branco e descrição em cinza abaixo de cada card.

### 4.4 Section 02: Investors
* **Cabeçalho da Seção:** Segue o padrão da seção anterior, com "02" e a tag "Investors of * Network".
* **Título:** "Our investors of * Network project".
* **Carrossel de Logos:** Uma linha horizontal com logos dos investidores.
    * A maioria dos logos está contida em círculos escuros com ícones brancos.
    * **Destaque:** Um investidor específico ("SLICE") está evidenciado com um círculo laranja muito maior, quebrando a simetria de forma proposital para chamar a atenção. Outro logo ("Petal") aparece em formato de texto.
    * Setas de navegação nas pontas esquerda e direita indicam um carrossel horizontal contínuo.

## 5. Elementos Visuais e Constantes (Design System)
1.  **Botões e Badges (Pills):** O uso de componentes em formato de "pílula" (bordas totalmente arredondadas) é constante. Eles aparecem como botões laranja, tags de categorização brancas e selos embutidos nos textos.
2.  **Uso de Símbolos:** O asterisco (`*`) atua como o logotipo primário ou elemento central da identidade da marca (presente no nome, nas ilustrações dos cards e nos ícones). O raio (`⚡`) é usado para remeter à velocidade/energia.
3.  **Contraste Extremo:** A escolha de colocar cards quase brancos em um fundo quase preto cria uma área de "respiro" visual inverso. Onde o normal seria escurecer cards, o designer optou por iluminá-los, o que prende a atenção instantaneamente para os recursos (features) do produto.
4.  **Bordas e Linhas:** Linhas separadoras são usadas de forma extremamente sutil (1px, com baixa opacidade) para delimitar o header, o carrossel e certas métricas, garantindo que o design não fique poluído.
