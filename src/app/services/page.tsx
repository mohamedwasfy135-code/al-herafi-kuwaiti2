import { Suspense } from 'react'
import ServicesContent from './ServicesContent'

export default function ServicesPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center">جارٍ التحميل...</div>}>
      <ServicesContent />
    </Suspense>
  )
}
