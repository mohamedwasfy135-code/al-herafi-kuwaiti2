'use client'

import { offlineQueue } from './offline-queue'

export interface FetchWithOfflineOptions extends RequestInit {
  /** If true, skip the offline queue and fail immediately when offline */
  skipQueue?: boolean
}

/**
 * Fetch wrapper that queues non-GET requests when offline.
 * When the user is offline, POST/PUT/DELETE/PATCH requests are stored
 * in the offline queue (IndexedDB) and replayed when connectivity returns.
 *
 * GET requests are handled by the service worker cache.
 */
export async function fetchWithOffline(
  url: string,
  options?: FetchWithOfflineOptions
): Promise<Response> {
  const { skipQueue, ...fetchOptions } = options || {}
  const method = (fetchOptions.method || 'GET').toUpperCase()

  // For GET requests, just use normal fetch (service worker handles caching)
  if (method === 'GET') {
    return fetch(url, fetchOptions)
  }

  // If online or skipQueue, do a normal fetch
  if (navigator.onLine || skipQueue) {
    return fetch(url, fetchOptions)
  }

  // Offline + non-GET request: queue it for later sync
  try {
    let body: unknown = undefined
    if (fetchOptions.body) {
      if (typeof fetchOptions.body === 'string') {
        try {
          body = JSON.parse(fetchOptions.body)
        } catch {
          body = fetchOptions.body
        }
      } else {
        body = fetchOptions.body
      }
    }

    await offlineQueue.add({
      url,
      method,
      body,
    })

    // Try to trigger background sync via service worker
    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: 'TRIGGER_SYNC',
      })
    }

    return new Response(
      JSON.stringify({
        queued: true,
        offline: true,
        message: 'Operation saved for sync',
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 202,
      }
    )
  } catch (error) {
    console.error('[fetchWithOffline] Failed to queue request:', error)
    return new Response(
      JSON.stringify({
        error: true,
        offline: true,
        message: 'Failed to queue operation',
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 503,
      }
    )
  }
}

/**
 * Check if a response came from the offline queue
 */
export function isQueuedResponse(response: Response): boolean {
  return response.status === 202 && response.headers.get('Content-Type') === 'application/json'
}

/**
 * Parse a queued response body
 */
export async function parseQueuedResponse(response: Response): Promise<{
  queued: boolean
  offline: boolean
  message?: string
} | null> {
  if (!isQueuedResponse(response)) return null
  try {
    return await response.json()
  } catch {
    return null
  }
}

/**
 * Get the count of pending operations in the offline queue
 */
export async function getPendingOperationsCount(): Promise<number> {
  try {
    return await offlineQueue.getCount()
  } catch {
    return 0
  }
}

/**
 * Manually trigger sync of all pending operations
 */
export async function triggerManualSync(): Promise<{
  success: number
  failed: number
}> {
  if (!navigator.onLine) {
    return { success: 0, failed: 0 }
  }
  return offlineQueue.replayAll()
}
