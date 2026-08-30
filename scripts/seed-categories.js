const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const cats = [
    { name: 'سباكة', nameEn: 'Plumbing', icon: '🔧', sortOrder: 1 },
    { name: 'كهرباء', nameEn: 'Electricity', icon: '⚡', sortOrder: 2 },
    { name: 'نجارة', nameEn: 'Carpentry', icon: '🪚', sortOrder: 3 },
    { name: 'تكييف', nameEn: 'AC', icon: '❄️', sortOrder: 4 },
    { name: 'دهان', nameEn: 'Painting', icon: '🎨', sortOrder: 5 },
    { name: 'صيانة', nameEn: 'Maintenance', icon: '🔨', sortOrder: 6 },
  ];

  for (const c of cats) {
    const exists = await prisma.category.findUnique({ where: { name: c.name } });
    if (!exists) {
      await prisma.category.create({ data: c });
      console.log(`✅ أضيفت: ${c.name}`);
    } else {
      console.log(`⏭️ موجودة مسبقاً: ${c.name}`);
    }
  }
  console.log('✅ تم تحضير جميع الفئات');
}

main()
  .catch(e => {
    console.error('❌ حدث خطأ:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
