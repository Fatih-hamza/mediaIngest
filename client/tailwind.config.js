module.exports = {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        'neon-green': '#10B981'
      },
      fontFamily: {
        inter: ['Inter', 'ui-sans-serif', 'system-ui'],
        'jetbrains': ['JetBrains Mono', 'ui-monospace']
      }
    }
  },
  plugins: []
}
