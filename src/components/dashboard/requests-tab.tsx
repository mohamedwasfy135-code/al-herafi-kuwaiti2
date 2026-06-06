'use client'

import { useState, useEffect } from 'react'
import {
  ClipboardList,
  Plus,
  Filter,
  Eye,
  Clock,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Loader2,
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { ScrollArea } from '@/components/ui/scroll-area'
import { useLanguage } from '@/lib/language-context'

interface RequestItem {
  id: number
  clientId: string
  serviceType: string | null
  description: string | null
  status: string
  estimatedPrice: number | null
  agreedPrice: number | null
  finalPrice: number | null
  createdAt: string
  client?: { id: string; name: string | null; phone: string | null }
  craftsman?: { id: string; name: string | null } | null
  priceOffers?: { id: number; proposedPrice: number; status: string }[]
}

const statusMap: Record<string, { label: string; color: string }> = {
  pending: { label: 'معلق', color: 'bg-yellow-100 text-yellow-700' },
  notified: { label: 'تم الإبلاغ', color: 'bg-blue-100 text-blue-700' },
  accepted: { label: 'مقبول', color: 'bg-emerald-100 text-emerald-700' },
  in_progress: { label: 'قيد التنفيذ', color: 'bg-sky-100 text-sky-700' },
  done: { label: 'مكتمل', color: 'bg-green-100 text-green-700' },
  rejected: { label: 'مرفوض', color: 'bg-red-100 text-red-700' },
  cancelled: { label: 'ملغي', color: 'bg-gray-100 text-gray-700' },
  no_craftsman: { label: 'بدون حرفي', color: 'bg-orange-100 text-orange-700' },
}

// Sample data for demo
const sampleRequests: RequestItem[] = [
  {
    id: 1024,
    clientId: '1',
    serviceType: 'سباكة',
    description: 'تسريب مياه في المطبخ',
    status: 'in_progress',
    estimatedPrice: 45,
    agreedPrice: 45,
    finalPrice: null,
    createdAt: new Date().toISOString(),
    client: { id: '1', name: 'أحمد محمد', phone: '96612345' },
    craftsman: { id: '2', name: 'خالد العلي' },
  },
  {
    id: 1023,
    clientId: '2',
    serviceType: 'كهرباء',
    description: 'عطل في لوحة الكهرباء',
    status: 'done',
    estimatedPrice: 80,
    agreedPrice: 80,
    finalPrice: 80,
    createdAt: new Date(Date.now() - 86400000).toISOString(),
    client: { id: '2', name: 'فاطمة حسن', phone: '96654321' },
    craftsman: { id: '3', name: 'عمر السيد' },
  },
  {
    id: 1022,
    clientId: '3',
    serviceType: 'دهان',
    description: 'دهان غرفة المعيشة',
    status: 'pending',
    estimatedPrice: 120,
    agreedPrice: null,
    finalPrice: null,
    createdAt: new Date(Date.now() - 86400000).toISOString(),
    client: { id: '3', name: 'محمد عبدالله', phone: '96698765' },
    craftsman: null,
  },
  {
    id: 1021,
    clientId: '4',
    serviceType: 'تكييف',
    description: 'صيانة مكيف سبليت',
    status: 'done',
    estimatedPrice: 65,
    agreedPrice: 65,
    finalPrice: 65,
    createdAt: new Date(Date.now() - 172800000).toISOString(),
    client: { id: '4', name: 'نورة السالم', phone: '96611111' },
    craftsman: { id: '5', name: 'سعد الحربي' },
  },
  {
    id: 1020,
    clientId: '5',
    serviceType: 'نجارة',
    description: 'تصليح دولاب خشبي',
    status: 'in_progress',
    estimatedPrice: 200,
    agreedPrice: 200,
    finalPrice: null,
    createdAt: new Date(Date.now() - 172800000).toISOString(),
    client: { id: '5', name: 'يوسف الشمري', phone: '96622222' },
    craftsman: { id: '6', name: 'علي القحطاني' },
  },
  {
    id: 1019,
    clientId: '6',
    serviceType: 'تنظيف',
    description: 'تنظيف شقة بعد العزل',
    status: 'pending',
    estimatedPrice: 30,
    agreedPrice: null,
    finalPrice: null,
    createdAt: new Date(Date.now() - 259200000).toISOString(),
    client: { id: '6', name: 'هند المطيري', phone: '96633333' },
    craftsman: null,
  },
]

export function RequestsTab() {
  const { t, lang, dir } = useLanguage()
  const [requests, setRequests] = useState<RequestItem[]>(sampleRequests)
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [selectedRequest, setSelectedRequest] = useState<RequestItem | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    async function fetchRequests() {
      setLoading(true)
      try {
        const params = new URLSearchParams()
        if (statusFilter !== 'all') params.set('status', statusFilter)
        const res = await fetch(`/api/requests?${params.toString()}`)
        if (res.ok) {
          const data = await res.json()
          if (data.data && data.data.length > 0) {
            setRequests(data.data)
          }
        }
      } catch {
        // Keep sample data on error
      } finally {
        setLoading(false)
      }
    }
    fetchRequests()
  }, [statusFilter])

  const filteredRequests =
    statusFilter === 'all'
      ? requests
      : requests.filter((r) => r.status === statusFilter)

  const getStatusBadge = (status: string) => {
    const s = statusMap[status] || { label: status, color: 'bg-gray-100 text-gray-700' }
    return (
      <Badge variant="secondary" className={`text-xs ${s.color}`}>
        {s.label}
      </Badge>
    )
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'pending':
        return <Clock className="h-4 w-4 text-yellow-600" />
      case 'done':
        return <CheckCircle2 className="h-4 w-4 text-green-600" />
      case 'rejected':
      case 'cancelled':
        return <XCircle className="h-4 w-4 text-red-600" />
      default:
        return <AlertCircle className="h-4 w-4 text-sky-600" />
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">الطلبات</h2>
          <p className="text-muted-foreground">إدارة ومتابعة طلبات الخدمة</p>
        </div>
        <div className="flex items-center gap-3">
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-40">
              <Filter className="ml-2 h-4 w-4" />
              <SelectValue placeholder="فلتر الحالة" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">الكل</SelectItem>
              <SelectItem value="pending">معلق</SelectItem>
              <SelectItem value="accepted">مقبول</SelectItem>
              <SelectItem value="in_progress">قيد التنفيذ</SelectItem>
              <SelectItem value="done">مكتمل</SelectItem>
              <SelectItem value="rejected">مرفوض</SelectItem>
              <SelectItem value="cancelled">ملغي</SelectItem>
            </SelectContent>
          </Select>
          <Button className="gap-2 bg-emerald-600 hover:bg-emerald-700">
            <Plus className="h-4 w-4" />
            طلب جديد
          </Button>
        </div>
      </div>

      {/* Status summary cards */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-7">
        {Object.entries(statusMap).map(([key, val]) => {
          const count = requests.filter((r) => r.status === key).length
          return (
            <Card
              key={key}
              className={`cursor-pointer transition-colors ${
                statusFilter === key ? 'ring-2 ring-emerald-500' : ''
              }`}
              onClick={() => setStatusFilter(statusFilter === key ? 'all' : key)}
            >
              <CardContent className="p-3 text-center">
                <p className="text-2xl font-bold">{count}</p>
                <p className="text-xs text-muted-foreground">{val.label}</p>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* Requests Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">رقم الطلب</TableHead>
                    <TableHead className="text-right">العميل</TableHead>
                    <TableHead className="text-right">الخدمة</TableHead>
                    <TableHead className="text-right">الحرفي</TableHead>
                    <TableHead className="text-right">المبلغ</TableHead>
                    <TableHead className="text-right">الحالة</TableHead>
                    <TableHead className="text-right">التاريخ</TableHead>
                    <TableHead className="text-right">إجراء</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredRequests.map((req) => (
                    <TableRow key={req.id} className="cursor-pointer">
                      <TableCell className="font-medium">#{req.id}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Avatar className="h-7 w-7">
                            <AvatarFallback className="bg-gray-100 text-xs">
                              {req.client?.name?.charAt(0) || '؟'}
                            </AvatarFallback>
                          </Avatar>
                          <span className="text-sm">{req.client?.name || '—'}</span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <ClipboardList className="h-3.5 w-3.5 text-muted-foreground" />
                          <span className="text-sm">{req.serviceType || '—'}</span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm text-muted-foreground">
                          {req.craftsman?.name || '—'}
                        </span>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm font-medium">
                          {req.agreedPrice || req.estimatedPrice
                            ? `${req.agreedPrice || req.estimatedPrice} ${t('currency')}`
                            : '—'}
                        </span>
                      </TableCell>
                      <TableCell>{getStatusBadge(req.status)}</TableCell>
                      <TableCell>
                        <span className="text-xs text-muted-foreground">
                          {new Date(req.createdAt).toLocaleDateString('ar-KW')}
                        </span>
                      </TableCell>
                      <TableCell>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8"
                          onClick={() => setSelectedRequest(req)}
                        >
                          <Eye className="h-4 w-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Request Detail Dialog */}
      <Dialog
        open={!!selectedRequest}
        onOpenChange={() => setSelectedRequest(null)}
      >
        <DialogContent className="max-w-lg" dir="rtl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {selectedRequest && getStatusIcon(selectedRequest.status)}
              طلب #{selectedRequest?.id}
            </DialogTitle>
            <DialogDescription>تفاصيل الطلب</DialogDescription>
          </DialogHeader>
          {selectedRequest && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-muted-foreground">العميل</p>
                  <p className="font-medium">{selectedRequest.client?.name || '—'}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">الخدمة</p>
                  <p className="font-medium">{selectedRequest.serviceType || '—'}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">الحرفي</p>
                  <p className="font-medium">{selectedRequest.craftsman?.name || 'لم يحدد'}</p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">الحالة</p>
                  {getStatusBadge(selectedRequest.status)}
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">السعر المقدر</p>
                  <p className="font-medium">
                    {selectedRequest.estimatedPrice ? `${selectedRequest.estimatedPrice} ${t('currency')}` : '—'}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">السعر المتفق عليه</p>
                  <p className="font-medium">
                    {selectedRequest.agreedPrice ? `${selectedRequest.agreedPrice} ${t('currency')}` : '—'}
                  </p>
                </div>
              </div>
              {selectedRequest.description && (
                <div>
                  <p className="text-sm text-muted-foreground">الوصف</p>
                  <p className="text-sm">{selectedRequest.description}</p>
                </div>
              )}
              {selectedRequest.priceOffers && selectedRequest.priceOffers.length > 0 && (
                <div>
                  <p className="text-sm text-muted-foreground mb-2">العروض المقدمة</p>
                  {selectedRequest.priceOffers.map((offer) => (
                    <div
                      key={offer.id}
                      className="flex items-center justify-between rounded-lg border p-2 mb-1"
                    >
                      <span className="text-sm">{offer.proposedPrice} {t('currency')}</span>
                      <Badge variant="outline" className="text-xs">
                        {offer.status === 'pending' ? 'معلق' : offer.status === 'accepted' ? 'مقبول' : 'مرفوض'}
                      </Badge>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
