const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // جلب الحرفي برقم الهاتف (أو يمكنك تغيير الشرط)
  const craftsman = await prisma.user.findFirst({
    where: { phone: '96551234567', role: 'craftsman' }
  });
  if (!craftsman) {
    console.error('❌ الحرفي غير موجود. تأكد من إضافته أولاً.');
    process.exit(1);
  }
  console.log('ℹ️ Craftsman found:', craftsman.name, craftsman.id);

  // إضافة الخدمة
  const service = await prisma.service.create({
    data: {
      craftsmanId: craftsman.id,
      title: 'تصليح مكيفات',
      description: 'تصليح وصيانة جميع أنواع المكيفات',
      price: 20.0,
      isActive: true,
    },
  });
  console.log('✅ تم إنشاء الخدمة:', service.id);
}

main()
  .catch((e) => {
    console.error('❌ خطأ:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
