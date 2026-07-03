export function prefersReduce(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

/**
 * Diretiva de scroll-reveal via IntersectionObserver.
 * Uso: v-reveal ou v-reveal="'120ms'" para escalonar (stagger) entradas.
 */
export const vReveal = {
  mounted(el: HTMLElement, binding: { value?: string }) {
    if (prefersReduce()) {
      el.classList.add('is-visible')
      return
    }
    el.classList.add('reveal')
    if (binding.value) el.style.transitionDelay = binding.value
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((en) => {
          if (en.isIntersecting) {
            el.classList.add('is-visible')
            io.unobserve(el)
          }
        })
      },
      { threshold: 0.12, rootMargin: '0px 0px -8% 0px' },
    )
    io.observe(el)
  },
}
