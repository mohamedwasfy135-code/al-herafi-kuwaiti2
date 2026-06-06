'use client'

import { useState, useEffect } from 'react'
import {
  Users,
  Plus,
  Edit3,
  Trash2,
  Shield,
  Loader2,
  Phone,
  Mail,
  Lock,
  CheckCircle2,
  XCircle,
  Crown,
  Calculator,
  Store,
  Eye,
  EyeOff,
  Save,
  X,
} from 'lucide-react'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'
import type { TranslationKey } from '@/lib/i18n'

interface BusinessUser {
  id: string
  businessId: string
  name: string
  phone: string | null
  email: string | null
  role: string
  permissions: Record<string, boolean> | null
  isActive: boolean
  createdAt: string
  updatedAt: string
}

const roleOptionKeys: { value: string; labelKey: TranslationKey; icon: React.ElementType; color: string }[] = [
  { value: 'accountant', labelKey: 'role_accountant', icon: Calculator, color: 'bg-sky-100 text-sky-700 border-sky-200' },
  { value: 'seller', labelKey: 'role_seller', icon: Store, color: 'bg-violet-100 text-violet-700 border-violet-200' },
]

const roleLabelMapKeys: Record<string, { labelKey: TranslationKey; icon: React.ElementType; color: string }> = {
  owner: { labelKey: 'role_owner', icon: Crown, color: 'bg-amber-100 text-amber-700 border-amber-200' },
  accountant: { labelKey: 'role_accountant', icon: Calculator, color: 'bg-sky-100 text-sky-700 border-sky-200' },
  seller: { labelKey: 'role_seller', icon: Store, color: 'bg-violet-100 text-violet-700 border-violet-200' },
}

// Permission items per role
const permissionItemKeys: { key: string; labelKey: TranslationKey }[] = [
  { key: 'sales-invoices', labelKey: 'nav_sales_invoices' },
  { key: 'purchase-invoices', labelKey: 'nav_purchase_invoices' },
  { key: 'sales-returns', labelKey: 'nav_sales_returns' },
  { key: 'purchase-returns', labelKey: 'nav_purchase_returns' },
  { key: 'products', labelKey: 'nav_products' },
  { key: 'categories', labelKey: 'nav_categories' },
  { key: 'inventory', labelKey: 'nav_inventory_mgmt' },
  { key: 'warehouses', labelKey: 'nav_warehouses' },
  { key: 'chart-of-accounts', labelKey: 'nav_chart_of_accounts' },
  { key: 'bonds', labelKey: 'nav_bonds' },
  { key: 'accounting', labelKey: 'nav_accounting' },
  { key: 'general-ledger', labelKey: 'nav_general_ledger' },
  { key: 'clients', labelKey: 'nav_clients' },
  { key: 'suppliers', labelKey: 'nav_suppliers' },
  { key: 'employees', labelKey: 'nav_employees' },
  { key: 'salaries', labelKey: 'nav_salaries' },
  { key: 'rents', labelKey: 'nav_rents' },
  { key: 'offers', labelKey: 'nav_offers' },
  { key: 'dashboard', labelKey: 'dashboard_title' },
  { key: 'settings', labelKey: 'nav_settings' },
]

// Default permissions per role
const defaultPermissions: Record<string, Record<string, boolean>> = {
  accountant: {
    'sales-invoices': true,
    'purchase-invoices': true,
    'sales-returns': true,
    'purchase-returns': true,
    'chart-of-accounts': true,
    'accounting': true,
    'bonds': true,
    'general-ledger': true,
    'dashboard': true,
    'settings': true,
  },
  seller: {
    'sales-invoices': true,
    'purchase-invoices': true,
    'products': true,
    'categories': true,
    'inventory': true,
    'clients': true,
    'dashboard': true,
  },
}

