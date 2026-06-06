'use client'

/**
 * استخراج businessId وبيانات المستخدم من localStorage
 * هذا الملف يُستخدم في المكونات فقط (client-side)
 */

interface UserData {
  id: string
  name: string
  role: string
  phone?: string
  email?: string
  businessId?: string
  businessName?: string
  businessRole?: string // 'owner' | 'accountant' | 'seller'
  permissions?: Record<string, boolean> | null
}

/**
 * الحصول على بيانات المستخدم من localStorage
 */
export function getLocalUser(): UserData | null {
  if (typeof window === 'undefined') return null
  const saved = localStorage.getItem('sana3i_user')
  if (!saved) return null
  try {
    return JSON.parse(saved)
  } catch {
    return null
  }
}

/**
 * الحصول على businessId للمستخدم الحالي
 * يُرجع businessId من بيانات المستخدم إذا كان متوفراً
 * أو يُرجع userId كملاذ أخير
 * أو يُرجع 'demo' كقيمة افتراضية
 */
export function getBusinessId(): string {
  const user = getLocalUser()
  if (user?.role === 'business') {
    return user.businessId || user.id || 'demo'
  }
  return 'demo'
}

/**
 * الحصول على دور المستخدم التجاري (مالك/محاسب/بائع)
 */
export function getBusinessRole(): string {
  const user = getLocalUser()
  if (user?.businessRole) return user.businessRole
  if (user?.role === 'business') return 'owner'
  return 'owner'
}

/**
 * الحصول على صلاحيات المستخدم التجاري
 */
export function getBusinessPermissions(): Record<string, boolean> | null {
  const user = getLocalUser()
  return user?.permissions || null
}

/**
 * التحقق من صلاحية الوصول لصفحة معينة
 */
export function canAccessPage(accessKey: string): boolean {
  const role = getBusinessRole()
  const roleAccessMap: Record<string, string[]> = {
    owner: ['all'],
    accountant: [
      'sales-invoices', 'purchase-invoices', 'sales-returns', 'purchase-returns',
      'chart-of-accounts', 'accounting', 'bonds', 'general-ledger',
      'dashboard', 'settings',
    ],
    seller: [
      'sales-invoices', 'purchase-invoices', 'products', 'categories',
      'inventory', 'clients', 'dashboard',
    ],
  }

  const allowed = roleAccessMap[role]
  if (!allowed) return false
  if (allowed.includes('all')) return true
  return allowed.includes(accessKey)
}
