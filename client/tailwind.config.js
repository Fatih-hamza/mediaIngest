module.exports = {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        'neon-cyan': '#06b6d4',
        'neon-purple': '#a855f7',
        'neon-pink': '#ec4899'
      },
      fontFamily: {
        inter: ['Inter', 'ui-sans-serif', 'system-ui'],
        'jetbrains': ['JetBrains Mono', 'ui-monospace']
      },
      backgroundImage: {
        'cyber-gradient': 'linear-gradient(135deg, rgba(6,182,212,0.1) 0%, rgba(168,85,247,0.1) 50%, rgba(236,72,153,0.1) 100%)'
      },
      boxShadow: {
        'glow-cyan': '0 0 20px rgba(6,182,212,0.5)',
        'glow-purple': '0 0 20px rgba(168,85,247,0.5)',
        'glow-pink': '0 0 20px rgba(236,72,153,0.5)'
      }
    }
  },
  plugins: []
}
