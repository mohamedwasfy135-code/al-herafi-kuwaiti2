const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  // جلب العميل والحرفي
  const client = await prisma.user.findFirst({ where: { phone: '96559999999', role: 'client' } });
  const craftsman = await prisma.user.findFirst({ where: { phone: '96551234567', role: 'craftsman' } });
  if (!client || !craftsman) {
    console.error('❌ العميل أو الحرفي غير موجودين');
    return;
  }
  const request = await prisma.request.create({
    data: {
      clientId: client.id,
      craftsmanId: craftsman.id,
      serviceType: 'تصليح مكيفات',
      details: 'المكيف لا يبرد - أول طلب تجريبي',
      status: 'pending',
      price: 20,
    },
  });
  console.log('✅ تم إنشاء الطلب بنجاح، معرف الطلب:', request.id);
}
main().catch(e => console.error(e)).finally(() => prisma.$disconnect());
