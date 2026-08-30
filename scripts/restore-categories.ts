import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function restoreCategories() {
  console.log('🔄 جاري استعادة التصنيفات...')
  
  try {
    // ══════════════════════════════════════════════════════════════
    // تصنيفات الخدمات
    // ═══════════════════════════════════════════════════════════════
    const serviceCategories = [
      { id: 1, name: 'كهرباء', nameEn: 'Electricity', icon: '⚡' },
      { id: 2, name: 'سباكة', nameEn: 'Plumbing', icon: '' },
      { id: 3, name: 'تكييف', nameEn: 'AC', icon: '❄️' },
      { id: 4, name: 'نجارة', nameEn: 'Carpentry', icon: '🪵' },
      { id: 5, name: 'حدادة', nameEn: 'Metalwork', icon: '🔨' },
      { id: 6, name: 'دهانات', nameEn: 'Painting', icon: '🎨' },
      { id: 7, name: 'أرضيات', nameEn: 'Flooring', icon: '🏠' },
      { id: 8, name: 'أسقف', nameEn: 'Ceiling', icon: '🏗️' },
      { id: 9, name: 'نقل عفش', nameEn: 'Moving', icon: '🚚' },
      { id: 10, name: 'تنظيف', nameEn: 'Cleaning', icon: '🧹' },
      { id: 11, name: 'مكافحة حشرات', nameEn: 'Pest Control', icon: '' },
      { id: 12, name: 'حدائق', nameEn: 'Gardening', icon: '🌳' },
      { id: 13, name: 'كهربائي', nameEn: 'Electrician', icon: '⚡' },
      { id: 14, name: 'سباك', nameEn: 'Plumber', icon: '' },
      { id: 15, name: 'فني تكييف', nameEn: 'AC Technician', icon: '❄️' },
      { id: 16, name: 'نجار', nameEn: 'Carpenter', icon: '🪵' },
      { id: 17, name: 'حداد', nameEn: 'Blacksmith', icon: '🔨' },
      { id: 18, name: 'دهان', nameEn: 'Painter', icon: '🎨' },
      { id: 19, name: 'مبلط', nameEn: 'Tiler', icon: '🏠' },
      { id: 20, name: 'معلم أسقف', nameEn: 'Ceiling Worker', icon: '🏗️' },
    ]

    console.log('📝 إنشاء تصنيفات الخدمات...')
    for (const cat of serviceCategories) {
      await prisma.category.upsert({
        where: { id: cat.id },
        update: {},
        create: {
          id: cat.id,
          name: cat.name,
          nameEn: cat.nameEn,
          icon: cat.icon,
          type: 'service'
        }
      })
      console.log(`   ✅ ${cat.name}`)
    }

    // ═══════════════════════════════════════════════════════════════
    // تصنيفات المحلات
    // ═══════════════════════════════════════════════════════════════
    const businessCategories = [
      { id: 101, name: 'مواد كهربائية', nameEn: 'Electrical Supplies', icon: '💡' },
      { id: 102, name: 'أدوات سباكة', nameEn: 'Plumbing Tools', icon: '🔧' },
      { id: 103, name: 'أجهزة تكييف', nameEn: 'AC Units', icon: '❄️' },
      { id: 104, name: 'أخشاب ونجارة', nameEn: 'Wood & Carpentry', icon: '🪵' },
      { id: 105, name: 'حديد ومعدات', nameEn: 'Iron & Tools', icon: '🔨' },
      { id: 106, name: 'دهانات ومواد', nameEn: 'Paints & Materials', icon: '🎨' },
      { id: 107, name: 'أرضيات وسيراميك', nameEn: 'Flooring & Ceramics', icon: '🏠' },
      { id: 108, name: 'مستلزمات حدائق', nameEn: 'Garden Supplies', icon: '🌳' },
      { id: 109, name: 'أدوات تنظيف', nameEn: 'Cleaning Supplies', icon: '🧹' },
      { id: 110, name: 'مكافحة حشرات', nameEn: 'Pest Control', icon: '🐛' },
      { id: 111, name: 'محلات', nameEn: 'Shops', icon: '🏪' },
    ]

    console.log('\n📝 إنشاء تصنيفات المحلات...')
    for (const cat of businessCategories) {
      await prisma.category.upsert({
        where: { id: cat.id },
        update: {},
        create: {
          id: cat.id,
          name: cat.name,
          nameEn: cat.nameEn,
          icon: cat.icon,
          type: 'business'
        }
      })
      console.log(`   ✅ ${cat.name}`)
    }

    console.log('\n🎉 تم استعادة جميع التصنيفات بنجاح!')
    console.log(`📊 إجمالي التصنيفات: ${serviceCategories.length + businessCategories.length}`)
    
  } catch (error) {
    console.error(' خطأ في استعادة التصنيفات:', error)
  } finally {
    await prisma.$disconnect()
  }
}

restoreCategories()
