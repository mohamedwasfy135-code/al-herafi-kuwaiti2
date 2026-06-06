'use client'

import { useState, useEffect, useCallback } from 'react'
import { useLanguage } from '@/lib/language-context'
import { getBusinessId } from '@/lib/shop-utils'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible'
import {
  Shield,
  Search,
  ChevronDown,
  ChevronLeft,
  RefreshCw,
  Loader2,
  Plus,
  Edit,
  Trash2,
  CreditCard,
  GitMerge,
  Download,
  Upload,
} from 'lucide-react'

interface AuditLogEntry {
  id: number
  businessId: string
  userId: string | null
  action: string
  entity: string
  entityId: number | null
  changes: { before?: unknown; after?: unknown } | null
  ipAddress: string | null
  userAgent: string | null
  createdAt: string
  user: { id: string; name: string; email: string | null } | null
}

const actionColors: Record<string, string> = {
  CREATE: 'bg-green-100 text-green-700 border-green-200',
  UPDATE: 'bg-blue-100 text-blue-700 border-blue-200',
  DELETE: 'bg-red-100 text-red-700 border-red-200',
  PAY: 'bg-amber-100 text-amber-700 border-amber-200',
  MERGE: 'bg-purple-100 text-purple-700 border-purple-200',
  EXPORT: 'bg-cyan-100 text-cyan-700 border-cyan-200',
  IMPORT: 'bg-orange-100 text-orange-700 border-orange-200',
}

const actionIcons: Record<string, React.ElementType> = {
  CREATE: Plus,
  UPDATE: Edit,
  DELETE: Trash2,
  PAY: CreditCard,
  MERGE: GitMerge,
  EXPORT: Download,
  IMPORT: Upload,
}

const actionTypes = ['CREATE', 'UPDATE', 'DELETE', 'PAY', 'MERGE', 'EXPORT', 'IMPORT']
const entityTypes = ['Product', 'SalesInvoice', 'PurchaseInvoice', 'Bond', 'Salary', 'Rent', 'Backup', 'Offer', 'Account', 'Employee', 'Client', 'Supplier']

