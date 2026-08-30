import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 بدء إضافة التصنيفات...')

  // تصنيفات الحرفيين (خدمات)
  const serviceCategories = [
    { name: 'كهرباء', nameEn: 'Electrical', icon: '⚡', type: 'service' },
    { name: 'صحي', nameEn: 'Plumbing', icon: '🚰', type: 'service' },
    { name: 'تكييف وتبريد', nameEn: 'AC & Cooling', icon: '❄️', type: 'service' },
    { name: 'سيراميك', nameEn: 'Ceramics', icon: '🏺', type: 'service' },
    { name: 'نقل عفش', nameEn: 'Moving', icon: '🚚', type: 'service' },
    { name: 'صبغ', nameEn: 'Painting', icon: '🎨', type: 'service' },
    { name: 'ترميميات', nameEn: 'Renovation', icon: '🔧', type: 'service' },
  ]

  // تصنيفات المحلات (منتجات)
  const businessCategories = [
    { name: 'أدوات كهربائية', nameEn: 'Electrical Tools', icon: '💡', type: 'business' },
    { name: 'أدوات صحية', nameEn: 'Plumbing Tools', icon: '🔧', type: 'business' },
    { name: 'مواد بناء', nameEn: 'Building Materials', icon: '🧱', type: 'business' },
    { name: 'معدات كهربائية', nameEn: 'Electrical Equipment', icon: '⚙️', type: 'business' },
    { name: 'أصباغ', nameEn: 'Paints', icon: '🎨', type: 'business' },
  ]

  console.log('\n📌 إضافة تصنيفات الحرفيين (خدمات):')
  for (const category of serviceCategories) {
    await prisma.category.upsert({
      where: { name: category.name },
      update: { type: 'service' },
      create: category,
    })
    console.log(`  ✅ ${category.icon} ${category.name}`)
  }

  console.log('\n🏪 إضافة تصنيفات المحلات (منتجات):')
  for (const category of businessCategories) {
    await prisma.category.upsert({
      where: { name: category.name },
      update: { type: 'business' },
      create: category,
    })
    console.log(`  ✅ ${category.icon} ${category.name}`)
  }

  console.log('\n✅ تم إضافة جميع التصنيفات بنجاح!')
}

main()
  .catch((e) => {
    console.error('❌ خطأ:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
