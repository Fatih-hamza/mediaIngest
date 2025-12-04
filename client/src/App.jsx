import React, { useEffect, useRef, useState } from 'react'
import { Zap, Terminal, Cpu } from 'lucide-react'

function StatusBadge({ syncing }) {
  return (
    <div className="flex items-center space-x-3">
      <div className={`w-4 h-4 rounded-full ${syncing ? 'bg-emerald-400 shadow-[0_0_12px_rgba(16,185,129,0.7)] animate-pulse' : 'bg-gray-500'} `} />
      <div className="text-sm font-semibold text-gray-200">{syncing ? 'Syncing' : 'Idle'}</div>
    </div>
  )
}

export default function App() {
  const [logs, setLogs] = useState('Loading logs...')
  const [syncing, setSyncing] = useState(false)
  const terminalRef = useRef(null)

  useEffect(() => {
    let mounted = true

    async function fetchOnce() {
      try {
        const [logsRes, statusRes] = await Promise.all([
          fetch('/api/logs'),
          fetch('/api/status')
        ])
        const logsJson = await logsRes.json()
        const statusJson = await statusRes.json()
        if (!mounted) return
        setLogs(typeof logsJson.logs === 'string' ? logsJson.logs : JSON.stringify(logsJson, null, 2))
        setSyncing(!!statusJson.syncing)
      } catch (e) {
        if (!mounted) return
        setLogs(prev => prev + '\n[error fetching] ' + e.message)
      }
    }

    fetchOnce()
    const id = setInterval(fetchOnce, 1000)
    return () => { mounted = false; clearInterval(id) }
  }, [])

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight
    }
  }, [logs])

  return (
    <div className="min-h-screen bg-slate-900 text-slate-200 font-inter p-6">
      <div className="max-w-6xl mx-auto">
        <header className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-4">
            <div className="p-3 rounded-lg bg-gradient-to-br from-slate-800/30 to-slate-800/10 backdrop-blur border border-slate-700/40">
              <Cpu className="text-emerald-400" />
            </div>
            <div>
              <h1 className="text-2xl font-extrabold tracking-tight">Universal Media Ingest</h1>
              <p className="text-xs text-slate-400">Home Lab USB ingest monitor</p>
            </div>
          </div>
          <div className="flex items-center space-x-6">
            <div className="px-4 py-2 rounded-xl glass">
              <StatusBadge syncing={syncing} />
            </div>
            <div className="text-slate-400 text-sm">Auto-refresh: 1s</div>
          </div>
        </header>

        <main>
          <section className="glass p-4 rounded-2xl border border-slate-700/30">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <Terminal className="text-slate-300" />
                <h2 className="text-sm font-semibold">Live Logs</h2>
              </div>
              <div className="text-xs text-slate-400">Showing last 200 lines</div>
            </div>

            <div ref={terminalRef} className="h-[60vh] overflow-y-auto bg-black text-green-200 text-sm font-jetbrains p-4 rounded-md border border-slate-800/60 shadow-[inset_0_0_30px_rgba(0,0,0,0.7)]">
              <pre className="whitespace-pre-wrap">{logs}</pre>
            </div>
          </section>
        </main>
      </div>
    </div>
  )
}
