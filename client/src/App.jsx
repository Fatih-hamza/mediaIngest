import React, { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { HardDrive, Activity, CheckCircle, Film, Tv, Database, Zap } from 'lucide-react'

function StatusBadge({ active }) {
  return (
    <div className="flex items-center gap-2">
      <motion.div 
        className={`w-2.5 h-2.5 rounded-full ${active ? 'bg-blue-500' : 'bg-emerald-500'}`}
        animate={active ? { 
          scale: [1, 1.3, 1],
          opacity: [1, 0.7, 1]
        } : {
          scale: [1, 1.2, 1],
          opacity: [1, 0.8, 1]
        }}
        transition={{ duration: 2, repeat: Infinity }}
      />
      <span className="text-sm font-medium text-slate-300">
        {active ? 'Syncing' : 'Ready'}
      </span>
    </div>
  )
}

function HeroCard({ active, current }) {
  const hasTransfer = active && current.filename
  
  return (
    <div className="bg-slate-900/50 backdrop-blur border border-slate-800 rounded-xl p-6 lg:col-span-2">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
          Active Transfer
        </h2>
        <Activity className={`w-4 h-4 ${active ? 'text-blue-400 animate-pulse' : 'text-slate-700'}`} />
      </div>

      {hasTransfer ? (
        <div>
          <div className="mb-5">
            <h3 className="text-3xl font-bold text-white mb-2 truncate">
              {current.filename}
            </h3>
            <p className="text-sm text-slate-500">Media file transfer in progress</p>
          </div>

          {/* Progress Bar */}
          <div className="mb-6">
            <div className="flex justify-between items-center mb-2">
              <span className="text-xs uppercase tracking-wide text-slate-500">Progress</span>
              <span className="text-lg font-bold text-blue-400">{current.progress}%</span>
            </div>
            <div className="h-3 bg-slate-950 rounded-full overflow-hidden border border-slate-800">
              <motion.div
                className="h-full bg-gradient-to-r from-blue-600 to-blue-500"
                animate={{ width: `${current.progress}%` }}
                transition={{ duration: 0.1, ease: "linear" }}
              />
            </div>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-3 gap-3">
            <div className="bg-slate-950/50 rounded-lg p-4 border border-slate-800/50">
              <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Speed</div>
              <div className="text-xl font-bold text-white">{current.speed || '--'}</div>
            </div>
            <div className="bg-slate-950/50 rounded-lg p-4 border border-slate-800/50">
              <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Size</div>
              <div className="text-xl font-bold text-white">{current.size || '--'}</div>
            </div>
            <div className="bg-slate-950/50 rounded-lg p-4 border border-slate-800/50">
              <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">ETA</div>
              <div className="text-xl font-bold text-white">{current.timeRemaining || '--'}</div>
            </div>
          </div>
        </div>
      ) : (
        <div className="text-center py-16">
          <motion.div
            animate={{ 
              scale: [1, 1.05, 1],
              opacity: [0.5, 0.7, 0.5]
            }}
            transition={{ duration: 3, repeat: Infinity }}
          >
            <HardDrive className="w-16 h-16 text-slate-800 mx-auto mb-4" />
          </motion.div>
          <h3 className="text-xl font-semibold text-slate-400 mb-2">System Ready</h3>
          <p className="text-sm text-slate-600">Waiting for USB drive connection...</p>
        </div>
      )}
    </div>
  )
}

function DeviceCard() {
  return (
    <div className="bg-slate-900/50 backdrop-blur border border-slate-800 rounded-xl p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
          USB Device
        </h2>
        <Database className="w-4 h-4 text-slate-700" />
      </div>

      <div className="space-y-4">
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Device</div>
          <div className="text-sm font-medium text-white">Samsung T7 Shield</div>
        </div>
        
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Mount</div>
          <div className="text-xs font-mono text-slate-400">/media/usb-ingest</div>
        </div>
        
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">FS Type</div>
          <div className="text-sm font-medium text-slate-400">NTFS (ntfs3)</div>
        </div>

        <div className="pt-3 border-t border-slate-800">
          <div className="flex items-center gap-2">
            <CheckCircle className="w-4 h-4 text-emerald-500" />
            <span className="text-xs text-slate-500">Ready</span>
          </div>
        </div>
      </div>
    </div>
  )
}

function StatsCard({ stats }) {
  const lastActiveText = stats.lastActive 
    ? new Date(stats.lastActive).toLocaleString()
    : 'Never';
    
  return (
    <div className="bg-slate-900/50 backdrop-blur border border-slate-800 rounded-xl p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
          Statistics
        </h2>
        <Zap className="w-4 h-4 text-slate-700" />
      </div>

      <div className="space-y-4">
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Total Files</div>
          <div className="text-3xl font-bold text-white">{stats.totalFiles || 0}</div>
        </div>
        
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Total Data</div>
          <div className="text-2xl font-bold text-blue-400">{stats.totalGB || '0.00'} GB</div>
        </div>
        
        <div className="pt-3 border-t border-slate-800">
          <div className="text-xs uppercase tracking-wide text-slate-600 mb-1">Last Active</div>
          <div className="text-xs text-slate-400">{lastActiveText}</div>
        </div>
      </div>
    </div>
  )
}

function HistoryCard({ history }) {
  return (
    <div className="bg-slate-900/50 backdrop-blur border border-slate-800 rounded-xl p-6 lg:col-span-3">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
          Transfer History
        </h2>
        <span className="text-xs text-slate-600">{history.length} recent</span>
      </div>

      {history.length === 0 ? (
        <div className="text-center py-12 text-slate-600 text-sm">
          No transfer history yet
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-800">
                <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-600">Type</th>
                <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-600">Filename</th>
                <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-600">Size</th>
                <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-600">Time</th>
                <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-600">Status</th>
              </tr>
            </thead>
            <tbody>
              {history.map((item, idx) => (
                <motion.tr
                  key={item.filename + item.timestamp}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: idx * 0.03 }}
                  className="border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors"
                >
                  <td className="py-3 px-4">
                    {item.type === 'Movie' ? (
                      <Film className="w-4 h-4 text-blue-400" />
                    ) : (
                      <Tv className="w-4 h-4 text-purple-400" />
                    )}
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-sm font-medium text-white truncate max-w-md">
                      {item.filename}
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-sm text-slate-400">{item.size}</div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-xs text-slate-500">
                      {new Date(item.timestamp).toLocaleTimeString()}
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <CheckCircle className="w-4 h-4 text-emerald-500" />
                  </td>
                </motion.tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default function App() {
  const [active, setActive] = useState(false)
  const [current, setCurrent] = useState({ filename: null, progress: 0, speed: null, timeRemaining: null, size: null })
  const [history, setHistory] = useState([])
  const [stats, setStats] = useState({ totalFiles: 0, totalGB: '0.00', lastActive: null })

  useEffect(() => {
    let mounted = true

    async function poll() {
      try {
        const [statusRes, historyRes, statsRes] = await Promise.all([
          fetch('/api/status'),
          fetch('/api/history'),
          fetch('/api/stats')
        ])
        
        const statusData = await statusRes.json()
        const historyData = await historyRes.json()
        const statsData = await statsRes.json()
        
        if (!mounted) return
        
        if (statusData.ok) {
          setActive(statusData.active)
          setCurrent(statusData.current || { filename: null, progress: 0, speed: null, timeRemaining: null, size: null })
        }
        
        if (historyData.ok) {
          setHistory(historyData.history || [])
        }
        
        if (statsData.ok) {
          setStats(statsData.stats)
        }
      } catch (e) {
        console.error('Polling error:', e)
      }
    }

    poll()
    const interval = setInterval(poll, 500) // Poll every 500ms for faster updates
    
    return () => { 
      mounted = false
      clearInterval(interval)
    }
  }, [])

  return (
    <div className="min-h-screen bg-slate-950 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <header className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-slate-900 rounded-lg border border-slate-800 flex items-center justify-center">
              <HardDrive className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">Media Ingest System</h1>
              <p className="text-xs text-slate-600">Real-time monitoring & history</p>
            </div>
          </div>
          <StatusBadge active={active} />
        </header>

        {/* Bento Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          {/* Hero Card - spans 2 columns */}
          <HeroCard active={active} current={current} />

          {/* Device Card */}
          <DeviceCard />

          {/* Stats Card */}
          <StatsCard stats={stats} />

          {/* History Card - full width */}
          <HistoryCard history={history} />
        </div>
      </div>
    </div>
  )
}
