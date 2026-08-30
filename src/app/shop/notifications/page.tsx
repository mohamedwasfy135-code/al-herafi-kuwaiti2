'use client'

import { useState, useEffect, useCallback } from 'react'
import { useLanguage } from '@/lib/language-context'
import { getBusinessId } from '@/lib/shop-utils'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Bell,
  MessageCircle,
  Clock,
  BarChart3,
  Brain,
  Package,
  TrendingUp,
  Send,
  RefreshCw,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Loader2,
  FileText,
  CalendarDays,
  BadgeDollarSign,
  BookOpen,
} from 'lucide-react'
import { useToast } from '@/hooks/use-toast'

interface NotificationLog {
  id: number
  type: string
  channel: string
  recipient: string
  title: string
  message: string | null
  status: string
  sentAt: string | null
  createdAt: string
}

interface DailyReport {
  businessName: string
  date: string
  sales: { total: number; paid: number; remaining: number; invoiceCount: number; unpaidCount: number }
  purchases: { total: number }
  expenses: { total: number }
  bonds: { receiptTotal: number; paymentTotal: number; net: number }
  netCashFlow: number
  lowStockAlerts: { name: string; stockQuantity: number; lowStockThreshold: number }[]
}

export default function NotificationsPage() {
  const { t, lang, dir } = useLanguage()
  const { toast } = useToast()

  // Settings state
  const [whatsappPhone, setWhatsappPhone] = useState('')
  const [dailyTime, setDailyTime] = useState('21')
  const [weeklyDay, setWeeklyDay] = useState('sunday')
  const [monthlyDate, setMonthlyDate] = useState('1')

  // Enable/disable toggles
  const [dailySalesEnabled, setDailySalesEnabled] = useState(true)
  const [dailyExpensesEnabled, setDailyExpensesEnabled] = useState(true)
  const [ledgerBalanceEnabled, setLedgerBalanceEnabled] = useState(true)
  const [weeklyEnabled, setWeeklyEnabled] = useState(true)
  const [monthlyEnabled, setMonthlyEnabled] = useState(true)
  const [aiEnabled, setAiEnabled] = useState(false)

  // AI settings
  const [aiRecommendations, setAiRecommendations] = useState(true)
  const [inventoryAlerts, setInventoryAlerts] = useState(true)
  const [salesTrends, setSalesTrends] = useState(true)

  // Data state
  const [report, setReport] = useState<DailyReport | null>(null)
  const [waMessage, setWaMessage] = useState('')
  const [notificationLogs, setNotificationLogs] = useState<NotificationLog[]>([])
  const [aiInsights, setAiInsights] = useState('')
  const [loading, setLoading] = useState(false)
  const [aiLoading, setAiLoading] = useState(false)
  const [reportLoading, setReportLoading] = useState(false)
  const [logsLoading, setLogsLoading] = useState(false)

  const businessId = getBusinessId()

  // Load settings from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('sana3i_notification_settings')
    if (saved) {
      try {
        const settings = JSON.parse(saved)
        setWhatsappPhone(settings.whatsappPhone || '')
        setDailyTime(settings.dailyTime || '21')
        setWeeklyDay(settings.weeklyDay || 'sunday')
        setMonthlyDate(settings.monthlyDate || '1')
        setDailySalesEnabled(settings.dailySalesEnabled ?? true)
        setDailyExpensesEnabled(settings.dailyExpensesEnabled ?? true)
        setLedgerBalanceEnabled(settings.ledgerBalanceEnabled ?? true)
        setWeeklyEnabled(settings.weeklyEnabled ?? true)
        setMonthlyEnabled(settings.monthlyEnabled ?? true)
        setAiEnabled(settings.aiEnabled ?? false)
        setAiRecommendations(settings.aiRecommendations ?? true)
        setInventoryAlerts(settings.inventoryAlerts ?? true)
        setSalesTrends(settings.salesTrends ?? true)
      } catch { /* ignore */ }
    }
  }, [])

  // Save settings
  const saveSettings = useCallback(() => {
    const settings = {
      whatsappPhone, dailyTime, weeklyDay, monthlyDate,
      dailySalesEnabled, dailyExpensesEnabled, ledgerBalanceEnabled,
      weeklyEnabled, monthlyEnabled, aiEnabled,
      aiRecommendations, inventoryAlerts, salesTrends,
    }
    localStorage.setItem('sana3i_notification_settings', JSON.stringify(settings))
    toast({ title: t('success'), description: t('save_changes') })
  }, [whatsappPhone, dailyTime, weeklyDay, monthlyDate, dailySalesEnabled, dailyExpensesEnabled, ledgerBalanceEnabled, weeklyEnabled, monthlyEnabled, aiEnabled, aiRecommendations, inventoryAlerts, salesTrends, t, toast])

  // Generate daily report
  const generateDailyReport = async () => {
    if (!businessId) return
    setReportLoading(true)
    try {
      const res = await fetch(`/api/notifications/daily-report?businessId=${businessId}&date=${new Date().toISOString().split('T')[0]}`)
      const data = await res.json()
      if (data.report) {
        setReport(data.report)
        setWaMessage(data.waMessage)
      }
    } catch (error) {
      console.error('Error generating report:', error)
    } finally {
      setReportLoading(false)
    }
  }

  // Send test WhatsApp message
  const sendTestMessage = async () => {
    if (!businessId || !whatsappPhone) {
      toast({ title: t('error'), description: t('required'), variant: 'destructive' })
      return
    }
    setLoading(true)
    try {
      const testMsg = t('notifications_test_wa_message')

      const res = await fetch('/api/notifications/whatsapp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId, phone: whatsappPhone, message: testMsg, type: 'alert' }),
      })
      const data = await res.json()
      if (data.waMeLink) {
        window.open(data.waMeLink, '_blank')
        toast({ title: t('notifications_test_sent') })
      }
    } catch {
      toast({ title: t('error'), variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }

  // Send daily report via WhatsApp
  const sendDailyReport = async () => {
    if (!businessId || !whatsappPhone) {
      toast({ title: t('error'), description: t('required'), variant: 'destructive' })
      return
    }
    if (!waMessage) {
      await generateDailyReport()
    }
    setLoading(true)
    try {
      const msg = waMessage || t('notifications_daily_report_short')
      const res = await fetch('/api/notifications/whatsapp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId, phone: whatsappPhone, message: msg, type: 'daily_report' }),
      })
      const data = await res.json()
      if (data.waMeLink) {
        window.open(data.waMeLink, '_blank')
        toast({ title: t('notifications_report_generated') })
      }
    } catch {
      toast({ title: t('error'), variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }

  // Generate AI report
  const generateAIReport = async (period: 'weekly' | 'monthly') => {
    if (!businessId) return
    setAiLoading(true)
    try {
      const res = await fetch('/api/notifications/ai-report', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId, period }),
      })
      const data = await res.json()
      if (data.insights) {
        setAiInsights(data.insights)
      }
    } catch {
      toast({ title: t('error'), variant: 'destructive' })
    } finally {
      setAiLoading(false)
    }
  }

  // Send AI report via WhatsApp
  const sendAIReport = async () => {
    if (!businessId || !whatsappPhone || !aiInsights) {
      toast({ title: t('error'), description: t('required'), variant: 'destructive' })
      return
    }
    setLoading(true)
    try {
      const res = await fetch('/api/notifications/whatsapp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId, phone: whatsappPhone, message: aiInsights, type: 'ai_analysis' }),
      })
      const data = await res.json()
      if (data.waMeLink) {
        window.open(data.waMeLink, '_blank')
        toast({ title: t('notifications_report_generated') })
      }
    } catch {
      toast({ title: t('error'), variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }

  // Load notification logs
  const loadLogs = useCallback(async () => {
    if (!businessId) return
    setLogsLoading(true)
    try {
      const res = await fetch(`/api/notifications?businessId=${businessId}&limit=20`)
      const data = await res.json()
      if (data.logs) {
        setNotificationLogs(data.logs)
      }
    } catch (error) {
      console.error('Error loading logs:', error)
    } finally {
      setLogsLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    loadLogs()
  }, [loadLogs])

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'sent': return <CheckCircle2 className="h-4 w-4 text-emerald-500" />
      case 'pending': return <Clock className="h-4 w-4 text-amber-500" />
      case 'failed': return <XCircle className="h-4 w-4 text-red-500" />
      default: return <Clock className="h-4 w-4 text-gray-600" />
    }
  }

  const getStatusBadge = (status: string) => {
    const variants: Record<string, 'default' | 'secondary' | 'destructive' | 'outline'> = {
      sent: 'default', pending: 'secondary', failed: 'destructive',
    }
    return <Badge variant={variants[status] || 'outline'} className="text-xs">
      {status === 'sent' ? t('notifications_sent') : status === 'pending' ? t('notifications_pending') : t('notifications_failed')}
    </Badge>
  }

  const getTypeLabel = (type: string) => {
    const map: Record<string, string> = {
      daily_report: t('notifications_daily_report'),
      weekly_report: t('notifications_weekly_report'),
      monthly_report: t('notifications_monthly_report'),
      ai_analysis: t('notifications_ai_analysis'),
      alert: t('warning'),
    }
    return map[type] || type
  }

  const days = [
    { value: 'sunday', label: t('day_sunday') },
    { value: 'monday', label: t('day_monday') },
    { value: 'tuesday', label: t('day_tuesday') },
    { value: 'wednesday', label: t('day_wednesday') },
    { value: 'thursday', label: t('day_thursday') },
  ]

  return (
    <div className="space-y-6" dir={dir}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Bell className="h-6 w-6 text-emerald-600" />
            {t('notifications_title')}
          </h1>
          <p className="text-sm text-gray-700 mt-1">
            {t('notifications_whatsapp')} &amp; {t('notifications_ai_analysis')}
          </p>
        </div>
        <Button onClick={saveSettings} className="bg-emerald-600 hover:bg-emerald-700">
          {t('save_changes')}
        </Button>
      </div>

      <Tabs defaultValue="whatsapp" className="space-y-4">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="whatsapp" className="gap-1.5">
            <MessageCircle className="h-4 w-4" />
            <span className="hidden sm:inline">{t('notifications_whatsapp')}</span>
          </TabsTrigger>
          <TabsTrigger value="schedule" className="gap-1.5">
            <Clock className="h-4 w-4" />
            <span className="hidden sm:inline">{t('notifications_schedule')}</span>
          </TabsTrigger>
          <TabsTrigger value="ai" className="gap-1.5">
            <Brain className="h-4 w-4" />
            <span className="hidden sm:inline">{t('notifications_ai_settings')}</span>
          </TabsTrigger>
          <TabsTrigger value="history" className="gap-1.5">
            <FileText className="h-4 w-4" />
            <span className="hidden sm:inline">{t('notifications_history')}</span>
          </TabsTrigger>
        </TabsList>

        {/* WhatsApp Integration Tab */}
        <TabsContent value="whatsapp" className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {/* WhatsApp Settings Card */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <MessageCircle className="h-5 w-5 text-emerald-600" />
                  {t('notifications_whatsapp')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label>{t('notifications_phone_number')}</Label>
                  <div className="flex gap-2">
                    <Input
                      placeholder="+965 5XXX XXXX"
                      value={whatsappPhone}
                      onChange={(e) => setWhatsappPhone(e.target.value)}
                      className="flex-1"
                      dir="ltr"
                    />
                    <Button onClick={sendTestMessage} disabled={loading || !whatsappPhone} variant="outline" className="shrink-0">
                      {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                      <span className="ms-1.5 hidden sm:inline">{t('notifications_test_message')}</span>
                    </Button>
                  </div>
                </div>

                <Separator />

                <div className="space-y-3">
                  <Label className="text-base font-medium">{t('notifications_connection_status')}</Label>
                  <div className="flex items-center gap-2">
                    <div className={`h-3 w-3 rounded-full ${whatsappPhone ? 'bg-emerald-500' : 'bg-gray-300'}`} />
                    <span className="text-sm">
                      {whatsappPhone ? t('notifications_connected') : t('notifications_disconnected')}
                    </span>
                  </div>
                </div>

                <Separator />

                <div className="space-y-3">
                  <Label className="text-base font-medium">{t('notifications_report_types')}</Label>
                  
                  <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                    <div className="flex items-center gap-2">
                      <BarChart3 className="h-4 w-4 text-emerald-600" />
                      <span className="text-sm">{t('notifications_daily_sales')}</span>
                    </div>
                    <Switch checked={dailySalesEnabled} onCheckedChange={setDailySalesEnabled} />
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                    <div className="flex items-center gap-2">
                      <BadgeDollarSign className="h-4 w-4 text-orange-600" />
                      <span className="text-sm">{t('notifications_daily_expenses')}</span>
                    </div>
                    <Switch checked={dailyExpensesEnabled} onCheckedChange={setDailyExpensesEnabled} />
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                    <div className="flex items-center gap-2">
                      <BookOpen className="h-4 w-4 text-teal-600" />
                      <span className="text-sm">{t('notifications_ledger_balance')}</span>
                    </div>
                    <Switch checked={ledgerBalanceEnabled} onCheckedChange={setLedgerBalanceEnabled} />
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                    <div className="flex items-center gap-2">
                      <CalendarDays className="h-4 w-4 text-violet-600" />
                      <span className="text-sm">{t('notifications_weekly_report')}</span>
                    </div>
                    <Switch checked={weeklyEnabled} onCheckedChange={setWeeklyEnabled} />
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                    <div className="flex items-center gap-2">
                      <FileText className="h-4 w-4 text-rose-600" />
                      <span className="text-sm">{t('notifications_monthly_report')}</span>
                    </div>
                    <Switch checked={monthlyEnabled} onCheckedChange={setMonthlyEnabled} />
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Daily Report Preview Card */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <FileText className="h-5 w-5 text-emerald-600" />
                  {t('notifications_daily_report')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex gap-2">
                  <Button onClick={generateDailyReport} disabled={reportLoading} variant="outline" className="flex-1">
                    {reportLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
                    <span className="ms-1.5">{t('notifications_generate_report')}</span>
                  </Button>
                  <Button onClick={sendDailyReport} disabled={loading || !whatsappPhone || !waMessage} className="flex-1 bg-emerald-600 hover:bg-emerald-700">
                    {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <MessageCircle className="h-4 w-4" />}
                    <span className="ms-1.5">{t('notifications_open_whatsapp')}</span>
                  </Button>
                </div>

                {report && (
                  <div className="space-y-3">
                    <div className="grid grid-cols-2 gap-3">
                      <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800">
                        <p className="text-xs text-gray-700">{t('dashboard_total_revenue')}</p>
                        <p className="text-lg font-bold text-emerald-700">{report.sales.total.toFixed(3)} {t('currency')}</p>
                      </div>
                      <div className="p-3 rounded-lg bg-orange-50 dark:bg-orange-950/30 border border-orange-200 dark:border-orange-800">
                        <p className="text-xs text-gray-700">{t('dashboard_total_expenses')}</p>
                        <p className="text-lg font-bold text-orange-700">{report.expenses.total.toFixed(3)} {t('currency')}</p>
                      </div>
                      <div className="p-3 rounded-lg bg-teal-50 dark:bg-teal-950/30 border border-teal-200 dark:border-teal-800">
                        <p className="text-xs text-gray-700">{t('finance_purchases')}</p>
                        <p className="text-lg font-bold text-teal-700">{report.purchases.total.toFixed(3)} {t('currency')}</p>
                      </div>
                      <div className="p-3 rounded-lg bg-violet-50 dark:bg-violet-950/30 border border-violet-200 dark:border-violet-800">
                        <p className="text-xs text-gray-700">{t('notifications_daily_net_cash')}</p>
                        <p className={`text-lg font-bold ${report.netCashFlow >= 0 ? 'text-emerald-700' : 'text-red-700'}`}>
                          {report.netCashFlow.toFixed(3)} {t('currency')}
                        </p>
                      </div>
                    </div>

                    {report.lowStockAlerts.length > 0 && (
                      <div className="p-3 rounded-lg bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800">
                        <p className="text-xs font-medium text-amber-700 mb-1 flex items-center gap-1">
                          <AlertTriangle className="h-3.5 w-3.5" />
                          {t('notifications_low_stock_alerts')}
                        </p>
                        <div className="space-y-1">
                          {report.lowStockAlerts.map((p, i) => (
                            <p key={i} className="text-xs text-amber-600">{p.name}: {p.stockQuantity} {t('quantity')}</p>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Schedule Tab */}
        <TabsContent value="schedule" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Clock className="h-4 w-4 text-emerald-600" />
                  {t('notifications_daily_report')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label>{t('notifications_enabled')}</Label>
                  <Switch checked={dailySalesEnabled} onCheckedChange={setDailySalesEnabled} />
                </div>
                <div className="space-y-1.5">
                  <Label>{t('notifications_send_time')}</Label>
                  <Select value={dailyTime} onValueChange={setDailyTime}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {Array.from({ length: 24 }, (_, i) => i).map(h => (
                        <SelectItem key={h} value={String(h)}>{String(h).padStart(2, '0')}:00</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <CalendarDays className="h-4 w-4 text-violet-600" />
                  {t('notifications_weekly_report')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label>{t('notifications_enabled')}</Label>
                  <Switch checked={weeklyEnabled} onCheckedChange={setWeeklyEnabled} />
                </div>
                <div className="space-y-1.5">
                  <Label>{t('notifications_weekly_day')}</Label>
                  <Select value={weeklyDay} onValueChange={setWeeklyDay}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {days.map(d => (
                        <SelectItem key={d.value} value={d.value}>{d.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <FileText className="h-4 w-4 text-rose-600" />
                  {t('notifications_monthly_report')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label>{t('notifications_enabled')}</Label>
                  <Switch checked={monthlyEnabled} onCheckedChange={setMonthlyEnabled} />
                </div>
                <div className="space-y-1.5">
                  <Label>{t('notifications_monthly_date')}</Label>
                  <Select value={monthlyDate} onValueChange={setMonthlyDate}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {Array.from({ length: 28 }, (_, i) => i + 1).map(d => (
                        <SelectItem key={d} value={String(d)}>{d}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* AI Settings Tab */}
        <TabsContent value="ai" className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Brain className="h-5 w-5 text-emerald-600" />
                  {t('notifications_ai_settings')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                  <div>
                    <p className="font-medium text-sm">{t('notifications_ai_analysis')}</p>
                    <p className="text-xs text-gray-700">{t('notifications_ai_recommendations')}</p>
                  </div>
                  <Switch checked={aiEnabled} onCheckedChange={setAiEnabled} />
                </div>

                <Separator />

                <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                  <div className="flex items-center gap-2">
                    <Brain className="h-4 w-4 text-violet-600" />
                    <span className="text-sm">{t('notifications_ai_recommendations')}</span>
                  </div>
                  <Switch checked={aiRecommendations} onCheckedChange={setAiRecommendations} disabled={!aiEnabled} />
                </div>

                <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                  <div className="flex items-center gap-2">
                    <Package className="h-4 w-4 text-orange-600" />
                    <span className="text-sm">{t('notifications_inventory_alerts')}</span>
                  </div>
                  <Switch checked={inventoryAlerts} onCheckedChange={setInventoryAlerts} disabled={!aiEnabled} />
                </div>

                <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-900">
                  <div className="flex items-center gap-2">
                    <TrendingUp className="h-4 w-4 text-teal-600" />
                    <span className="text-sm">{t('notifications_sales_trends')}</span>
                  </div>
                  <Switch checked={salesTrends} onCheckedChange={setSalesTrends} disabled={!aiEnabled} />
                </div>
              </CardContent>
            </Card>

            {/* AI Report Card */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <BarChart3 className="h-5 w-5 text-emerald-600" />
                  {t('notifications_ai_analysis')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex gap-2">
                  <Button onClick={() => generateAIReport('weekly')} disabled={aiLoading} variant="outline" className="flex-1">
                    {aiLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <CalendarDays className="h-4 w-4" />}
                    <span className="ms-1.5">{t('notifications_weekly_report')}</span>
                  </Button>
                  <Button onClick={() => generateAIReport('monthly')} disabled={aiLoading} variant="outline" className="flex-1">
                    {aiLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <FileText className="h-4 w-4" />}
                    <span className="ms-1.5">{t('notifications_monthly_report')}</span>
                  </Button>
                </div>

                {aiInsights && (
                  <div className="space-y-3">
                    <ScrollArea className="h-72">
                      <div className="prose prose-sm dark:prose-invert max-w-none whitespace-pre-wrap text-sm leading-relaxed">
                        {aiInsights}
                      </div>
                    </ScrollArea>
                    <Button onClick={sendAIReport} disabled={loading || !whatsappPhone} className="w-full bg-emerald-600 hover:bg-emerald-700">
                      {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <MessageCircle className="h-4 w-4" />}
                      <span className="ms-1.5">{t('notifications_send_ai_report')}</span>
                    </Button>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* History Tab */}
        <TabsContent value="history" className="space-y-4">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <FileText className="h-5 w-5 text-emerald-600" />
                  {t('notifications_history')}
                </CardTitle>
                <Button variant="outline" size="sm" onClick={loadLogs} disabled={logsLoading}>
                  {logsLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {notificationLogs.length === 0 ? (
                <div className="text-center py-8">
                  <Bell className="h-12 w-12 text-gray-700 mx-auto mb-3" />
                  <p className="text-gray-700">{t('notifications_no_notifications')}</p>
                </div>
              ) : (
                <ScrollArea className="max-h-96">
                  <div className="space-y-2">
                    {notificationLogs.map((log) => (
                      <div key={log.id} className="flex items-center justify-between p-3 rounded-lg border bg-white dark:bg-gray-900">
                        <div className="flex items-center gap-3 min-w-0 flex-1">
                          {getStatusIcon(log.status)}
                          <div className="min-w-0 flex-1">
                            <p className="text-sm font-medium truncate">{log.title}</p>
                            <p className="text-xs text-gray-700">
                              {getTypeLabel(log.type)} • {new Date(log.createdAt).toLocaleDateString(lang === 'ar' ? 'ar-KW' : 'en-US')}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-2 shrink-0">
                          {getStatusBadge(log.status)}
                          <Badge variant="outline" className="text-xs">
                            {log.channel === 'whatsapp' ? t('notifications_whatsapp') : log.channel}
                          </Badge>
                        </div>
                      </div>
                    ))}
                  </div>
                </ScrollArea>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}
