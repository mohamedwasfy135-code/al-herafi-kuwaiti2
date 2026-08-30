const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  await prisma.service.update({
    where: { id: 1 },
    data: { categoryId: 4 },
  });
  console.log('✅ تم ربط الخدمة بفئة تكييف');
}
main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
