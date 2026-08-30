const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('جارٍ إضافة الفئات...');
  const categories = [
    { name: 'سباكة', nameEn: 'Plumbing', icon: '🔧', sortOrder: 1 },
    { name: 'كهرباء', nameEn: 'Electricity', icon: '⚡', sortOrder: 2 },
    { name: 'نجارة', nameEn: 'Carpentry', icon: '🪚', sortOrder: 3 },
    { name: 'تكييف', nameEn: 'AC', icon: '❄️', sortOrder: 4 },
    { name: 'دهان', nameEn: 'Painting', icon: '🎨', sortOrder: 5 },
    { name: 'صيانة', nameEn: 'Maintenance', icon: '🔨', sortOrder: 6 },
  ];

  for (const cat of categories) {
    // استخدام upsert لتجنب الخطأ إذا كانت الفئة موجودة مسبقاً
    await prisma.category.upsert({
      where: { name: cat.name },
      update: {},
      create: cat,
    });
    console.log(`✅ تمت إضافة/تحديث الفئة: ${cat.name}`);
  }

  console.log('✅ تم إضافة جميع الفئات.');
}

main()
  .catch((e) => {
    console.error('❌ حدث خطأ:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