export default function AuditLogPage() {
  const { t, lang, dir } = useLanguage()
  const businessId = getBusinessId()

  const [logs, setLogs] = useState<AuditLogEntry[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [actionFilter, setActionFilter] = useState<string>('all')
  const [entityFilter, setEntityFilter] = useState<string>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [expandedRows, setExpandedRows] = useState<Set<number>>(new Set())

  const fetchLogs = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({
        businessId,
        page: String(page),
        limit: '25',
      })
      if (actionFilter !== 'all') params.set('action', actionFilter)
      if (entityFilter !== 'all') params.set('entity', entityFilter)
      if (searchQuery) params.set('search', searchQuery)

      const res = await fetch(`/api/audit-logs?${params}`)
      const data = await res.json()

      setLogs(data.logs || [])
      setTotal(data.total || 0)
    } catch (error) {
      console.error('Failed to fetch audit logs:', error)
    } finally {
      setLoading(false)
    }
  }, [businessId, page, actionFilter, entityFilter, searchQuery])

  useEffect(() => {
    fetchLogs()
  }, [fetchLogs])

  const toggleRow = (id: number) => {
    setExpandedRows((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const totalPages = Math.ceil(total / 25)

  const formatAction = (action: string) => {
    const map: Record<string, { ar: string; en: string }> = {
      CREATE: { ar: 'إنشاء', en: 'Create' },
      UPDATE: { ar: 'تحديث', en: 'Update' },
      DELETE: { ar: 'حذف', en: 'Delete' },
      PAY: { ar: 'دفع', en: 'Pay' },
      MERGE: { ar: 'دمج', en: 'Merge' },
      EXPORT: { ar: 'تصدير', en: 'Export' },
      IMPORT: { ar: 'استيراد', en: 'Import' },
    }
    return map[action]?.[lang === 'ar' ? 'ar' : 'en'] || action
  }

  return (
    <div className="space-y-6" dir={dir}>
      <div className="flex items-center gap-3">
        <div className="p-2 bg-emerald-100 rounded-lg">
          <Shield className="h-6 w-6 text-emerald-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t('audit_title')}</h1>
        </div>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-wrap gap-3 items-center">
            <div className="relative flex-1 min-w-[200px]">
              <Search className="absolute start-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder={t('search')}
                value={searchQuery}
                onChange={(e) => { setSearchQuery(e.target.value); setPage(1) }}
                className="ps-9"
              />
            </div>
            <Select value={actionFilter} onValueChange={(v) => { setActionFilter(v); setPage(1) }}>
              <SelectTrigger className="w-[150px]">
                <SelectValue placeholder={t('audit_action')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('all')}</SelectItem>
                {actionTypes.map((action) => (
                  <SelectItem key={action} value={action}>{formatAction(action)}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={entityFilter} onValueChange={(v) => { setEntityFilter(v); setPage(1) }}>
              <SelectTrigger className="w-[150px]">
                <SelectValue placeholder={t('audit_entity')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('all')}</SelectItem>
                {entityTypes.map((entity) => (
                  <SelectItem key={entity} value={entity}>{entity}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button variant="outline" size="sm" onClick={fetchLogs}>
              <RefreshCw className="h-4 w-4 me-1" />
              {t('refresh')}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Logs Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-16">
              <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
              <span className="ms-2 text-gray-500">{t('loading')}</span>
            </div>
          ) : logs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-gray-400">
              <Shield className="h-12 w-12 mb-3" />
              <p>{t('audit_no_entries')}</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('date')}</TableHead>
                  <TableHead>{t('audit_action')}</TableHead>
                  <TableHead>{t('audit_entity')}</TableHead>
                  <TableHead className="hidden md:table-cell">ID</TableHead>
                  <TableHead className="hidden md:table-cell">{t('audit_user')}</TableHead>
                  <TableHead>{t('audit_changes')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {logs.map((log) => {
                  const ActionIcon = actionIcons[log.action] || Shield
                  const isExpanded = expandedRows.has(log.id)

                  return (
                    <Collapsible key={log.id} open={isExpanded} onOpenChange={() => toggleRow(log.id)}>
                      <TableRow className="hover:bg-gray-50 cursor-pointer" onClick={() => toggleRow(log.id)}>
                        <TableCell className="text-xs whitespace-nowrap">
                          {new Date(log.createdAt).toLocaleString(lang === 'ar' ? 'ar-KW' : 'en-US')}
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline" className={`${actionColors[log.action] || 'bg-gray-100 text-gray-700'} text-xs`}>
                            <ActionIcon className="h-3 w-3 me-1" />
                            {formatAction(log.action)}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-sm font-medium">{log.entity}</TableCell>
                        <TableCell className="hidden md:table-cell text-xs text-gray-500">{log.entityId || '-'}</TableCell>
                        <TableCell className="hidden md:table-cell text-sm">{log.user?.name || '-'}</TableCell>
                        <TableCell>
                          <CollapsibleTrigger asChild>
                            <Button variant="ghost" size="sm" className="h-6 px-2">
                              {isExpanded ? <ChevronDown className="h-3 w-3" /> : <ChevronLeft className="h-3 w-3" />}
                            </Button>
                          </CollapsibleTrigger>
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell colSpan={6} className="p-0 border-0">
                          <CollapsibleContent>
                            <div className="px-4 py-3 bg-gray-50 border-b">
                              {log.changes ? (
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                  {log.changes.before != null && (
                                    <div>
                                      <p className="text-xs font-medium text-red-600 mb-1">
                                        {t('audit_before')}:
                                      </p>
                                      <pre className="text-xs bg-red-50 p-2 rounded border border-red-200 max-h-40 overflow-auto">
                                        {JSON.stringify(log.changes.before, null, 2)}
                                      </pre>
                                    </div>
                                  )}
                                  {log.changes.after != null && (
                                    <div>
                                      <p className="text-xs font-medium text-green-600 mb-1">
                                        {t('audit_after')}:
                                      </p>
                                      <pre className="text-xs bg-green-50 p-2 rounded border border-green-200 max-h-40 overflow-auto">
                                        {JSON.stringify(log.changes.after, null, 2)}
                                      </pre>
                                    </div>
                                  )}
                                </div>
                              ) : (
                                <p className="text-xs text-gray-400">{t('audit_no_changes')}</p>
                              )}
                              {log.ipAddress && (
                                <p className="text-xs text-gray-400 mt-2">IP: {log.ipAddress}</p>
                              )}
                            </div>
                          </CollapsibleContent>
                        </TableCell>
                      </TableRow>
                    </Collapsible>
                  )
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-gray-500">
            {t('audit_page')} {page} {t('audit_of')} {totalPages}
            <span className="mx-2">|</span>
            {total} {t('audit_records')}
          </p>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              {t('audit_previous')}
            </Button>
            <Button
              variant="outline"
              size="sm"
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              {t('audit_next')}
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
