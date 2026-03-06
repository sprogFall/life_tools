import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eff6ff',
          100: '#dbeafe',
          500: '#3b82f6',
          700: '#1d4ed8',
          900: '#1e3a8a',
        },
        accent: '#f59e0b',
        ink: '#0f172a',
        mist: '#f8fafc',
      },
      boxShadow: {
        panel: '0 24px 48px -24px rgba(15, 23, 42, 0.28)',
      },
      backgroundImage: {
        shell: 'radial-gradient(circle at top right, rgba(59,130,246,0.16), transparent 28%), radial-gradient(circle at top left, rgba(245,158,11,0.12), transparent 20%)',
      },
      borderRadius: {
        '4xl': '2rem',
      },
    },
  },
  plugins: [],
};

export default config;
