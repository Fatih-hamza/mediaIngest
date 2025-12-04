import React, { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { HardDrive, Activity, CheckCircle, Zap, Clock, Database } from 'lucide-react'

function StatusBadge({ active }) {
  return (
    <div className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-slate-800 border border-slate-700">
      <motion.div 
        className={`w-2 h-2 rounded-full ${active ? 'bg-emerald-500' : 'bg-slate-500'}`}
        animate={active ? { 
          scale: [1, 1.2, 1],
          opacity: [1, 0.8, 1]
        } : {}}
        transition={{ duration: 2, repeat: Infinity }}
      />
      <span className="text-xs font-medium uppercase tracking-wide text-slate-300">
        {active ? 'Active' : 'Idle'}
      </span>
    </div>
  )
}

function HeroCard({ active, current }) {
  const hasTransfer = active && current.filename
  
  return (
    <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
          Active Transfer
        </h2>
        <Activity className={`w-4 h-4 ${active ? 'text-blue-400' : 'text-slate-600'}`} />
      </div>

      {hasTransfer ? (
        <div>
          {/* Filename */}
          <div className="mb-6">
            <h3 className="text-2xl font-bold text-white mb-1 truncate">
              {current.filename}
            </h3>
            <p className="text-sm text-slate-500">Media file ingest in progress</p>
          </div>

          {/* Progress Bar */}
          <div className="mb-6">
            <div className="flex justify-between items-center mb-2">
              <span className="text-xs uppercase tracking-wide text-slate-400">Progress</span>
              <span className="text-sm font-bold text-blue-400">{current.progress}%</span>
            </div>
            <div className="h-2 bg-slate-900 rounded-full overflow-hidden">
              <motion.div
                className="h-full bg-blue-500"
                initial={{ width: 0 }}
                animate={{ width: `${current.progress}%` }}
                transition={{ duration: 0.5, ease: "easeOut" }}
              />
            </div>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-3 gap-4">
            <div className="bg-slate-900 rounded-md p-4 border border-slate-800">
              <div className="text-xs uppercase tracking-wide text-slate-500 mb-1">Speed</div>
              <div className="text-xl font-bold text-white">{current.speed || '--'}</div>
            </div>
            <div className="bg-slate-900 rounded-md p-4 border border-slate-800">
              <div className="text-xs uppercase tracking-wide text-slate-500 mb-1">Size</div>
              <div className="text-xl font-bold text-white">
                {current.size ? `${current.size}` : '--'}
              </div>
            </div>
            <div className="bg-slate-900 rounded-md p-4 border border-slate-800">
              <div className="text-xs uppercase tracking-wide text-slate-500 mb-1">ETA</div>
              <div className="text-xl font-bold text-white">{current.timeRemaining || '--'}</div>
            </div>
          </div>
        </div>
      ) : (
        <div className="text-center py-12">
          <HardDrive className="w-12 h-12 text-slate-700 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-slate-400 mb-1">Waiting for Drive...</h3>
          <p className="text-sm text-slate-600">Connect a USB device to begin transfer</p>
        </div>
      )}
    </div>
  )
}

function DriveInfoCard() {
  return (
    <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
          Device Info
        </h2>
        <Database className="w-4 h-4 text-slate-600" />
      </div>

      <div className="space-y-4">
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500 mb-1">Label</div>
          <div className="text-sm font-medium text-white">USB Storage Device</div>
        </div>
        
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500 mb-1">Mount Point</div>
          <div className="text-sm font-mono text-slate-300">/media/usb-ingest</div>
        </div>
        
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500 mb-1">File System</div>
          <div className="text-sm font-medium text-slate-300">NTFS (ntfs3 driver)</div>
        </div>

        <div className="pt-4 border-t border-slate-700">
          <div className="flex items-center gap-2">
            <CheckCircle className="w-4 h-4 text-emerald-500" />
            <span className="text-xs text-slate-400">Device Ready</span>
          </div>
        </div>
      </div>
    </div>
  )
}

function HistoryCard({ completed }) {
  return (
    <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
          Recent Transfers
        </h2>
        <span className="text-xs text-slate-600">{completed.length} completed</span>
      </div>

      {completed.length === 0 ? (
        <div className="text-center py-8 text-slate-600 text-sm">
          No completed transfers yet
        </div>
      ) : (
        <div className="space-y-2">
          {completed.map((file, idx) => (
            <motion.div
              key={file.filename + idx}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.05 }}
              className="flex items-center gap-3 p-3 bg-slate-900 rounded-md border border-slate-800 hover:border-slate-700 transition-colors"
            >
              <CheckCircle className="w-4 h-4 text-emerald-500 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-white truncate">{file.filename}</div>
                <div className="text-xs text-slate-500">
                  {file.size && <span className="mr-3">{file.size}</span>}
                  <span>Avg. {file.speed}</span>
                </div>
              </div>
              <Clock className="w-3 h-3 text-slate-600" />
            </motion.div>
          ))}
        </div>
      )}
    </div>
  )
}

