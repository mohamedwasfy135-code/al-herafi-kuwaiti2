const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // 1. إنشاء حرفي جديد
  const craftsman = await prisma.user.create({
    data: {
      name: 'أحمد النجار',
      phone: '96551234567',
      password: '123456',
      role: 'craftsman',
      verificationStatus: 'approved',
    },
  });
  console.log('✅ Craftsman created:', craftsman.id);

  // 2. إنشاء خدمة للحرفي
  const service = await prisma.service.create({
    data: {
      craftsmanId: craftsman.id,
      name: 'تصليح مكيفات',
      description: 'تصليح وصيانة جميع أنواع المكيفات',
      price: 20,
      governorate: 'العاصمة',
      isActive: true,
    },
  });
  console.log('✅ Service created:', service.id);

  // 3. إنشاء عميل (إذا لم يكن موجوداً)
  let client = await prisma.user.findFirst({ where: { role: 'client' } });
  if (!client) {
    client = await prisma.user.create({
      data: {
        name: 'عميل تجريبي',
        phone: '96559999999',
        password: '123456',
        role: 'client',
      },
    });
    console.log('✅ Client created:', client.id);
  } else {
    console.log('ℹ️ Client already exists:', client.id);
  }

  // 4. إنشاء طلب
  const request = await prisma.request.create({
    data: {
      clientId: client.id,
      craftsmanId: craftsman.id,
      serviceType: 'تصليح مكيفات',
      details: 'المكيف لا يبرد',
      status: 'pending',
      price: 20,
    },
  });
  console.log('✅ Request created:', request.id);
}

main()
  .catch((e) => {
    console.error('❌ Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
