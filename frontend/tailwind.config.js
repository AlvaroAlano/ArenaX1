/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Rebrand 2026-07: verde-limão neon como cor única de marca (mono-lime),
        // fundo cinza-escuro (NÃO preto absoluto). Ver design-direction memory.
        // Botões preenchidos com `primary` usam texto ESCURO (text-canvas), nunca branco.
        primary: "#C8F03C", // Verde-limão — cor principal (CTAs, destaques)
        "primary-hover": "#DAFB60",
        "primary-focus": "#aad42f", // Limão mais fechado — fim de gradiente / pressed
        accent: "#C8F03C", // Mesmo limão — esquema mono
        "accent-hover": "#DAFB60",
        "accent-soft": "#dbf87a",
        "brand-green": "#059669",
        "background-light": "#f5f7f8",
        "background-dark": "#15181e", // Cinza-escuro (= canvas)
        "admin-sidebar": "#101319",
        "admin-card": "#21252e",
        canvas: "#15181e", // Cinza-escuro neutro-frio (base — não preto absoluto)
        "surface-1": "#1b1f26", // Bandas de seção alternadas (um passo acima do canvas)
        "surface-2": "#21252e", // Cards
        "surface-3": "#282d37",
        "surface-4": "#2f353f",
        hairline: "#323844",
        "hairline-strong": "#3f4651",
        "hairline-tertiary": "#4b525e",
        ink: "#f2f5f7",
        "ink-muted": "#d3d8de",
        "ink-subtle": "#969ba3",
        "ink-tertiary": "#666c76",
        "semantic-success": "#27a644",
        "semantic-error": "#ef4444",
        // Aliases de limão mantidos (LandingViewV2 os usava; agora == primary/accent)
        lime: "#C8F03C",
        "lime-hover": "#DAFB60",
        "lime-soft": "rgba(200, 240, 60, 0.14)",
      },
      fontFamily: {
        sans: ["Inter", "SF Pro Display", "system-ui", "sans-serif"],
        display: ["Archivo", "sans-serif"], // Títulos — geométrica, uppercase peso 900
        archivo: ["Archivo", "sans-serif"],
        mono: ["JetBrains Mono", "ui-monospace", "SF Mono", "monospace"],
      },
      fontSize: {
        "display-xl": ["80px", { lineHeight: "1.05", letterSpacing: "-3.0px", fontWeight: "600" }],
        "display-lg": ["56px", { lineHeight: "1.10", letterSpacing: "-1.8px", fontWeight: "600" }],
        "display-md": ["40px", { lineHeight: "1.15", letterSpacing: "-1.0px", fontWeight: "600" }],
        headline: ["28px", { lineHeight: "1.20", letterSpacing: "-0.6px", fontWeight: "600" }],
        "card-title": ["22px", { lineHeight: "1.25", letterSpacing: "-0.4px", fontWeight: "500" }],
        subhead: ["20px", { lineHeight: "1.40", letterSpacing: "-0.2px", fontWeight: "400" }],
        "body-lg": ["18px", { lineHeight: "1.50", letterSpacing: "-0.1px", fontWeight: "400" }],
        body: ["16px", { lineHeight: "1.50", letterSpacing: "-0.05px", fontWeight: "400" }],
        "body-sm": ["14px", { lineHeight: "1.50", letterSpacing: "0", fontWeight: "400" }],
        caption: ["12px", { lineHeight: "1.40", letterSpacing: "0", fontWeight: "400" }],
        button: ["14px", { lineHeight: "1.20", letterSpacing: "0", fontWeight: "500" }],
        eyebrow: ["13px", { lineHeight: "1.30", letterSpacing: "0.4px", fontWeight: "500" }],
      },
      spacing: {
        xxs: "4px",
        xs: "8px",
        sm: "12px",
        md: "16px",
        lg: "24px",
        xl: "32px",
        xxl: "48px",
        section: "96px",
      },
      borderRadius: {
        xs: "4px",
        sm: "6px",
        md: "8px",
        lg: "12px",
        xl: "16px",
        xxl: "24px",
        pill: "9999px",
      },
      boxShadow: {
        "glow-primary": "0 0 40px -8px rgba(200, 240, 60, 0.45)",
        "glow-accent": "0 0 40px -8px rgba(200, 240, 60, 0.45)",
        "card-premium": "0 24px 60px -24px rgba(0, 0, 0, 0.7)",
      },
      backgroundImage: {
        "radial-fade": "radial-gradient(closest-side, var(--tw-gradient-stops))",
      },
    },
  },
  plugins: [],
}
