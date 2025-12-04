module.exports = {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        slate: {
          850: '#1a202e',
          950: '#0a0f1a'
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'Courier New', 'monospace']
      },
      backdropBlur: {
        xs: '2px'
      }
    }
  },
  plugins: []
}
