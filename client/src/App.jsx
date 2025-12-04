import React, { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Zap, Activity, Check, Loader2 } from 'lucide-react'

// Log Parser - Extracts transfer data from rsync output
function parseLogData(logLines) {
  const current = { filename: null, progress: 0, speed: null, timeRemaining: null }
  const completed = []
  
  for (let i = 0; i < logLines.length; i++) {
    const line = logLines[i].trim()
    
    // Match progress line: "1.80G 100% 65.71MB/s 0:00:26"
    const progressMatch = line.match(/^([\d.]+[KMGT]?)\s+(\d+)%\s+([\d.]+[KMGT]?B\/s)\s+(\d+:\d+:\d+)/)
    
    if (progressMatch) {
      const progress = parseInt(progressMatch[2])
      const speed = progressMatch[3]
      const timeRemaining = progressMatch[4]
      
      // Look backwards for the filename (previous non-empty line)
      let filename = null
      for (let j = i - 1; j >= 0; j--) {
        const prevLine = logLines[j].trim()
        if (prevLine && !prevLine.match(/^([\d.]+[KMGT]?)\s+(\d+)%/) && !prevLine.includes('Syncing')) {
          filename = prevLine
          break
        }
      }
      
      if (progress === 100 && filename) {
        // Completed file
        if (!completed.find(f => f.filename === filename)) {
          completed.push({ filename, speed, timestamp: Date.now() })
        }
      } else if (progress < 100 && filename) {
        // Currently transferring
        current.filename = filename
        current.progress = progress
        current.speed = speed
        current.timeRemaining = timeRemaining
      }
    }
  }
  
  return { current, completed: completed.slice(-5) }
}

function StatusBadge({ active }) {
  return (
    <div className="flex items-center space-x-3">
      <motion.div 
        className={`w-3 h-3 rounded-full ${active ? 'bg-orange-400' : 'bg-emerald-400'}`}
        animate={active ? { 
          scale: [1, 1.3, 1],
          opacity: [1, 0.7, 1]
        } : {}}
        transition={{ duration: 1.5, repeat: Infinity }}
      />
      <div className="text-sm font-semibold">
        {active ? (
          <span className="text-orange-300">Ingesting Data...</span>
        ) : (
          <span className="text-emerald-300">System Ready</span>
        )}
      </div>
    </div>
  )
}

