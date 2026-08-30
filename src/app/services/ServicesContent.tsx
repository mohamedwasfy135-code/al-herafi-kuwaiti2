'use client'

import { useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

export default function ServicesContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  
  useEffect(() => {
    const categoryId = searchParams.get('category')
    const search = searchParams.get('search')
    
    if (categoryId) {
      router.replace(`/create-request?categoryId=${categoryId}`)
    } else if (search) {
      router.replace(`/create-request?search=${encodeURIComponent(search)}`)
    } else {
      router.replace('/create-request')
    }
  }, [router, searchParams])

  return (
    <div className="flex min-h-screen items-center justify-center">
      <p>جارٍ التوجيه إلى صفحة الطلب...</p>
    </div>
  )
}