// Log Parser - Extracts transfer data from rsync output
function parseLogData(logLines) {
  const current = { filename: null, progress: 0, speed: null, timeRemaining: null, size: null }
  const completed = []
  let currentFilename = null
  
  for (let i = 0; i < logLines.length; i++) {
    const line = logLines[i].trim()
    
    const progressMatch = line.match(/([\d.]+[KMGT]?)\s+(\d+)%\s+([\d.]+[KMGT]?B\/s)\s+(\d+:\d+:\d+)/)
    
    if (progressMatch) {
      const size = progressMatch[1]
      const progress = parseInt(progressMatch[2])
      const speed = progressMatch[3]
      const timeRemaining = progressMatch[4]
      
      if (!currentFilename) {
        for (let j = i - 1; j >= 0; j--) {
          const prevLine = logLines[j].trim()
          if (prevLine && (
            prevLine.match(/\.(mp4|mkv|avi|mov|m4v|webm)$/i) ||
            prevLine.match(/\.(srt|txt|jpg|png)$/i)
          )) {
            currentFilename = prevLine.replace(/^.*\//, '')
            break
          }
        }
      }
      
      if (progress === 100 && currentFilename && currentFilename.match(/\.(mp4|mkv|avi|mov|m4v|webm)$/i)) {
        if (!completed.find(f => f.filename === currentFilename)) {
          completed.push({ filename: currentFilename, speed, size, timestamp: Date.now() })
        }
        currentFilename = null
      } else if (progress < 100 && currentFilename) {
        current.filename = currentFilename
        current.progress = progress
        current.speed = speed
        current.timeRemaining = timeRemaining
        current.size = size
      }
    } else if (line.match(/\.(mp4|mkv|avi|mov|m4v|webm)$/i)) {
      currentFilename = line.replace(/^.*\//, '')
    } else if (line.includes('Ingest Complete') || line.includes('sent ') || line.includes('bytes/sec')) {
      currentFilename = null
      if (current.progress === 100) {
        current.filename = null
        current.progress = 0
      }
    }
  }
  
  return { current, completed: completed.slice(-5).reverse() }
}

export default function App() {
  const [active, setActive] = useState(false)
  const [current, setCurrent] = useState({ filename: null, progress: 0, speed: null, timeRemaining: null, size: null })
  const [completed, setCompleted] = useState([])
  const [uptime, setUptime] = useState('00:00:00')

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
    
    // Uptime counter
    const startTime = Date.now()
    const uptimeInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000)
      const hours = Math.floor(elapsed / 3600).toString().padStart(2, '0')
      const minutes = Math.floor((elapsed % 3600) / 60).toString().padStart(2, '0')
      const seconds = (elapsed % 60).toString().padStart(2, '0')
      setUptime(`${hours}:${minutes}:${seconds}`)
    }, 1000)
    
    return () => { 
      mounted = false
      clearInterval(interval)
      clearInterval(uptimeInterval)
    }
  }, [])

  return (
    <div className="min-h-screen bg-slate-900 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <header className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-slate-800 rounded-lg border border-slate-700 flex items-center justify-center">
              <Zap className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-white">Media Ingest Node</h1>
              <p className="text-xs text-slate-500">USB Transfer Monitor</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <div className="text-right">
              <div className="text-xs uppercase tracking-wide text-slate-500">Uptime</div>
              <div className="text-sm font-mono text-slate-300">{uptime}</div>
            </div>
            <StatusBadge active={active} />
          </div>
        </header>

        {/* Main Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Hero Card - spans 2 columns */}
          <div className="lg:col-span-2">
            <HeroCard active={active} current={current} />
          </div>

          {/* Drive Info Card */}
          <div>
            <DriveInfoCard />
          </div>

          {/* History Card - full width */}
          <div className="lg:col-span-3">
            <HistoryCard completed={completed} />
          </div>
        </div>
      </div>
    </div>
  )
}
