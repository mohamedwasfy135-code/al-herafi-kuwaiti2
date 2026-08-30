const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const category = await prisma.category.findUnique({ where: { name: 'تكييف' } });
  if (!category) {
    console.error('❌ فئة تكييف غير موجودة');
    process.exit(1);
  }
  await prisma.service.update({
    where: { id: 1 },
    data: { categoryId: category.id },
  });
  console.log('✅ تم ربط خدمة تصليح مكيفات بفئة تكييف');
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
