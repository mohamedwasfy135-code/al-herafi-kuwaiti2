const CACHE_NAME = 'sana3i-v2'
const API_CACHE = 'sana3i-api-v2'
const IMAGE_CACHE = 'sana3i-images-v2'

const STATIC_ASSETS = [
  '/',
  '/shop/login',
  '/shop/dashboard',
  '/manifest.json',
]

// Assets to cache on install (core shell)
const PRE_CACHE_ROUTES = [
  '/shop/login',
  '/shop/dashboard',
]

// Install: cache static assets and pre-cache app shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('[SW] Some static assets failed to cache:', err)
      })
    })
  )
  self.skipWaiting()
})

// Activate: clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== CACHE_NAME && k !== API_CACHE && k !== IMAGE_CACHE)
          .map((k) => caches.delete(k))
      )
    )
  )
  self.clients.claim()
})

// Fetch strategy
self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)

  // Skip non-http requests (chrome-extension, etc.)
  if (!url.protocol.startsWith('http')) return

  // Skip Next.js HMR and dev requests
  if (url.pathname.startsWith('/_next/') && url.pathname.includes('hmr')) return

  // Handle POST/PUT/DELETE - queue when offline
  if (request.method !== 'GET') {
    event.respondWith(handleNonGetRequest(request))
    return
  }

  // Image caching strategy - cache-first with long TTL
  if (url.pathname.match(/\.(png|jpg|jpeg|gif|svg|webp|ico)$/)) {
    event.respondWith(handleImageRequest(request))
    return
  }

  // API requests - network-first
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(handleApiRequest(request))
    return
  }

  // Static assets (JS, CSS, fonts) - stale-while-revalidate
  if (url.pathname.match(/\.(js|css|woff2?|ttf|eot)$/)) {
    event.respondWith(handleStaticAssetRequest(request))
    return
  }

  // Navigation and other requests - cache-first with offline fallback
  event.respondWith(handleNavigationRequest(request))
})

// Handle non-GET requests (POST, PUT, DELETE, PATCH)
async function handleNonGetRequest(request) {
  try {
    const response = await fetch(request)
    return response
  } catch (error) {
    // Network failed - store in IndexedDB for later sync
    try {
      const body = await request.text()
      const db = await openDB()
      await db.put('pending_requests', {
        url: request.url,
        method: request.method,
        headers: Object.fromEntries(request.headers.entries()),
        body: body,
        timestamp: Date.now(),
      })

      // Register for background sync
      if ('sync' in self.registration) {
        await self.registration.sync.register('sync-pending-operations')
      }

      // Notify clients about queued operation
      const clients = await self.clients.matchAll()
      clients.forEach((c) =>
        c.postMessage({
          type: 'OPERATION_QUEUED',
          url: request.url,
          method: request.method,
        })
      )

      // Return a mock success response so the app doesn't crash
      return new Response(
        JSON.stringify({ queued: true, offline: true, message: 'Operation saved for sync' }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 202,
        }
      )
    } catch (dbError) {
      console.error('[SW] Failed to queue offline request:', dbError)
      return new Response(
        JSON.stringify({ error: true, offline: true, message: 'Failed to queue operation' }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 503,
        }
      )
    }
  }
}

// Handle API requests - network-first with cache fallback
async function handleApiRequest(request) {
  try {
    const response = await fetch(request)
    if (response.ok) {
      const clone = response.clone()
      caches.open(API_CACHE).then((cache) => cache.put(request, clone))
    }
    return response
  } catch (error) {
    const cached = await caches.match(request)
    if (cached) return cached
    return new Response(
      JSON.stringify({ error: true, offline: true, message: 'No cached data available' }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 503,
      }
    )
  }
}

