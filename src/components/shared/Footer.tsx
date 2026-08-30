import Link from 'next/link'

export default function Footer() {
  return (
    <footer className="bg-gray-900 text-white" dir="rtl">
      <div className="max-w-7xl mx-auto px-4 py-10">
        <div className="grid md:grid-cols-3 gap-8 mb-8">
          <div>
            <h3 className="text-lg font-bold mb-3 flex items-center gap-2">
              <span className="text-2xl">🔧</span>
              الحرفي الكويتي
            </h3>
            <p className="text-gray-600 text-sm leading-relaxed">
              منصة ربط العملاء بالحرفيين والمحلات في الكويت.
              تصفح الخدمات، اطلب حرفي، أو تسوق من المحلات.
            </p>
          </div>

          <div>
            <h4 className="font-semibold mb-3">روابط سريعة</h4>
            <ul className="space-y-2 text-sm text-gray-600">
              <li>
                <Link href="/services" className="hover:text-white transition">
                  الخدمات
                </Link>
              </li>
              <li>
                <Link href="/shops" className="hover:text-white transition">
                  المحلات والشركات
                </Link>
              </li>
              <li>
                <Link href="/my-orders" className="hover:text-white transition">
                  طلباتي
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <Link
              href="/shop/login"
              className="block p-4 bg-gray-800 rounded-lg hover:bg-gray-700 transition group"
            >
              <div className="flex items-center gap-3">
                <span className="text-3xl">🏪</span>
                <div>
                  <h4 className="font-bold group-hover:text-blue-400 transition">
                    انتقل إلى البرنامج الإداري المحاسبي
                  </h4>
                  <p className="text-sm text-gray-600 mt-1">
                    إدارة فواتير · سندات · محاسبة · مخزون
                  </p>
                </div>
              </div>
            </Link>
          </div>
        </div>

        <div className="border-t border-gray-800 pt-6 text-center text-sm text-gray-700">
          © {new Date().getFullYear()} الحرفي الكويتي - جميع الحقوق محفوظة
        </div>
      </div>
    </footer>
  )
}
