'use client'

import { Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import ShopsContent from './ShopsContent'

export default function ShopsPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center">تحميل...</div>}>
      <ShopsContent />
    </Suspense>
  )
}
