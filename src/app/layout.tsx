import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'الحرفي الكويتي',
  description: 'منصة الحرفي الكويتي للخدمات والمحلات',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body className="min-h-screen bg-gray-50">
        {children}
      </body>
    </html>
  )
}
