'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function NotificationsPage() {
  const router = useRouter()
  const [notifications, setNotifications] = useState<any[]>([])
  const [user, setUser] = useState<any>(null)
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (!stored) { router.push('/login'); return }
    const parsed = JSON.parse(stored)
    setUser(parsed)
    loadNotifications(parsed.id)
  }, [router])

  const loadNotifications = async (userId: string) => {
    const res = await fetch(`/api/notifications?userId=${userId}`)
    const data = await res.json()
    setNotifications(data.notifications || [])
  }

  const deleteOne = async (id: number) => {
    await fetch(`/api/notifications?id=${id}`, { method: 'DELETE' })
    if (user) loadNotifications(user.id)
  }

  const deleteSelected = async () => {
    for (const id of selectedIds) {
      await fetch(`/api/notifications?id=${id}`, { method: 'DELETE' })
    }
    setSelectedIds(new Set())
    if (user) loadNotifications(user.id)
  }

  const deleteAll = async () => {
    if (confirm('حذف جميع الإشعارات؟')) {
      await fetch(`/api/notifications?userId=${user?.id}`, { method: 'DELETE' })
      if (user) loadNotifications(user.id)
    }
  }

  const toggleSelect = (id: number) => {
    const newSet = new Set(selectedIds)
    if (newSet.has(id)) newSet.delete(id)
    else newSet.add(id)
    setSelectedIds(newSet)
  }

  if (!user) return <div className="p-8 text-center">تحميل...</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-100 p-6">
      <div className="max-w-3xl mx-auto">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-2xl font-bold">الإشعارات</h1>
          <div className="flex gap-2">
            {selectedIds.size > 0 && (
              <button onClick={deleteSelected} className="bg-red-500 text-white px-3 py-1 rounded text-sm">🗑️ حذف المحدد ({selectedIds.size})</button>
            )}
            <button onClick={deleteAll} className="bg-gray-500 text-white px-3 py-1 rounded text-sm">🗑️ حذف الكل</button>
          </div>
        </div>
        <div className="space-y-2">
          {notifications.length === 0 ? (
            <div className="bg-white rounded-xl p-8 text-center text-gray-600">لا توجد إشعارات</div>
          ) : (
            notifications.map((n: any) => (
              <div key={n.id} className={`bg-white rounded-xl shadow p-4 border-r-4 ${n.is_read ? 'border-gray-300' : 'border-blue-500'}`}>
                <div className="flex items-start gap-3">
                  <input type="checkbox" checked={selectedIds.has(n.id)} onChange={() => toggleSelect(n.id)} className="mt-1" />
                  <div className="flex-1">
                    <h3 className="font-bold">{n.title}</h3>
                    <p className="text-gray-600 text-sm">{n.body}</p>
                    <p className="text-gray-600 text-xs mt-2">{new Date(n.created_at).toLocaleString('ar')}</p>
                  </div>
                  <button onClick={() => deleteOne(n.id)} className="text-red-400 hover:text-red-600">🗑️</button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
