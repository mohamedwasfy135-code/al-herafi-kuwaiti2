'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { useLanguage } from '@/lib/language-context'
import { offlineQueue } from '@/lib/offline-queue'
import { Wifi, WifiOff, RefreshCw, CheckCircle2, AlertCircle, CloudOff } from 'lucide-react'
import { toast } from 'sonner'

type SyncStatus = 'idle' | 'syncing' | 'synced' | 'failed'

export function OnlineStatus() {
  const { t } = useLanguage()
  const [isOnline, setIsOnline] = useState(navigator.onLine)
  const [pendingCount, setPendingCount] = useState(0)
  const [syncStatus, setSyncStatus] = useState<SyncStatus>('idle')
  const syncTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const tRef = useRef(t)

  // Keep tRef in sync with latest t value
  useEffect(() => {
    tRef.current = t
  }, [t])

  const refreshPendingCount = useCallback(async () => {
    try {
      const count = await offlineQueue.getCount()
      setPendingCount(count)
      setSyncStatus((prev) => {
        if (count === 0 && prev !== 'syncing') return 'idle'
        return prev
      })
    } catch {
      // IndexedDB may not be available
    }
  }, [])

  const handleSync = useCallback(async () => {
    if (!navigator.onLine) return
    setSyncStatus('syncing')
    try {
      const result = await offlineQueue.replayAll()
      await refreshPendingCount()
      if (result.success > 0) {
        setSyncStatus('synced')
        toast.success(tRef.current('offline_sync_complete'), {
          description: `${result.success} ${tRef.current('offline_synced_items')}`,
          duration: 3000,
        })
      }
      if (result.failed > 0) {
        setSyncStatus('failed')
        toast.error(tRef.current('offline_sync_failed'), {
          description: `${result.failed} ${tRef.current('offline_sync_failed_items')}`,
          duration: 4000,
        })
      }
      if (result.success === 0 && result.failed === 0) {
        setSyncStatus('idle')
      }
      if (syncTimeoutRef.current) clearTimeout(syncTimeoutRef.current)
      syncTimeoutRef.current = setTimeout(() => {
        setSyncStatus((prev) => (prev === 'synced' ? 'idle' : prev))
      }, 5000)
    } catch {
      setSyncStatus('failed')
    }
  }, [refreshPendingCount])

  // Setup online/offline event listeners
  useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true)
      toast.success(tRef.current('offline_back_online'), { duration: 3000 })
      // Trigger sync when coming back online (via callback, not setState in effect body)
      offlineQueue.replayAll().then((result) => {
        if (result.success > 0 || result.failed > 0) {
          refreshPendingCount()
          if (result.success > 0) {
            setSyncStatus('synced')
            toast.success(tRef.current('offline_sync_complete'), {
              description: `${result.success} ${tRef.current('offline_synced_items')}`,
              duration: 3000,
            })
          }
          if (result.failed > 0) {
            setSyncStatus('failed')
          }
        }
      })
    }

    const handleOffline = () => {
      setIsOnline(false)
      setSyncStatus('idle')
    }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [refreshPendingCount])

  // Listen for service worker messages
  useEffect(() => {
    if (!('serviceWorker' in navigator)) return

    const handleMessage = (event: MessageEvent) => {
      const data = event.data
      if (!data?.type) return

      switch (data.type) {
        case 'SYNC_START':
          setSyncStatus('syncing')
          break
        case 'SYNC_COMPLETE':
          if (data.failed > 0) {
            setSyncStatus('failed')
          } else {
            setSyncStatus('synced')
          }
          refreshPendingCount()
          if (syncTimeoutRef.current) clearTimeout(syncTimeoutRef.current)
          syncTimeoutRef.current = setTimeout(() => {
            setSyncStatus((prev) => (prev === 'synced' ? 'idle' : prev))
          }, 5000)
          break
        case 'OPERATION_QUEUED':
          refreshPendingCount()
          break
      }
    }

    navigator.serviceWorker.addEventListener('message', handleMessage)
    return () => {
      navigator.serviceWorker.removeEventListener('message', handleMessage)
    }
  }, [refreshPendingCount])

  // Periodic pending count refresh + initial count check
  useEffect(() => {
    // Initial check
    offlineQueue.getCount().then((count) => {
      setPendingCount(count)
    }).catch(() => {})

    const interval = setInterval(refreshPendingCount, 15000)
    return () => clearInterval(interval)
  }, [refreshPendingCount])

  // Online + no pending + idle = simple green dot
  if (isOnline && pendingCount === 0 && syncStatus === 'idle') {
    return (
      <div className="flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium">
        <span className="relative flex h-2 w-2">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
          <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
        </span>
        <span className="text-emerald-600 hidden sm:inline">{t('offline_status_online')}</span>
      </div>
    )
  }

  // Offline state
  if (!isOnline) {
    return (
      <div className="flex items-center gap-1.5 px-2 py-1 rounded-full bg-red-50 border border-red-200 text-xs font-medium">
        <WifiOff className="h-3 w-3 text-red-500" />
        <span className="text-red-600">{t('offline_status_offline')}</span>
        {pendingCount > 0 && (
          <span className="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold leading-none">
            {pendingCount}
          </span>
        )}
      </div>
    )
  }

  // Online but has pending operations OR is syncing
  return (
    <div className="flex items-center gap-1">
      <div
        className={`
          flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium
          ${syncStatus === 'syncing'
            ? 'bg-sky-50 border border-sky-200'
            : syncStatus === 'synced'
              ? 'bg-emerald-50 border border-emerald-200'
              : syncStatus === 'failed'
                ? 'bg-red-50 border border-red-200'
                : 'bg-amber-50 border border-amber-200'
          }
        `}
      >
        {syncStatus === 'syncing' ? (
          <>
            <RefreshCw className="h-3 w-3 text-sky-600 animate-spin" />
            <span className="text-sky-700 hidden sm:inline">{t('offline_syncing')}</span>
          </>
        ) : syncStatus === 'synced' ? (
          <>
            <CheckCircle2 className="h-3 w-3 text-emerald-600" />
            <span className="text-emerald-700 hidden sm:inline">{t('offline_sync_complete')}</span>
          </>
        ) : syncStatus === 'failed' ? (
          <>
            <AlertCircle className="h-3 w-3 text-red-500" />
            <span className="text-red-600 hidden sm:inline">{t('offline_sync_failed')}</span>
          </>
        ) : (
          <>
            <CloudOff className="h-3 w-3 text-amber-600" />
            <span className="text-amber-700 hidden sm:inline">{t('offline_pending_ops')}</span>
          </>
        )}

        {pendingCount > 0 && (
          <span
            className={`
              inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold leading-none
              ${syncStatus === 'syncing'
                ? 'bg-sky-500 text-white'
                : syncStatus === 'failed'
                  ? 'bg-red-500 text-white'
                  : 'bg-amber-500 text-white'
              }
            `}
          >
            {pendingCount}
          </span>
        )}
      </div>

      {pendingCount > 0 && syncStatus !== 'syncing' && (
        <button
          onClick={handleSync}
          className="flex items-center justify-center h-6 w-6 rounded-full border border-gray-200 hover:bg-gray-100 transition-colors disabled:opacity-50"
          disabled={false}
          title={t('offline_manual_sync')}
        >
          <RefreshCw className="h-3 w-3 text-gray-600" />
        </button>
      )}
    </div>
  )
}
