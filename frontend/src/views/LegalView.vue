<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'
import termosRaw from '../../../termos-de-uso.md?raw'
import privacidadeRaw from '../../../politica-de-privacidade.md?raw'

/* Página institucional que renderiza os documentos legais da raiz do repo
   (fonte única de verdade — nada de copiar o texto pra dentro do app).
   O conteúdo é nosso e estático (?raw resolvido em build), então v-html
   aqui não abre superfície de XSS. */
const props = defineProps<{ doc: 'termos' | 'privacidade' }>()

const sources: Record<typeof props.doc, string> = {
  termos: termosRaw,
  privacidade: privacidadeRaw,
}

const html = computed(() => {
  const src = sources[props.doc]
    // Links cruzados entre os .md viram rotas do app
    .replace(/\(politica-de-privacidade\.md\)/g, '(/privacidade)')
    .replace(/\(termos-de-uso\.md\)/g, '(/termos)')
  return marked.parse(src, { async: false })
})
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 py-14 lg:py-20">
    <article class="legal-prose" v-html="html"></article>
  </div>
</template>

<style scoped>
/* Tipografia dos documentos legais (v-html não recebe classes utilitárias,
   então o "prose" é definido aqui com os tokens do design system). */
.legal-prose {
  color: #969ba3; /* ink-subtle */
  font-size: 15px;
  line-height: 1.7;
}

.legal-prose :deep(h1) {
  font-family: 'Archivo', sans-serif;
  font-size: 32px;
  font-weight: 900;
  letter-spacing: -0.6px;
  line-height: 1.15;
  color: #f2f5f7; /* ink */
  margin: 0 0 24px;
}

.legal-prose :deep(h2) {
  font-family: 'Archivo', sans-serif;
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.3px;
  color: #f2f5f7;
  border-bottom: 1px solid #323844; /* hairline */
  padding-bottom: 10px;
  margin: 40px 0 16px;
}

.legal-prose :deep(h3) {
  font-size: 16px;
  font-weight: 700;
  color: #d3d8de; /* ink-muted */
  margin: 28px 0 12px;
}

.legal-prose :deep(p) {
  margin: 0 0 14px;
}

.legal-prose :deep(strong) {
  color: #d3d8de;
  font-weight: 600;
}

.legal-prose :deep(a) {
  color: #c8f03c; /* primary */
  text-decoration: underline;
  text-underline-offset: 3px;
}

.legal-prose :deep(a:hover) {
  color: #dafb60; /* primary-hover */
}

.legal-prose :deep(ul),
.legal-prose :deep(ol) {
  margin: 0 0 14px;
  padding-left: 22px;
}

.legal-prose :deep(li) {
  margin-bottom: 6px;
}

.legal-prose :deep(blockquote) {
  margin: 0 0 24px;
  padding: 14px 18px;
  border-left: 3px solid rgba(200, 240, 60, 0.5);
  border-radius: 0 12px 12px 0;
  background: #1b1f26; /* surface-1 */
  color: #d3d8de;
}

.legal-prose :deep(blockquote p) {
  margin-bottom: 8px;
}

.legal-prose :deep(blockquote p:last-child) {
  margin-bottom: 0;
}

.legal-prose :deep(hr) {
  border: none;
  border-top: 1px solid #323844;
  margin: 32px 0;
}

.legal-prose :deep(code) {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 13px;
  background: #21252e; /* surface-2 */
  border: 1px solid #323844;
  border-radius: 4px;
  padding: 1px 5px;
  color: #d3d8de;
}

.legal-prose :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 20px;
  font-size: 14px;
}

.legal-prose :deep(th),
.legal-prose :deep(td) {
  border: 1px solid #323844;
  padding: 8px 12px;
  text-align: left;
}

.legal-prose :deep(th) {
  color: #f2f5f7;
  background: #1b1f26;
}
</style>
