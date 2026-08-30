'use client'

import { useState, useEffect } from 'react'
import { useRouter, useParams } from 'next/navigation'
import Link from 'next/link'
import {
  Star,
  ShoppingCart,
  Search,
  ArrowRight,
  Loader2,
  PackageOpen,
  Sparkles,
} from 'lucide-react'

interface Business {
  id: string
  name: string
  logoUrl?: string
  coverUrl?: string
  description?: string
  phone?: string
  rating: number
  totalReviews: number
  businessType: string
  category?: { name: string } | null
}

interface Product {
  id: number
  name: string
  price: number
  discountPrice?: number | null
  stockQuantity: number
  category?: { name: string } | null
  images?: string | null
  isActive: boolean
  isFeatured: boolean
}

export default function StorePage() {
  const router = useRouter()
  const params = useParams()
  const businessId = params.businessId as string

  const [business, setBusiness] = useState<Business | null>(null)
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')

  useEffect(() => {
    if (!businessId) return
    fetchBusiness()
    fetchProducts()
  }, [businessId])

  const fetchBusiness = async () => {
    try {
      const res = await fetch(`/api/business/${businessId}`)
      const data = await res.json()
      setBusiness(data.business || data)
    } catch (err) {
      console.error('Error fetching business:', err)
    }
  }

  const fetchProducts = async () => {
    try {
      const res = await fetch(`/api/products?businessId=${businessId}`)
      const data = await res.json()
      const allProducts = Array.isArray(data) ? data : (data.products || data.data || [])
      setProducts(allProducts.filter((p: Product) => p.isActive))
    } catch (err) {
      console.error('Error fetching products:', err)
    } finally {
      setLoading(false)
    }
  }

  const filteredProducts = searchQuery
    ? products.filter(
        p =>
          p.name?.includes(searchQuery) ||
          p.category?.name?.includes(searchQuery)
      )
    : products

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50">
      <div className="bg-gradient-to-r from-blue-700 to-indigo-800 text-white">
        <div className="max-w-6xl mx-auto px-4 py-8 md:py-12">
          <div className="flex items-center gap-4 mb-4">
            <button
              onClick={() => router.back()}
              className="text-white/80 hover:text-white transition"
            >
              <ArrowRight className="h-5 w-5" />
            </button>
            <div className="flex-1">
              <h1 className="text-2xl md:text-3xl font-bold">{business?.name || 'المتجر'}</h1>
              <div className="flex items-center gap-3 mt-2 text-sm text-white/80">
                <span>{business?.businessType === 'shop' ? '🏪 محل' : '🏢 شركة'}</span>
                {business?.category?.name && <span>{business.category.name}</span>}
                {business?.rating > 0 && (
                  <span className="flex items-center gap-1">
                    <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                    {business.rating.toFixed(1)} ({business.totalReviews})
                  </span>
                )}
              </div>
              {business?.description && (
                <p className="mt-3 text-white/70 text-sm leading-relaxed max-w-2xl">
                  {business.description}
                </p>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-6">
        <div className="relative mb-6">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-600" />
          <input
            type="text"
            placeholder="ابحث عن منتج..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pr-10 pl-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 transition bg-white"
          />
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="h-10 w-10 animate-spin text-blue-600" />
          </div>
        ) : filteredProducts.length === 0 ? (
          <div className="text-center py-20">
            <PackageOpen className="h-16 w-16 mx-auto text-gray-700 mb-4" />
            <h3 className="text-lg font-medium text-gray-600">لا توجد منتجات حالياً</h3>
            <p className="text-sm text-gray-600 mt-1">لم يقم المحل بإضافة منتجات بعد</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {filteredProducts.map((product) => {
              const imageSrc = product.images?.split(',')[0] || null
              return (
                <div
                  key={product.id}
                  className="bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden group relative"
                >
                  <div className="h-48 bg-gradient-to-br from-blue-50 to-indigo-50 flex items-center justify-center relative">
                    {imageSrc ? (
                      <img
                        src={imageSrc}
                        alt={product.name}
                        className="h-full w-full object-cover group-hover:scale-105 transition-transform duration-300"
                      />
                    ) : (
                      <PackageOpen className="h-12 w-12 text-gray-700" />
                    )}
                    {product.isFeatured && (
                      <div className="absolute top-2 right-2 bg-amber-400 text-white text-xs font-bold px-2 py-1 rounded-full flex items-center gap-1">
                        <Sparkles className="h-3 w-3" />
                        مميز
                      </div>
                    )}
                    {product.discountPrice && product.discountPrice < product.price && (
                      <div className="absolute top-2 left-2 bg-red-500 text-white text-xs font-bold px-2 py-1 rounded-full">
                        خصم {Math.round((1 - product.discountPrice / product.price) * 100)}%
                      </div>
                    )}
                  </div>

                  <div className="p-4">
                    <h3 className="font-semibold text-gray-900 mb-1 truncate">{product.name}</h3>
                    {product.category?.name && (
                      <p className="text-xs text-gray-700 mb-2">{product.category.name}</p>
                    )}
                    <div className="flex items-center justify-between">
                      <div>
                        {product.discountPrice && product.discountPrice < product.price ? (
                          <div className="flex items-center gap-2">
                            <span className="text-lg font-bold text-red-600">{product.discountPrice} د.ك</span>
                            <span className="text-sm text-gray-600 line-through">{product.price} د.ك</span>
                          </div>
                        ) : (
                          <span className="text-lg font-bold text-blue-600">{product.price} د.ك</span>
                        )}
                      </div>
                      {product.stockQuantity > 0 ? (
                        <button
                          onClick={() => alert(`تمت إضافة "${product.name}" إلى السلة`)}
                          className="flex items-center gap-1 bg-emerald-600 hover:bg-emerald-700 text-white text-sm px-3 py-1.5 rounded-lg transition"
                        >
                          <ShoppingCart className="h-4 w-4" />
                          أضف
                        </button>
                      ) : (
                        <span className="text-xs text-red-500">غير متوفر</span>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      <div className="text-center pb-8">
        <Link href="/dashboard" className="text-blue-600 hover:underline text-sm">
          ← العودة إلى لوحة العميل
        </Link>
      </div>
    </div>
  )
}
