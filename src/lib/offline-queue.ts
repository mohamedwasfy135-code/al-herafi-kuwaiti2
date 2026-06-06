// Offline Queue for pending operations when offline
// Uses IndexedDB to store pending API calls
// When back online, replays them in order

interface PendingOperation {
  id: string
  url: string
  method: string
  body: any
  timestamp: number
  retries: number
}

class OfflineQueue {
  private dbName = 'sana3i_offline'
  private storeName = 'pending_ops'
  private db: IDBDatabase | null = null

  private async getDB(): Promise<IDBDatabase> {
    if (this.db) return this.db

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, 1)

      request.onerror = () => reject(request.error)

      request.onupgradeneeded = () => {
        const db = request.result
        if (!db.objectStoreNames.contains(this.storeName)) {
          const store = db.createObjectStore(this.storeName, { keyPath: 'id' })
          store.createIndex('timestamp', 'timestamp', { unique: false })
        }
      }

      request.onsuccess = () => {
        this.db = request.result
        resolve(this.db)
      }
    })
  }

  async add(operation: Omit<PendingOperation, 'id' | 'timestamp' | 'retries'>): Promise<void> {
    const db = await this.getDB()
    const op: PendingOperation = {
      ...operation,
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
      timestamp: Date.now(),
      retries: 0,
    }

    return new Promise((resolve, reject) => {
      const tx = db.transaction(this.storeName, 'readwrite')
      const store = tx.objectStore(this.storeName)
      const request = store.add(op)
      request.onsuccess = () => resolve()
      request.onerror = () => reject(request.error)
    })
  }

  async getAll(): Promise<PendingOperation[]> {
    const db = await this.getDB()

    return new Promise((resolve, reject) => {
      const tx = db.transaction(this.storeName, 'readonly')
      const store = tx.objectStore(this.storeName)
      const index = store.index('timestamp')
      const request = index.getAll()
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error)
    })
  }

  async remove(id: string): Promise<void> {
    const db = await this.getDB()

    return new Promise((resolve, reject) => {
      const tx = db.transaction(this.storeName, 'readwrite')
      const store = tx.objectStore(this.storeName)
      const request = store.delete(id)
      request.onsuccess = () => resolve()
      request.onerror = () => reject(request.error)
    })
  }

  async getCount(): Promise<number> {
    const db = await this.getDB()

    return new Promise((resolve, reject) => {
      const tx = db.transaction(this.storeName, 'readonly')
      const store = tx.objectStore(this.storeName)
      const request = store.count()
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error)
    })
  }

  async replayAll(): Promise<{ success: number; failed: number }> {
    const operations = await this.getAll()
    let success = 0
    let failed = 0

    for (const op of operations) {
      try {
        const response = await fetch(op.url, {
          method: op.method,
          headers: {
            'Content-Type': 'application/json',
          },
          body: op.body ? JSON.stringify(op.body) : undefined,
        })

        if (response.ok) {
          await this.remove(op.id)
          success++
        } else {
          // Increment retry count
          op.retries++
          if (op.retries >= 3) {
            // Remove after 3 failed retries
            await this.remove(op.id)
          }
          failed++
        }
      } catch {
        failed++
        op.retries++
        if (op.retries >= 3) {
          await this.remove(op.id)
        }
      }
    }

    return { success, failed }
  }

  async clear(): Promise<void> {
    const db = await this.getDB()

    return new Promise((resolve, reject) => {
      const tx = db.transaction(this.storeName, 'readwrite')
      const store = tx.objectStore(this.storeName)
      const request = store.clear()
      request.onsuccess = () => resolve()
      request.onerror = () => reject(request.error)
    })
  }
}

export const offlineQueue = new OfflineQueue()