function HeroCard({ current, active }) {
  const hasTransfer = current.filename && active
  
  return (
    <motion.div 
      className="relative overflow-hidden rounded-3xl p-8 glass-card border border-slate-700/50"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
    >
      {/* Gradient glow effect */}
      <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/10 via-purple-500/10 to-pink-500/10 blur-xl" />
      
      <div className="relative z-10">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-3 rounded-xl bg-gradient-to-br from-cyan-500/20 to-purple-500/20 backdrop-blur">
              <Activity className="w-6 h-6 text-cyan-400" />
            </div>
            <div>
              <h2 className="text-sm text-slate-400 font-medium">Current Transfer</h2>
              <p className="text-xs text-slate-500">Live Progress Monitor</p>
            </div>
          </div>
          <StatusBadge active={active} />
        </div>

        <AnimatePresence mode="wait">
          {hasTransfer ? (
            <motion.div
              key="transfer"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            >
              {/* Filename */}
              <div className="mb-4">
                <div className="text-2xl font-bold text-slate-100 truncate">
                  {current.filename}
                </div>
              </div>

              {/* Progress Bar */}
              <div className="mb-6">
                <div className="flex justify-between text-xs text-slate-400 mb-2">
                  <span>Progress</span>
                  <span className="text-cyan-400 font-semibold">{current.progress}%</span>
                </div>
                <div className="h-4 bg-slate-800/50 rounded-full overflow-hidden border border-slate-700/50">
                  <motion.div
                    className="h-full bg-gradient-to-r from-cyan-500 via-purple-500 to-pink-500 shadow-[0_0_20px_rgba(6,182,212,0.5)]"
                    initial={{ width: 0 }}
                    animate={{ width: `${current.progress}%` }}
                    transition={{ duration: 0.5, ease: "easeOut" }}
                  />
                </div>
              </div>

              {/* Speed & Time */}
              <div className="grid grid-cols-2 gap-4">
                <div className="p-4 rounded-xl bg-slate-800/30 border border-slate-700/30">
                  <div className="text-xs text-slate-400 mb-1">Transfer Speed</div>
                  <div className="text-2xl font-bold text-cyan-400">{current.speed}</div>
                </div>
                <div className="p-4 rounded-xl bg-slate-800/30 border border-slate-700/30">
                  <div className="text-xs text-slate-400 mb-1">Time Remaining</div>
                  <div className="text-2xl font-bold text-purple-400">{current.timeRemaining}</div>
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div
              key="idle"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="text-center py-12"
            >
              <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-gradient-to-br from-emerald-500/20 to-cyan-500/20 flex items-center justify-center">
                <Zap className="w-8 h-8 text-emerald-400" />
              </div>
              <h3 className="text-xl font-semibold text-slate-300 mb-2">No Active Transfers</h3>
              <p className="text-sm text-slate-500">Waiting for media ingest to begin...</p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </motion.div>
  )
}

function HistoryList({ completed }) {
  return (
    <motion.div
      className="rounded-2xl p-6 glass-card border border-slate-700/50"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.1 }}
    >
      <div className="flex items-center gap-2 mb-4">
        <Check className="w-5 h-5 text-emerald-400" />
        <h3 className="text-lg font-semibold text-slate-200">Recently Completed</h3>
        <span className="text-xs text-slate-500 ml-auto">{completed.length} files</span>
      </div>

      <div className="space-y-2">
        <AnimatePresence>
          {completed.length === 0 ? (
            <div className="text-center py-8 text-slate-500 text-sm">
              No completed transfers yet
            </div>
          ) : (
            completed.map((file, idx) => (
              <motion.div
                key={file.filename + idx}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                transition={{ delay: idx * 0.05 }}
                className="flex items-center gap-3 p-3 rounded-lg bg-slate-800/30 border border-slate-700/30 hover:border-emerald-500/30 transition-colors"
              >
                <div className="w-8 h-8 rounded-full bg-emerald-500/20 flex items-center justify-center flex-shrink-0">
                  <Check className="w-4 h-4 text-emerald-400" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm text-slate-200 truncate">{file.filename}</div>
                  <div className="text-xs text-slate-500">Avg. {file.speed}</div>
                </div>
              </motion.div>
            ))
          )}
        </AnimatePresence>
      </div>
    </motion.div>
  )
}

export default function App() {
  const [active, setActive] = useState(false)
  const [current, setCurrent] = useState({ filename: null, progress: 0, speed: null, timeRemaining: null })
  const [completed, setCompleted] = useState([])

  useEffect(() => {
    let mounted = true

    async function poll() {
      try {
        const [statusRes, activeRes] = await Promise.all([
          fetch('/api/status'),
          fetch('/api/active')
        ])
        
        const statusData = await statusRes.json()
        const activeData = await activeRes.json()
        
        if (!mounted) return
        
        if (statusData.ok && Array.isArray(statusData.logs)) {
          const parsed = parseLogData(statusData.logs)
          setCurrent(parsed.current)
          setCompleted(parsed.completed)
        }
        
        if (activeData.ok) {
          setActive(activeData.active)
        }
      } catch (e) {
        console.error('Polling error:', e)
      }
    }

    poll()
    const interval = setInterval(poll, 500)
    return () => { mounted = false; clearInterval(interval) }
  }, [])

  return (
    <div className="min-h-screen bg-slate-900 text-slate-200 p-6">
      {/* Background gradients */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl" />
      </div>

      <div className="max-w-5xl mx-auto relative z-10">
        {/* Header */}
        <motion.header 
          className="mb-8"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-extrabold bg-gradient-to-r from-cyan-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
                Universal Media Ingest
              </h1>
              <p className="text-sm text-slate-500 mt-1">High-Performance Transfer Monitor</p>
            </div>
            <div className="text-xs text-slate-600">
              <Loader2 className="w-4 h-4 inline animate-spin mr-1" />
              Auto-refresh: 500ms
            </div>
          </div>
        </motion.header>

        {/* Hero Card */}
        <div className="mb-6">
          <HeroCard current={current} active={active} />
        </div>

        {/* History */}
        <HistoryList completed={completed} />
      </div>
    </div>
  )
}
