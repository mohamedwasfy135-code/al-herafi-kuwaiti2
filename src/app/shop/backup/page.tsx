'use client'

import { useState, useEffect, useCallback } from 'react'
import { useLanguage } from '@/lib/language-context'
import { getBusinessId } from '@/lib/shop-utils'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Progress } from '@/components/ui/progress'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import {
  Download,
  Upload,
  Shield,
  FileJson,
  Clock,
  AlertTriangle,
  CheckCircle2,
  Loader2,
  Database,
} from 'lucide-react'

interface BackupStats {
  products: number
  productCategories: number
  warehouses: number
  suppliers: number
  employees: number
  salaries: number
  rents: number
  accounts: number
  transactions: number
  salesInvoices: number
  purchaseInvoices: number
  salesReturns: number
  purchaseReturns: number
  bonds: number
  expenses: number
  businessClients: number
  offers: number
  productMovements: number
  shareholders: number
  shareholderTransactions: number
}

interface BackupData {
  version: string
  exportedAt: string
  business: { id: string; name: string; nameEn?: string }
  data: Record<string, unknown>
  stats: BackupStats
}

export default function BackupPage() {
  const { t, lang, dir } = useLanguage()
  const businessId = getBusinessId()

  const [exporting, setExporting] = useState(false)
  const [importing, setImporting] = useState(false)
  const [importProgress, setImportProgress] = useState(0)
  const [lastExport, setLastExport] = useState<string | null>(null)
  const [importFile, setImportFile] = useState<BackupData | null>(null)
  const [importFileName, setImportFileName] = useState('')
  const [showConfirmDialog, setShowConfirmDialog] = useState(false)
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  useEffect(() => {
    const saved = localStorage.getItem('sana3i_last_export')
    if (saved) setLastExport(saved)
  }, [])

  const handleExport = useCallback(async () => {
    setExporting(true)
    setMessage(null)
    try {
      const response = await fetch(`/api/backup/export?businessId=${businessId}`)
      if (!response.ok) {
        const err = await response.json()
        throw new Error(err.error || 'Export failed')
      }

      const data = await response.json()
      const jsonStr = JSON.stringify(data, null, 2)

      // Create download
      const blob = new Blob([jsonStr], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `sana3i-backup-${data.business?.name || 'unknown'}-${new Date().toISOString().split('T')[0]}.json`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)

      const now = new Date().toISOString()
      localStorage.setItem('sana3i_last_export', now)
      setLastExport(now)

      setMessage({ type: 'success', text: t('backup_export_success') })
    } catch (error) {
      setMessage({ type: 'error', text: error instanceof Error ? error.message : 'Export failed' })
    } finally {
      setExporting(false)
    }
  }, [businessId, t])

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setImportFileName(file.name)
    const reader = new FileReader()
    reader.onload = (ev) => {
      try {
        const data = JSON.parse(ev.target?.result as string) as BackupData
        if (!data.version || !data.data || !data.stats) {
          setMessage({ type: 'error', text: 'Invalid backup file format' })
          return
        }
        setImportFile(data)
        setMessage(null)
      } catch {
        setMessage({ type: 'error', text: 'Failed to parse backup file' })
      }
    }
    reader.readAsText(file)
  }, [])

  const handleImport = useCallback(async () => {
    if (!importFile) return
    setShowConfirmDialog(false)
    setImporting(true)
    setImportProgress(10)
    setMessage(null)

    try {
      setImportProgress(30)
      const response = await fetch('/api/backup/import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          data: importFile.data,
        }),
      })

      setImportProgress(80)

      if (!response.ok) {
        const err = await response.json()
        throw new Error(err.error || 'Import failed')
      }

      const result = await response.json()
      setImportProgress(100)
      setMessage({
        type: 'success',
        text: `${t('backup_import_success')} (${result.recordsImported} records)`,
      })
      setImportFile(null)
      setImportFileName('')
      // Reset file input
      const fileInput = document.getElementById('import-file') as HTMLInputElement
      if (fileInput) fileInput.value = ''
    } catch (error) {
      setMessage({ type: 'error', text: error instanceof Error ? error.message : 'Import failed' })
    } finally {
      setImporting(false)
      setTimeout(() => setImportProgress(0), 2000)
    }
  }, [businessId, importFile, t])

  const statsEntries = importFile?.stats
    ? Object.entries(importFile.stats).filter(([, v]) => v > 0)
    : []

  return (
    <div className="space-y-6" dir={dir}>
      <div className="flex items-center gap-3">
        <div className="p-2 bg-emerald-100 rounded-lg">
          <Database className="h-6 w-6 text-emerald-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t('backup_title')}</h1>
          <p className="text-sm text-gray-700">{t('backup_title')}</p>
        </div>
      </div>

      {message && (
        <Alert variant={message.type === 'error' ? 'destructive' : 'default'} className={message.type === 'success' ? 'border-emerald-200 bg-emerald-50' : ''}>
          {message.type === 'success' ? <CheckCircle2 className="h-4 w-4 text-emerald-600" /> : <AlertTriangle className="h-4 w-4" />}
          <AlertDescription className={message.type === 'success' ? 'text-emerald-700' : ''}>
            {message.text}
          </AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Export Section */}
        <Card className="border-emerald-200">
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="p-2 bg-emerald-100 rounded-lg">
                <Download className="h-5 w-5 text-emerald-600" />
              </div>
              <div>
                <CardTitle className="text-lg">{t('backup_export')}</CardTitle>
                <CardDescription>{t('backup_export')}</CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-2 text-sm text-gray-600">
              <Clock className="h-4 w-4" />
              <span>{t('backup_last_export')}:</span>
              <span className="font-medium">
                {lastExport ? new Date(lastExport).toLocaleString() : t('backup_never')}
              </span>
            </div>

            <div className="p-4 bg-gray-50 rounded-lg space-y-2">
              <div className="flex items-center gap-2 text-sm text-gray-700">
                <FileJson className="h-4 w-4" />
                <span>{t('backup_json_format')}</span>
              </div>
              <p className="text-xs text-gray-600">
                {t('backup_export_desc')}
              </p>
            </div>

            <Button
              onClick={handleExport}
              disabled={exporting}
              className="w-full bg-emerald-600 hover:bg-emerald-700 text-white"
            >
              {exporting ? (
                <>
                  <Loader2 className="h-4 w-4 me-2 animate-spin" />
                  {t('loading')}
                </>
              ) : (
                <>
                  <Download className="h-4 w-4 me-2" />
                  {t('backup_export')}
                </>
              )}
            </Button>
          </CardContent>
        </Card>

        {/* Import Section */}
        <Card className="border-amber-200">
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="p-2 bg-amber-100 rounded-lg">
                <Upload className="h-5 w-5 text-amber-600" />
              </div>
              <div>
                <CardTitle className="text-lg">{t('backup_import')}</CardTitle>
                <CardDescription>{t('backup_import')}</CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <label
                htmlFor="import-file"
                className="flex items-center justify-center w-full p-6 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-amber-400 transition-colors bg-gray-50 hover:bg-amber-50"
              >
                <div className="text-center">
                  <Upload className="h-8 w-8 text-gray-600 mx-auto mb-2" />
                  <p className="text-sm text-gray-600">
                    {importFileName || t('backup_choose_file')}
                  </p>
                  <p className="text-xs text-gray-600">.json</p>
                </div>
                <input
                  id="import-file"
                  type="file"
                  accept=".json"
                  onChange={handleFileSelect}
                  className="hidden"
                />
              </label>
            </div>

            {/* Preview of import data */}
            {importFile && (
              <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg space-y-3">
                <div className="flex items-center gap-2 text-sm font-medium text-amber-700">
                  <Shield className="h-4 w-4" />
                  <span>{t('backup_import_data')}</span>
                </div>
                <div className="text-xs text-gray-700">
                  {t('backup_version')}: {importFile.version} |
                  {' '}{t('backup_export_date')}: {new Date(importFile.exportedAt).toLocaleString(lang === 'ar' ? 'ar-KW' : 'en-US')}
                </div>
                <div className="grid grid-cols-3 gap-2 max-h-48 overflow-y-auto">
                  {statsEntries.map(([key, value]) => (
                    <div key={key} className="bg-white p-2 rounded border text-center">
                      <div className="text-lg font-bold text-amber-600">{value as number}</div>
                      <div className="text-xs text-gray-700 capitalize">{key}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {importProgress > 0 && (
              <div className="space-y-2">
                <Progress value={importProgress} className="h-2" />
                <p className="text-xs text-center text-gray-700">
                  {t('backup_importing')} {importProgress}%
                </p>
              </div>
            )}

            <Button
              onClick={() => setShowConfirmDialog(true)}
              disabled={!importFile || importing}
              className="w-full bg-amber-600 hover:bg-amber-700 text-white"
            >
              {importing ? (
                <>
                  <Loader2 className="h-4 w-4 me-2 animate-spin" />
                  {t('loading')}
                </>
              ) : (
                <>
                  <Upload className="h-4 w-4 me-2" />
                  {t('backup_import')}
                </>
              )}
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Warning Alert */}
      <Alert variant="destructive">
        <AlertTriangle className="h-4 w-4" />
        <AlertDescription>
          {t('backup_import_warning')}
        </AlertDescription>
      </Alert>

      {/* Confirmation Dialog */}
      <AlertDialog open={showConfirmDialog} onOpenChange={setShowConfirmDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-red-500" />
              {t('backup_confirm_import')}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {t('backup_import_warning')}
              {importFile && (
                <span className="block mt-2 text-sm">
                  {Object.values(importFile.stats).reduce((a: number, b: unknown) => a + (b as number), 0)} {t('backup_records_will_import')}
                </span>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={handleImport} className="bg-red-600 hover:bg-red-700">
              {t('confirm')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
