const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // التحقق من وجود عميل مسبقًا
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
    console.log('✅ تم إنشاء العميل:', client.id);
  } else {
    console.log('ℹ️ عميل موجود مسبقًا:', client.name, client.phone);
  }
}

main()
  .catch((e) => { console.error('❌ خطأ:', e); process.exit(1); })
  .finally(() => prisma.$disconnect());
