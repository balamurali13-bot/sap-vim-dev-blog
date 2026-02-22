/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: 'var(--bg-primary)',
        secondary: 'var(--bg-secondary)',
        card: 'var(--bg-card)',
        code: 'var(--bg-code)',
        nav: 'var(--bg-nav)',
        text: {
          primary: 'var(--text-primary)',
          secondary: 'var(--text-secondary)',
          tertiary: 'var(--text-tertiary)',
        },
        accent: {
          DEFAULT: 'var(--accent)',
          hover: 'var(--accent-hover)',
          subtle: 'var(--accent-subtle)',
        },
        border: {
          DEFAULT: 'var(--border)',
          hover: 'var(--border-hover)',
        },
        tag: {
          bg: 'var(--tag-bg)',
          text: 'var(--tag-text)',
        },
        gradient: {
          start: '#2563eb',
          end: '#9333ea',
        },
        dark: {
          primary: 'var(--bg-primary)',
          secondary: 'var(--bg-secondary)',
          card: 'var(--bg-card)',
          code: 'var(--bg-code)',
          nav: 'var(--bg-nav)',
          accent: '#60a5fa',
          'accent-subtle': 'rgba(37,99,235,0.1)',
          'tag-bg': '#1e293b',
          'tag-text': '#94a3b8',
          border: '#1e293b',
        },
      },
      fontFamily: {
        sans: ['DM Sans', '-apple-system', 'sans-serif'],
        serif: ['Source Serif 4', 'Georgia', 'serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      fontSize: {
        base: '1rem',
      },
    },
  },
  plugins: [],
}