export function UsersPermissionsTab() {
  const { t, lang, dir } = useLanguage()
  const [users, setUsers] = useState<BusinessUser[]>([])
  const [loading, setLoading] = useState(true)
  const [showAddDialog, setShowAddDialog] = useState(false)
  const [editUser, setEditUser] = useState<BusinessUser | null>(null)
  const [showPassword, setShowPassword] = useState(false)
  const [saving, setSaving] = useState(false)
  const [deleting, setDeleting] = useState<string | null>(null)

  const [addForm, setAddForm] = useState({
    name: '',
    phone: '',
    email: '',
    password: '',
    role: 'seller',
  })

  const [editPermissions, setEditPermissions] = useState<Record<string, boolean>>({})

  const businessId = getBusinessId()

  useEffect(() => {
    loadUsers()
  }, [businessId])

  const loadUsers = async () => {
    try {
      const res = await fetch(`/api/business-users?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setUsers(data)
      }
    } catch {
      toast.error(t('users_load_failed'))
    } finally {
      setLoading(false)
    }
  }

  const handleAddUser = async () => {
    if (!addForm.name || !addForm.password) {
      toast.error(t('users_name_password_required'))
      return
    }

    setSaving(true)
    try {
      const permissions = defaultPermissions[addForm.role] || null
      const res = await fetch('/api/business-users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: addForm.name,
          phone: addForm.phone || undefined,
          email: addForm.email || undefined,
          password: addForm.password,
          role: addForm.role,
          permissions,
        }),
      })

      if (res.ok) {
        toast.success(t('users_add_success'))
        setShowAddDialog(false)
        setAddForm({ name: '', phone: '', email: '', password: '', role: 'seller' })
        loadUsers()
      } else {
        const err = await res.json()
        toast.error(err.error || t('users_add_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const handleToggleActive = async (user: BusinessUser) => {
    try {
      const res = await fetch(`/api/business-users/${user.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: !user.isActive }),
      })

      if (res.ok) {
        toast.success(user.isActive ? t('users_deactivated') : t('users_activated'))
        loadUsers()
      } else {
        toast.error(t('users_update_status_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    }
  }

  const handleDeleteUser = async (userId: string) => {
    setDeleting(userId)
    try {
      const res = await fetch(`/api/business-users/${userId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('users_delete_success'))
        loadUsers()
      } else {
        toast.error(t('users_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleting(null)
    }
  }

  const handleOpenEdit = (user: BusinessUser) => {
    setEditUser(user)
    setEditPermissions(user.permissions ? { ...user.permissions } : (defaultPermissions[user.role] ? { ...defaultPermissions[user.role] } : {}))
  }

  const handleSavePermissions = async () => {
    if (!editUser) return
    setSaving(true)
    try {
      const res = await fetch(`/api/business-users/${editUser.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ permissions: editPermissions }),
      })

      if (res.ok) {
        toast.success(t('users_permissions_updated'))
        setEditUser(null)
        loadUsers()
      } else {
        toast.error(t('users_permissions_update_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const handleRoleChangeForAdd = (newRole: string) => {
    setAddForm(prev => ({ ...prev, role: newRole }))
  }

  const handleRoleChangeForEdit = async (newRole: string) => {
    if (!editUser) return
    setSaving(true)
    try {
      const newPermissions = defaultPermissions[newRole] || null
      const res = await fetch(`/api/business-users/${editUser.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: newRole, permissions: newPermissions }),
      })

      if (res.ok) {
        toast.success(t('users_role_updated'))
        setEditUser(null)
        loadUsers()
      } else {
        toast.error(t('users_role_update_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-10 w-10 animate-spin text-emerald-600" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight flex items-center gap-2">
            <Shield className="h-6 w-6 text-emerald-600" />
            {t('users_title')}
          </h2>
          <p className="text-muted-foreground">{t('users_subtitle')}</p>
        </div>
        <Button
          onClick={() => setShowAddDialog(true)}
          className="gap-2 bg-emerald-600 hover:bg-emerald-700"
        >
          <Plus className="h-4 w-4" />
          {t('users_add_user')}
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-emerald-600">{users.length}</p>
            <p className="text-xs text-muted-foreground">{t('users_total')}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-amber-600">{users.filter(u => u.role === 'owner').length}</p>
            <p className="text-xs text-muted-foreground">{t('role_owner')}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-sky-600">{users.filter(u => u.role === 'accountant').length}</p>
            <p className="text-xs text-muted-foreground">{t('role_accountant')}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-violet-600">{users.filter(u => u.role === 'seller').length}</p>
            <p className="text-xs text-muted-foreground">{t('role_seller')}</p>
          </CardContent>
        </Card>
      </div>

      {/* Users List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <Users className="h-5 w-5 text-emerald-600" />
            {t('users_list')}
          </CardTitle>
          <CardDescription>
            {t('users_list_desc')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {users.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <Users className="h-12 w-12 mx-auto mb-3 opacity-30" />
              <p className="text-sm">{t('users_no_users')}</p>
              <p className="text-xs mt-1">{t('users_add_hint')}</p>
            </div>
          ) : (
            <div className="space-y-3">
              {users.map((u) => {
                const roleInfo = roleLabelMapKeys[u.role] || roleLabelMapKeys.seller
                const RoleIcon = roleInfo.icon
                return (
                  <div
                    key={u.id}
                    className={`flex items-center gap-4 p-4 rounded-xl border transition ${
                      u.isActive ? 'bg-white' : 'bg-gray-50 opacity-60'
                    }`}
                  >
                    {/* Avatar */}
                    <div className="h-10 w-10 rounded-full bg-emerald-100 flex items-center justify-center shrink-0">
                      <span className="text-emerald-700 font-bold text-sm">
                        {u.name.charAt(0)}
                      </span>
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-medium text-sm">{u.name}</span>
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium border ${roleInfo.color}`}>
                          <RoleIcon className="h-3 w-3" />
                          {t(roleInfo.labelKey)}
                        </span>
                        {!u.isActive && (
                          <Badge className="bg-gray-100 text-gray-500 border-gray-200 text-xs">{t('users_inactive')}</Badge>
                        )}
                      </div>
                      <div className="flex items-center gap-3 mt-1 text-xs text-muted-foreground">
                        {u.phone && (
                          <span className="flex items-center gap-1">
                            <Phone className="h-3 w-3" />
                            {u.phone}
                          </span>
                        )}
                        {u.email && (
                          <span className="flex items-center gap-1">
                            <Mail className="h-3 w-3" />
                            {u.email}
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        className="gap-1 text-xs h-8"
                        onClick={() => handleOpenEdit(u)}
                      >
                        <Edit3 className="h-3 w-3" />
                        {t('edit')}
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        className={`gap-1 text-xs h-8 ${
                          u.isActive
                            ? 'text-amber-600 hover:text-amber-700 border-amber-200'
                            : 'text-emerald-600 hover:text-emerald-700 border-emerald-200'
                        }`}
                        onClick={() => handleToggleActive(u)}
                      >
                        {u.isActive ? (
                          <>
                            <XCircle className="h-3 w-3" />
                            {t('users_deactivate')}
                          </>
                        ) : (
                          <>
                            <CheckCircle2 className="h-3 w-3" />
                            {t('users_activate')}
                          </>
                        )}
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        className="gap-1 text-xs h-8 text-red-600 hover:text-red-700 border-red-200"
                        onClick={() => handleDeleteUser(u.id)}
                        disabled={deleting === u.id}
                      >
                        {deleting === u.id ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <Trash2 className="h-3 w-3" />
                        )}
                        {t('delete')}
                      </Button>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Role Descriptions */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2 mb-2">
              <Crown className="h-5 w-5 text-amber-600" />
              <span className="font-medium">{t('users_owner_label')}</span>
            </div>
            <p className="text-xs text-muted-foreground">
              {t('users_owner_desc')}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2 mb-2">
              <Calculator className="h-5 w-5 text-sky-600" />
              <span className="font-medium">{t('users_accountant_label')}</span>
            </div>
            <p className="text-xs text-muted-foreground">
              {t('users_accountant_desc')}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2 mb-2">
              <Store className="h-5 w-5 text-violet-600" />
              <span className="font-medium">{t('users_seller_label')}</span>
            </div>
            <p className="text-xs text-muted-foreground">
              {t('users_seller_desc')}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Add User Dialog */}
      <Dialog open={showAddDialog} onOpenChange={setShowAddDialog}>
        <DialogContent className="sm:max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Plus className="h-5 w-5 text-emerald-600" />
              {t('users_add_new')}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>{t('name')} *</Label>
              <Input
                value={addForm.name}
                onChange={(e) => setAddForm(prev => ({ ...prev, name: e.target.value }))}
                placeholder={t('users_username_placeholder')}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="flex items-center gap-1.5">
                  <Phone className="h-3.5 w-3.5" />
                  {t('login_phone')}
                </Label>
                <Input
                  value={addForm.phone}
                  onChange={(e) => setAddForm(prev => ({ ...prev, phone: e.target.value }))}
                  placeholder="5XXXXXXXX"
                  dir="ltr"
                />
              </div>
              <div className="space-y-2">
                <Label className="flex items-center gap-1.5">
                  <Mail className="h-3.5 w-3.5" />
                  {t('login_email')}
                </Label>
                <Input
                  type="email"
                  value={addForm.email}
                  onChange={(e) => setAddForm(prev => ({ ...prev, email: e.target.value }))}
                  placeholder="email@example.com"
                  dir="ltr"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label className="flex items-center gap-1.5">
                <Lock className="h-3.5 w-3.5" />
                {t('login_password')} *
              </Label>
              <div className="relative">
                <Input
                  type={showPassword ? 'text' : 'password'}
                  value={addForm.password}
                  onChange={(e) => setAddForm(prev => ({ ...prev, password: e.target.value }))}
                  placeholder={t('users_password_placeholder')}
                  dir="ltr"
                />
                <button
                  type="button"
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('users_role')} *</Label>
              <Select
                value={addForm.role}
                onValueChange={handleRoleChangeForAdd}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {roleOptionKeys.map((opt) => {
                    const OptIcon = opt.icon
                    return (
                      <SelectItem key={opt.value} value={opt.value}>
                        <span className="flex items-center gap-2">
                          <OptIcon className="h-4 w-4" />
                          {t(opt.labelKey)}
                        </span>
                      </SelectItem>
                    )
                  })}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                {t('users_default_perms_note')}
              </p>
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              onClick={() => setShowAddDialog(false)}
            >
              {t('cancel')}
            </Button>
            <Button
              onClick={handleAddUser}
              className="gap-2 bg-emerald-600 hover:bg-emerald-700"
              disabled={saving}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
              {t('add')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit User / Permissions Dialog */}
      <Dialog open={!!editUser} onOpenChange={(open) => { if (!open) setEditUser(null) }}>
        <DialogContent className="sm:max-w-lg max-h-[90vh] overflow-y-auto" dir={dir}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5 text-emerald-600" />
              {t('users_edit_user')}: {editUser?.name}
            </DialogTitle>
          </DialogHeader>
          {editUser && (
            <div className="space-y-6 py-4">
              {/* User Info */}
              <div className="space-y-3">
                <h4 className="font-medium text-sm text-muted-foreground">{t('users_user_info')}</h4>
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <Label className="text-xs">{t('name')}</Label>
                    <p className="text-sm font-medium">{editUser.name}</p>
                  </div>
                  <div className="space-y-1">
                    <Label className="text-xs">{t('phone')}</Label>
                    <p className="text-sm">{editUser.phone || '—'}</p>
                  </div>
                  <div className="space-y-1">
                    <Label className="text-xs">{t('users_email_short')}</Label>
                    <p className="text-sm">{editUser.email || '—'}</p>
                  </div>
                  <div className="space-y-1">
                    <Label className="text-xs">{t('status')}</Label>
                    <Badge className={editUser.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'}>
                      {editUser.isActive ? t('employees_active_yes') : t('users_inactive')}
                    </Badge>
                  </div>
                </div>
              </div>

              <Separator />

              {/* Role Change */}
              <div className="space-y-2">
                <Label>{t('users_role')}</Label>
                <Select
                  value={editUser.role}
                  onValueChange={handleRoleChangeForEdit}
                  disabled={saving}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {roleOptionKeys.map((opt) => {
                      const OptIcon = opt.icon
                      return (
                        <SelectItem key={opt.value} value={opt.value}>
                          <span className="flex items-center gap-2">
                            <OptIcon className="h-4 w-4" />
                            {t(opt.labelKey)}
                          </span>
                        </SelectItem>
                      )
                    })}
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  {t('users_role_change_note')}
                </p>
              </div>

              <Separator />

              {/* Permissions Checkboxes */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label className="text-sm font-medium">{t('users_permissions')}</Label>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      className="text-xs h-7"
                      onClick={() => {
                        const allPerms: Record<string, boolean> = {}
                        permissionItemKeys.forEach(p => { allPerms[p.key] = true })
                        setEditPermissions(allPerms)
                      }}
                    >
                      {t('users_select_all')}
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      className="text-xs h-7"
                      onClick={() => setEditPermissions({})}
                    >
                      {t('users_deselect_all')}
                    </Button>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  {permissionItemKeys.map((perm) => (
                    <label
                      key={perm.key}
                      className={`flex items-center gap-2 p-2.5 rounded-lg border cursor-pointer transition text-sm ${
                        editPermissions[perm.key]
                          ? 'bg-emerald-50 border-emerald-200 text-emerald-700'
                          : 'bg-white border-gray-200 text-gray-500 hover:border-gray-300'
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={!!editPermissions[perm.key]}
                        onChange={(e) => {
                          setEditPermissions(prev => ({
                            ...prev,
                            [perm.key]: e.target.checked,
                          }))
                        }}
                        className="rounded border-gray-300"
                      />
                      <span>{t(perm.labelKey)}</span>
                    </label>
                  ))}
                </div>
              </div>
            </div>
          )}
          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              onClick={() => setEditUser(null)}
            >
              <X className="h-4 w-4 ml-1" />
              {t('cancel')}
            </Button>
            <Button
              onClick={handleSavePermissions}
              className="gap-2 bg-emerald-600 hover:bg-emerald-700"
              disabled={saving}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
              {t('users_save_permissions')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