// Handle image requests - cache-first
async function handleImageRequest(request) {
  const cached = await caches.match(request)
  if (cached) return cached

  try {
    const response = await fetch(request)
    if (response.ok) {
      const clone = response.clone()
      caches.open(IMAGE_CACHE).then((cache) => cache.put(request, clone))
    }
    return response
  } catch (error) {
    // Return a simple 1x1 transparent placeholder
    return new Response('', {
      headers: { 'Content-Type': 'image/svg+xml' },
      status: 200,
    })
  }
}

// Handle static assets (JS, CSS, fonts) - stale-while-revalidate
async function handleStaticAssetRequest(request) {
  const cached = await caches.match(request)
  const fetchPromise = fetch(request)
    .then((response) => {
      if (response.ok) {
        const clone = response.clone()
        caches.open(CACHE_NAME).then((cache) => cache.put(request, clone))
      }
      return response
    })
    .catch(() => cached)

  return cached || fetchPromise
}

// Handle navigation requests - cache-first with offline fallback
async function handleNavigationRequest(request) {
  const cached = await caches.match(request)
  if (cached) return cached

  try {
    const response = await fetch(request)
    if (response.ok && response.type === 'basic') {
      const clone = response.clone()
      caches.open(CACHE_NAME).then((cache) => cache.put(request, clone))
    }
    return response
  } catch (error) {
    // Offline fallback for navigation requests
    if (request.mode === 'navigate') {
      const fallback = await caches.match('/shop/dashboard')
      if (fallback) return fallback
      return new Response(
        '<html><body><h1 style="text-align:center;padding:40px;font-family:system-ui">You are offline</h1><p style="text-align:center;font-family:system-ui;color:#666">Please check your internet connection and try again.</p></body></html>',
        {
          headers: { 'Content-Type': 'text/html' },
          status: 503,
        }
      )
    }
    return new Response('Offline', { status: 503, statusText: 'Offline' })
  }
}

// Background sync event
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-pending-operations') {
    event.waitUntil(replayPendingRequests())
  }
})

// Open IndexedDB for service worker
function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('sana3i_sw_db', 1)
    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains('pending_requests')) {
        db.createObjectStore('pending_requests', { keyPath: 'timestamp' })
      }
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

// Replay pending requests stored in IndexedDB
async function replayPendingRequests() {
  const db = await openDB()

  const getAll = () =>
    new Promise((resolve) => {
      const tx = db.transaction('pending_requests', 'readonly')
      const store = tx.objectStore('pending_requests')
      const req = store.getAll()
      req.onsuccess = () => resolve(req.result)
      req.onerror = () => resolve([])
    })

  const requests = await getAll()

  if (requests.length === 0) return

  // Notify clients that sync is starting
  const clients = await self.clients.matchAll()
  clients.forEach((c) => c.postMessage({ type: 'SYNC_START', count: requests.length }))

  let success = 0
  let failed = 0

  for (const req of requests) {
    try {
      const response = await fetch(req.url, {
        method: req.method,
        headers: req.headers,
        body: req.body || undefined,
      })

      if (response.ok) {
        // Remove from IndexedDB on success
        const deleteTx = db.transaction('pending_requests', 'readwrite')
        deleteTx.objectStore('pending_requests').delete(req.timestamp)
        success++
      } else {
        failed++
      }
    } catch (e) {
      failed++
    }
  }

  // Notify clients that sync is complete
  clients.forEach((c) =>
    c.postMessage({ type: 'SYNC_COMPLETE', success, failed })
  )
}

// Handle messages from clients
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting()
  }
  if (event.data && event.data.type === 'GET_PENDING_COUNT') {
    getPendingCount().then((count) => {
      event.ports[0].postMessage({ count })
    })
  }
})

async function getPendingCount() {
  try {
    const db = await openDB()
    return new Promise((resolve) => {
      const tx = db.transaction('pending_requests', 'readonly')
      const store = tx.objectStore('pending_requests')
      const req = store.count()
      req.onsuccess = () => resolve(req.result)
      req.onerror = () => resolve(0)
    })
  } catch {
    return 0
  }
}
