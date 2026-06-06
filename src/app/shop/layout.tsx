'use client'

import { useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import {
  Home,
  Package,
  FolderTree,
  Warehouse,
  ArrowLeftRight,
  ShoppingCart,
  RotateCcw,
  Receipt,
  Users,
  BookOpen,
  FileCheck,
  CreditCard,
  BadgeDollarSign,
  Building2,
  UserCog,
  Banknote,
  Key,
  LogOut,
  ChevronDown,
  ChevronLeft,
  Menu,
  Store,
  UserPlus,
  ClipboardList,
  Shield,
  Crown,
  Calculator,
  StoreIcon,
  Languages,
  Database,
  BarChart3,
  ShieldCheck,
  Wrench,
  Bell,
} from 'lucide-react'
import { useLanguage } from '@/lib/language-context'
import { TranslationKey } from '@/lib/i18n'
import { OnlineStatus } from '@/components/shared/OnlineStatus'

interface NavGroup {
  labelKey: TranslationKey
  icon: React.ElementType
  items: { href: string; labelKey: TranslationKey; icon: React.ElementType; accessKey: string }[]
}

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

// Role access definitions
const roleAccessMap: Record<string, string[]> = {
  owner: ['all'], // Full access
  accountant: [
    'sales-invoices', 'purchase-invoices', 'sales-returns', 'purchase-returns', 'price-quotes',
    'chart-of-accounts', 'accounting', 'bonds', 'general-ledger',
    'dashboard', 'settings',
  ],
  seller: [
    'sales-invoices', 'purchase-invoices', 'price-quotes', 'products', 'categories',
    'inventory', 'clients', 'dashboard',
  ],
}

const roleLabelMap: Record<string, { labelKey: TranslationKey; color: string; icon: React.ElementType }> = {
  owner: { labelKey: 'role_owner', color: 'bg-amber-100 text-amber-700 border-amber-200', icon: Crown },
  accountant: { labelKey: 'role_accountant', color: 'bg-sky-100 text-sky-700 border-sky-200', icon: Calculator },
  seller: { labelKey: 'role_seller', color: 'bg-violet-100 text-violet-700 border-violet-200', icon: StoreIcon },
}

// Quick shortcuts displayed in the top header bar
const quickShortcuts = [
  { href: '/shop/sales-invoices', labelKey: 'shortcut_sales_invoice' as TranslationKey, icon: Receipt, color: 'emerald', accessKey: 'sales-invoices' },
  { href: '/shop/purchase-invoices', labelKey: 'shortcut_purchase_invoice' as TranslationKey, icon: ShoppingCart, color: 'orange', accessKey: 'purchase-invoices' },
  { href: '/shop/price-quotes', labelKey: 'shortcut_price_quote' as TranslationKey, icon: FileCheck, color: 'teal', accessKey: 'price-quotes' },
  { href: '/shop/bonds', labelKey: 'shortcut_bonds' as TranslationKey, icon: FileCheck, color: 'blue', accessKey: 'bonds' },
  { href: '/shop/products', labelKey: 'shortcut_product_card' as TranslationKey, icon: Package, color: 'violet', accessKey: 'products' },
  { href: '/shop/chart-of-accounts', labelKey: 'shortcut_account_card' as TranslationKey, icon: BookOpen, color: 'amber', accessKey: 'chart-of-accounts' },
  { href: '/shop/general-ledger', labelKey: 'shortcut_general_ledger' as TranslationKey, icon: UserPlus, color: 'teal', accessKey: 'general-ledger' },
] as const

// Reorganized sidebar menu groups
const navGroups: (NavGroup | { type: 'link'; href: string; labelKey: TranslationKey; icon: React.ElementType; accessKey: string })[] = [
  { type: 'link', href: '/shop/dashboard', labelKey: 'nav_home', icon: Home, accessKey: 'dashboard' },
  {
    labelKey: 'nav_invoices',
    icon: Receipt,
    items: [
      { href: '/shop/sales-invoices', labelKey: 'nav_sales_invoices', icon: Receipt, accessKey: 'sales-invoices' },
      { href: '/shop/purchase-invoices', labelKey: 'nav_purchase_invoices', icon: ShoppingCart, accessKey: 'purchase-invoices' },
      { href: '/shop/price-quotes', labelKey: 'nav_price_quotes', icon: FileCheck, accessKey: 'price-quotes' },
      { href: '/shop/sales-returns', labelKey: 'nav_sales_returns', icon: RotateCcw, accessKey: 'sales-returns' },
      { href: '/shop/purchase-returns', labelKey: 'nav_purchase_returns', icon: RotateCcw, accessKey: 'purchase-returns' },
    ],
  },
  {
    labelKey: 'nav_inventory',
    icon: Package,
    items: [
      { href: '/shop/products', labelKey: 'nav_products', icon: Package, accessKey: 'products' },
      { href: '/shop/categories', labelKey: 'nav_categories', icon: FolderTree, accessKey: 'categories' },
      { href: '/shop/inventory', labelKey: 'nav_inventory_mgmt', icon: ArrowLeftRight, accessKey: 'inventory' },
      { href: '/shop/warehouses', labelKey: 'nav_warehouses', icon: Warehouse, accessKey: 'warehouses' },
    ],
  },
  {
    labelKey: 'nav_accounts',
    icon: BookOpen,
    items: [
      { href: '/shop/chart-of-accounts', labelKey: 'nav_chart_of_accounts', icon: BookOpen, accessKey: 'chart-of-accounts' },
      { href: '/shop/bonds', labelKey: 'nav_bonds', icon: FileCheck, accessKey: 'bonds' },
      { href: '/shop/accounting', labelKey: 'nav_accounting', icon: CreditCard, accessKey: 'accounting' },
      { href: '/shop/general-ledger', labelKey: 'nav_general_ledger', icon: ClipboardList, accessKey: 'general-ledger' },
    ],
  },
  {
    labelKey: 'nav_people',
    icon: Users,
    items: [
      { href: '/shop/clients', labelKey: 'nav_clients', icon: Users, accessKey: 'clients' },
      { href: '/shop/suppliers', labelKey: 'nav_suppliers', icon: UserPlus, accessKey: 'suppliers' },
      { href: '/shop/employees', labelKey: 'nav_employees', icon: UserCog, accessKey: 'employees' },
    ],
  },
  {
    labelKey: 'nav_expenses',
    icon: BadgeDollarSign,
    items: [
      { href: '/shop/salaries', labelKey: 'nav_salaries', icon: Banknote, accessKey: 'salaries' },
      { href: '/shop/rents', labelKey: 'nav_rents', icon: Building2, accessKey: 'rents' },
      { href: '/shop/offers', labelKey: 'nav_offers', icon: BadgeDollarSign, accessKey: 'offers' },
    ],
  },
  { type: 'link', href: '/shop/settings', labelKey: 'nav_settings', icon: Key, accessKey: 'settings' },
  {
    labelKey: 'nav_tools',
    icon: Wrench,
    items: [
      { href: '/shop/financial-dashboard', labelKey: 'nav_financial_dashboard', icon: BarChart3, accessKey: 'dashboard' },
      { href: '/shop/backup', labelKey: 'nav_backup', icon: Database, accessKey: 'settings' },
      { href: '/shop/audit-log', labelKey: 'nav_audit_log', icon: ShieldCheck, accessKey: 'settings' },
      { href: '/shop/notifications', labelKey: 'nav_notifications', icon: Bell, accessKey: 'settings' },
    ],
  },
]

const shortcutColorMap: Record<string, { bg: string; hoverBg: string; text: string; border: string; activeBg: string; activeText: string }> = {
  emerald: {
    bg: 'bg-emerald-50',
    hoverBg: 'hover:bg-emerald-100',
    text: 'text-emerald-700',
    border: 'border-emerald-200',
    activeBg: 'bg-emerald-600',
    activeText: 'text-white',
  },
  orange: {
    bg: 'bg-orange-50',
    hoverBg: 'hover:bg-orange-100',
    text: 'text-orange-700',
    border: 'border-orange-200',
    activeBg: 'bg-orange-600',
    activeText: 'text-white',
  },
  blue: {
    bg: 'bg-sky-50',
    hoverBg: 'hover:bg-sky-100',
    text: 'text-sky-700',
    border: 'border-sky-200',
    activeBg: 'bg-sky-600',
    activeText: 'text-white',
  },
  violet: {
    bg: 'bg-violet-50',
    hoverBg: 'hover:bg-violet-100',
    text: 'text-violet-700',
    border: 'border-violet-200',
    activeBg: 'bg-violet-600',
    activeText: 'text-white',
  },
  amber: {
    bg: 'bg-amber-50',
    hoverBg: 'hover:bg-amber-100',
    text: 'text-amber-700',
    border: 'border-amber-200',
    activeBg: 'bg-amber-600',
    activeText: 'text-white',
  },
  teal: {
    bg: 'bg-teal-50',
    hoverBg: 'hover:bg-teal-100',
    text: 'text-teal-700',
    border: 'border-teal-200',
    activeBg: 'bg-teal-600',
    activeText: 'text-white',
  },
}

function canAccess(businessRole: string | undefined, accessKey: string): boolean {
  const role = businessRole || 'owner'
  const allowed = roleAccessMap[role]
  if (!allowed) return false
  if (allowed.includes('all')) return true
  return allowed.includes(accessKey)
}

export default function ShopLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const router = useRouter()
  const { lang, setLang, t, dir } = useLanguage()
  const [user, setUser] = useState<UserData | null>(null)
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set([
    'nav_invoices',
    'nav_inventory',
    'nav_accounts',
    'nav_people',
    'nav_expenses',
    'nav_tools',
  ]))

  const isLoginPage = pathname === '/shop/login'

  // Register service worker with enhanced update handling
  useEffect(() => {
    if (isLoginPage) return
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').then((registration) => {
        // Handle updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing
          if (newWorker) {
            newWorker.addEventListener('statechange', () => {
              if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                // New content is available, notify the waiting worker to activate
                newWorker.postMessage({ type: 'SKIP_WAITING' })
              }
            })
          }
        })

        // When controller changes (new SW activated), reload for fresh content
        navigator.serviceWorker.addEventListener('controllerchange', () => {
          // Page will reload automatically with the new service worker
        })

        // Check for updates periodically
        const intervalId = setInterval(() => {
          registration.update()
        }, 60 * 60 * 1000) // every hour

        return () => clearInterval(intervalId)
      }).catch((error) => {
        console.log('SW registration failed:', error)
      })
    }
  }, [isLoginPage])

  // The businessRole is either from the businessRole field (sub-user) or defaults to 'owner'
  const businessRole = user?.businessRole || (user?.role === 'business' ? 'owner' : undefined)

  // Filter navigation items based on role
  const filteredNavGroups = useMemo(() => {
    if (!businessRole) return navGroups
    return navGroups.filter((group) => {
      if ('type' in group && group.type === 'link') {
        return canAccess(businessRole, group.accessKey)
      }
      const navGroup = group as NavGroup
      // Filter items within groups
      const filteredItems = navGroup.items.filter((item) => canAccess(businessRole, item.accessKey))
      if (filteredItems.length === 0) return false
      return true
    }).map((group) => {
      if ('type' in group && group.type === 'link') return group
      const navGroup = group as NavGroup
      return {
        ...navGroup,
        items: navGroup.items.filter((item) => canAccess(businessRole, item.accessKey)),
      }
    })
  }, [businessRole])

  // Filter shortcuts based on role
  const filteredShortcuts = useMemo(() => {
    if (!businessRole) return quickShortcuts
    return quickShortcuts.filter((s) => canAccess(businessRole, s.accessKey))
  }, [businessRole])

  useEffect(() => {
    if (isLoginPage) return
    const saved = localStorage.getItem('sana3i_user')
    if (saved) {
      const userData = JSON.parse(saved)
      if (userData.role !== 'business') {
        router.push('/shop/login')
        return
      }
      queueMicrotask(() => setUser(userData))
    } else {
      router.push('/shop/login')
    }
  }, [router, isLoginPage])

  // Auto-expand group that contains the active path
  useEffect(() => {
    const groupsToExpand: string[] = []
    for (const group of filteredNavGroups) {
      if ('items' in group) {
        for (const item of group.items) {
          if (pathname === item.href) {
            groupsToExpand.push(group.labelKey)
            break
          }
        }
      }
    }
    if (groupsToExpand.length > 0) {
      const timer = setTimeout(() => {
        setExpandedGroups((prev) => {
          const next = new Set(prev)
          groupsToExpand.forEach((label) => next.add(label))
          return next
        })
      }, 0)
      return () => clearTimeout(timer)
    }
  }, [pathname, filteredNavGroups])

  if (isLoginPage) {
    return <>{children}</>
  }

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/shop/login')
  }

  const toggleGroup = (label: string) => {
    setExpandedGroups((prev) => {
      const next = new Set(prev)
      if (next.has(label)) next.delete(label)
      else next.add(label)
      return next
    })
  }

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-gray-500">{t('loading')}</p>
      </div>
    )
  }

  const isActive = (href: string) => pathname === href
  const roleInfo = businessRole ? roleLabelMap[businessRole] : null
  const RoleIcon = roleInfo?.icon

  return (
    <div className="min-h-screen bg-gray-100 flex" dir={dir}>
      {sidebarOpen && (
        <div className="fixed inset-0 bg-black/50 z-40 md:hidden" onClick={() => setSidebarOpen(false)} />
      )}

      <aside
        className={`
          fixed md:static inset-y-0 end-0 z-50
          w-64 bg-white border-s shadow-sm
          transform transition-transform md:transform-none
          ${sidebarOpen ? 'translate-x-0' : `${dir === 'rtl' ? 'translate-x-full' : '-translate-x-full'} md:translate-x-0`}
        `}
      >
        <div className="flex flex-col h-full">
          <div className="p-4 border-b">
            <Link href="/shop/dashboard" className="flex items-center gap-2 font-bold text-lg">
              <Store className="h-6 w-6 text-emerald-600" />
              <div>
                <span>{t('app_name')}</span>
                <p className="text-xs text-gray-400 font-normal">{t('app_subtitle')}</p>
              </div>
            </Link>
          </div>

          <nav className="flex-1 p-3 space-y-1 overflow-y-auto max-h-[calc(100vh-130px)]">
            {filteredNavGroups.map((group, idx) => {
              if ('type' in group && group.type === 'link') {
                const link = group as { href: string; labelKey: TranslationKey; icon: React.ElementType; accessKey: string }
                const Icon = link.icon
                return (
                  <Link
                    key={link.href}
                    href={link.href}
                    onClick={() => setSidebarOpen(false)}
                    className={`
                      flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition
                      ${isActive(link.href)
                        ? 'bg-emerald-50 text-emerald-700 font-medium'
                        : 'text-gray-600 hover:bg-gray-100'
                      }
                    `}
                  >
                    <Icon className="h-4 w-4 shrink-0" />
                    <span>{t(link.labelKey)}</span>
                  </Link>
                )
              }

              const navGroup = group as NavGroup
              const GroupIcon = navGroup.icon
              const isExpanded = expandedGroups.has(navGroup.labelKey)
              const hasActive = navGroup.items.some((item) => isActive(item.href))

              return (
                <div key={idx}>
                  <button
                    onClick={() => toggleGroup(navGroup.labelKey)}
                    className={`
                      w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition
                      ${hasActive
                        ? 'text-emerald-700 font-medium bg-emerald-50/50'
                        : 'text-gray-500 hover:bg-gray-50'
                      }
                    `}
                  >
                    <GroupIcon className="h-4 w-4 shrink-0" />
                    <span className="flex-1 text-right">{t(navGroup.labelKey)}</span>
                    {isExpanded ? (
                      <ChevronDown className="h-3.5 w-3.5" />
                    ) : (
                      <ChevronLeft className="h-3.5 w-3.5" />
                    )}
                  </button>
                  {isExpanded && (
                    <div className={`${dir === 'rtl' ? 'ms-4' : 'me-4'} mt-1 space-y-0.5`}>
                      {navGroup.items.map((item) => {
                        const ItemIcon = item.icon
                        return (
                          <Link
                            key={item.href}
                            href={item.href}
                            onClick={() => setSidebarOpen(false)}
                            className={`
                              flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition
                              ${isActive(item.href)
                                ? 'bg-emerald-50 text-emerald-700 font-medium'
                                : 'text-gray-500 hover:bg-gray-50 hover:text-gray-700'
                              }
                            `}
                          >
                            <ItemIcon className="h-3.5 w-3.5 shrink-0" />
                            <span>{t(item.labelKey)}</span>
                          </Link>
                        )
                      })}
                    </div>
                  )}
                </div>
              )
            })}
          </nav>

          <div className="p-3 border-t">
            <button
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-red-600 hover:text-red-700 hover:bg-red-50 transition"
              onClick={handleLogout}
            >
              <LogOut className="h-4 w-4" />
              <span>{t('logout')}</span>
            </button>
          </div>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-h-screen">
        {/* Top Header Bar with Quick Shortcuts */}
        <header className="bg-white border-b shadow-sm">
          {/* Main header row */}
          <div className="px-4 h-14 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <button className="md:hidden text-gray-600" onClick={() => setSidebarOpen(true)}>
                <Menu className="h-5 w-5" />
              </button>
              <p className="text-sm text-gray-500">
                {t('welcome')}, <span className="font-medium text-gray-900">{user.name}</span>
              </p>
              {/* Role Badge */}
              {roleInfo && RoleIcon && (
                <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium border ${roleInfo.color}`}>
                  <RoleIcon className="h-3 w-3" />
                  {t(roleInfo.labelKey)}
                </span>
              )}
            </div>
            <div className="flex items-center gap-2">
              {businessRole && businessRole !== 'owner' && (
                <div className="flex items-center gap-1 text-xs text-gray-400">
                  <Shield className="h-3.5 w-3.5" />
                  <span>{t('limited_permissions')}</span>
                </div>
              )}
              <OnlineStatus />
              <Link href="/shop/notifications" className="relative flex items-center justify-center h-8 w-8 rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-100 hover:text-gray-800 transition">
                <Bell className="h-4 w-4" />
              </Link>
              <button
                onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}
                className="flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium border border-gray-200 text-gray-600 hover:bg-gray-100 hover:text-gray-800 transition"
              >
                <Languages className="h-3.5 w-3.5" />
                {lang === 'ar' ? 'EN' : 'عربي'}
              </button>
            </div>
          </div>

          {/* Quick shortcuts row */}
          {filteredShortcuts.length > 0 && (
            <div className="px-3 pb-2 flex gap-2 overflow-x-auto scrollbar-thin">
              {filteredShortcuts.map((shortcut) => {
                const Icon = shortcut.icon
                const colors = shortcutColorMap[shortcut.color]
                const active = isActive(shortcut.href)
                return (
                  <Link
                    key={shortcut.href}
                    href={shortcut.href}
                    onClick={() => setSidebarOpen(false)}
                    className={`
                      flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium
                      border transition whitespace-nowrap shrink-0
                      ${active
                        ? `${colors.activeBg} ${colors.activeText} border-transparent shadow-sm`
                        : `${colors.bg} ${colors.text} ${colors.border} ${colors.hoverBg}`
                      }
                    `}
                  >
                    <Icon className="h-3.5 w-3.5" />
                    <span>{t(shortcut.labelKey)}</span>
                  </Link>
                )
              })}
            </div>
          )}
        </header>

        <main className="flex-1 p-4 md:p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
