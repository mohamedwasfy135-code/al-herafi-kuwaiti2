const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const service = await prisma.service.findUnique({ where: { id: 1 } });
  console.log('Service:', service);
  if (service && service.categoryId !== 4) {
    await prisma.service.update({ where: { id: 1 }, data: { categoryId: 4 } });
    console.log('✅ تم ربط الخدمة بفئة تكييف');
  } else if (!service) {
    console.log('❌ الخدمة غير موجودة، أنشئها أولاً');
  } else {
    console.log('ℹ️ الخدمة مربوطة مسبقاً');
  }
}
main().catch(e => console.error(e)).finally(() => prisma.$disconnect());
