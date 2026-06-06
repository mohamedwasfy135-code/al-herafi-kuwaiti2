'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import {
  Wrench,
  ArrowRight,
  Search,
  Star,
  MapPin,
  Phone,
  ShoppingCart,
  Filter,
  ChevronLeft,
  Loader2,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'

interface Category {
  id: number
  name: string
  nameEn: string | null
  icon: string | null
  type: string
  _count: { services: number }
}

interface Service {
  id: number
  title: string
  description: string | null
  price: number
  images: string | null
  isActive: boolean
  craftsman: {
    id: string
    name: string
    phone: string | null
    rating: number
    totalJobs: number
    avatarUrl: string | null
    governorate: string | null
    city: string | null
  }
  category: {
    id: number
    name: string
    nameEn: string | null
    icon: string | null
  } | null
}

export default function ServicesPage() {
  const router = useRouter()
  const [services, setServices] = useState<Service[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string>('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [user, setUser] = useState<{ name: string; phone: string } | null>(null)

  useEffect(() => {
    const userData = localStorage.getItem('sana3i_user')
    if (userData) {
      setUser(JSON.parse(userData))
    }

    Promise.all([fetchServices(), fetchCategories()])
  }, [])

  useEffect(() => {
    if (search !== undefined) {
      const timeout = setTimeout(() => fetchServices(), 400)
      return () => clearTimeout(timeout)
    }
  }, [search, selectedCategory])

  const fetchCategories = async () => {
    try {
      const res = await fetch('/api/categories')
      const data = await res.json()
      setCategories(data)
    } catch (err) {
      console.error('Failed to fetch categories:', err)
    }
  }

  const fetchServices = async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams()
      if (selectedCategory) params.set('categoryId', selectedCategory)
      if (search) params.set('search', search)

      const res = await fetch(`/api/services?${params.toString()}`)
      const data = await res.json()
      setServices(data.data || [])
    } catch (err) {
      console.error('Failed to fetch services:', err)
    } finally {
      setLoading(false)
    }
  }

  const getCategoryIcon = (name: string) => {
    const icons: Record<string, string> = {
      سباكة: '🔧',
      كهرباء: '⚡',
      تكييف: '❄️',
      دهان: '🎨',
      نجارة: '🪚',
      تنظيف: '🧹',
      صيانة: '🛠️',
      بناء: '🏗️',
    }
    return icons[name] || '🔧'
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50/50">
      {/* Header */}
      <header className="sticky top-0 z-30 border-b bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => router.push('/')}
              className="rounded-full"
            >
              <ChevronLeft className="h-5 w-5" />
            </Button>
            <div>
              <h1 className="text-lg font-bold">الخدمات المتاحة</h1>
              <p className="text-xs text-muted-foreground">
                {services.length} خدمة متاحة
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 text-sm">
              {user?.name?.charAt(0) || 'م'}
            </div>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-6xl px-4 py-4">
        {/* Search */}
        <div className="relative mb-4">
          <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="ابحث عن خدمة..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pr-10 h-11 rounded-xl border-gray-200 bg-white"
          />
        </div>

        {/* Category Filter */}
        <div className="mb-6 flex gap-2 overflow-x-auto pb-2">
          <button
            onClick={() => setSelectedCategory('')}
            className={`shrink-0 rounded-full px-4 py-2 text-sm font-medium transition-colors ${
              !selectedCategory
                ? 'bg-emerald-600 text-white shadow-md shadow-emerald-200'
                : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            }`}
          >
            الكل
          </button>
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() =>
                setSelectedCategory(
                  selectedCategory === String(cat.id) ? '' : String(cat.id)
                )
              }
              className={`shrink-0 rounded-full px-4 py-2 text-sm font-medium transition-colors ${
                selectedCategory === String(cat.id)
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-200'
                  : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
              }`}
            >
              {getCategoryIcon(cat.name)} {cat.name}
              <span className="mr-1 text-xs opacity-70">
                ({cat._count.services})
              </span>
            </button>
          ))}
        </div>

        {/* Services Grid */}
        {loading ? (
          <div className="flex min-h-[300px] items-center justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
          </div>
        ) : services.length === 0 ? (
          <div className="flex min-h-[300px] flex-col items-center justify-center text-center">
            <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-gray-100">
              <Wrench className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-600">
              لا توجد خدمات
            </h3>
            <p className="text-sm text-muted-foreground">
              جرب البحث بكلمات مختلفة أو غير التصنيف
            </p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {services.map((service) => (
              <Card
                key={service.id}
                className="overflow-hidden border-0 shadow-md shadow-gray-100 transition-shadow hover:shadow-lg"
              >
                {/* Category Badge */}
                <div className="bg-gradient-to-l from-emerald-500 to-emerald-600 px-4 py-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-lg">
                        {service.category
                          ? getCategoryIcon(service.category.name)
                          : '🔧'}
                      </span>
                      <span className="text-sm font-medium text-white">
                        {service.category?.name || 'عام'}
                      </span>
                    </div>
                    <Badge className="bg-white/20 text-white border-0 text-xs">
                      {service.price > 0 ? `${service.price} د.ك` : 'سعر عند الطلب'}
                    </Badge>
                  </div>
                </div>

                <CardContent className="p-4">
                  {/* Service Title */}
                  <h3 className="mb-2 text-base font-bold text-gray-900">
                    {service.title}
                  </h3>
                  {service.description && (
                    <p className="mb-3 text-sm text-muted-foreground line-clamp-2">
                      {service.description}
                    </p>
                  )}

                  {/* Craftsman Info */}
                  <div className="mb-3 flex items-center gap-3 rounded-lg bg-gray-50 p-2.5">
                    <Avatar className="h-9 w-9">
                      <AvatarFallback className="bg-emerald-100 text-emerald-700 text-xs font-semibold">
                        {service.craftsman.name.charAt(0)}
                      </AvatarFallback>
                    </Avatar>
                    <div className="flex-1">
                      <p className="text-sm font-medium">
                        {service.craftsman.name}
                      </p>
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        {service.craftsman.rating > 0 && (
                          <span className="flex items-center gap-0.5">
                            <Star className="h-3 w-3 fill-amber-400 text-amber-400" />
                            {service.craftsman.rating.toFixed(1)}
                          </span>
                        )}
                        {service.craftsman.city && (
                          <span className="flex items-center gap-0.5">
                            <MapPin className="h-3 w-3" />
                            {service.craftsman.city}
                          </span>
                        )}
                        {service.craftsman.totalJobs > 0 && (
                          <span>{service.craftsman.totalJobs} مهمة</span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Action */}
                  <Button
                    className="w-full bg-emerald-600 hover:bg-emerald-700 gap-2"
                    onClick={() => {
                      if (user) {
                        alert(`سيتم طلب خدمة: ${service.title}`)
                      } else {
                        router.push('/login')
                      }
                    }}
                  >
                    <ShoppingCart className="h-4 w-4" />
                    طلب الخدمة
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        {/* Bottom Nav */}
        <div className="mt-8 flex justify-center gap-3">
          <Button
            variant="outline"
            onClick={() => router.push('/')}
            className="gap-2"
          >
            <ArrowRight className="h-4 w-4" />
            العودة للوحة التحكم
          </Button>
        </div>
      </div>
    </div>
  )
}
