'use client'

import { SettingsTab } from '@/components/dashboard/settings-tab'
import { UsersPermissionsTab } from '@/components/dashboard/users-permissions-tab'
import { useState, useEffect } from 'react'
import { Settings, Users } from 'lucide-react'
import { getBusinessRole } from '@/lib/shop-utils'

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState<'settings' | 'users'>('settings')
  const [isOwner, setIsOwner] = useState(true)

  useEffect(() => {
    const role = getBusinessRole()
    queueMicrotask(() => setIsOwner(role === 'owner'))
  }, [])

  // Non-owner users can only see general settings
  if (!isOwner) {
    return <SettingsTab />
  }

  return (
    <div className="space-y-6">
      {/* Tab Switcher */}
      <div className="flex gap-2 p-1 bg-gray-100 rounded-xl w-fit">
        <button
          onClick={() => setActiveTab('settings')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition ${
            activeTab === 'settings'
              ? 'bg-white text-emerald-700 shadow-sm'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          <Settings className="h-4 w-4" />
          إعدادات المحل
        </button>
        <button
          onClick={() => setActiveTab('users')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition ${
            activeTab === 'users'
              ? 'bg-white text-emerald-700 shadow-sm'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          <Users className="h-4 w-4" />
          المستخدمين والصلاحيات
        </button>
      </div>

      {/* Tab Content */}
      {activeTab === 'settings' ? <SettingsTab /> : <UsersPermissionsTab />}
    </div>
  )
}
