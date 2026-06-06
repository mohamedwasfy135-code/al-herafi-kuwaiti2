'use client'

import { Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import { ProductsTab } from '@/components/dashboard/products-tab'

function ProductsContent() {
  const searchParams = useSearchParams()
  const editId = searchParams.get('edit') || searchParams.get('open')

  return <ProductsTab initialEditId={editId} />
}

export default function ProductsPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center py-12"><div className="animate-spin h-8 w-8 border-4 border-emerald-600 border-t-transparent rounded-full" /></div>}>
      <ProductsContent />
    </Suspense>
  )
}
