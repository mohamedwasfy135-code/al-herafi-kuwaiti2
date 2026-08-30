'use client'

import Link from 'next/link'

export default function CraftsmanDashboard() {
  return (
    <div dir="rtl" className="max-w-4xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">لوحة الحرفي</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Link href="/dashboard/craftsman/bidding">
          <div className="bg-blue-50 rounded-xl shadow p-6 text-center hover:bg-blue-100 transition">
            <div className="text-4xl mb-2">💰</div>
            <h2 className="text-xl font-bold">طلبات التسعير</h2>
            <p className="text-gray-600">عرض الأسعار على الطلبات المستلمة</p>
          </div>
        </Link>
        <Link href="/dashboard/craftsman/profile">
          <div className="bg-green-50 rounded-xl shadow p-6 text-center hover:bg-green-100 transition">
            <div className="text-4xl mb-2">📄</div>
            <h2 className="text-xl font-bold">المستندات</h2>
            <p className="text-gray-600">رفع البطاقة المدنية والحساب البنكي</p>
          </div>
        </Link>
      </div>
    </div>
  )
}
