import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkData() {
  console.log('🔍 فحص البيانات الموجودة في قاعدة البيانات...\n');

  // المستخدمين
  const users = await prisma.user.findMany({
    select: { id: true, name: true, role: true, verification_status: true },
  });
  console.log('👥 المستخدمين:', users.length);
  users.forEach(u => console.log(`   - ${u.name} (${u.role}) - ${u.verification_status}`));

  // الطلبات
  const requests = await prisma.request.findMany({
    select: { id: true, status: true, serviceType: true, clientId: true, craftsmanId: true },
  });
  console.log('\n📋 الطلبات:', requests.length);
  requests.forEach(r => console.log(`   - طلب #${r.id}: ${r.status} - ${r.serviceType || 'غير محدد'}`));

  // الوثائق
  const docs = await prisma.craftsmanIDocument.findMany({
    select: { id: true, status: true, craftsmanId: true },
  });
  console.log('\n📄 الوثائق:', docs.length);
  docs.forEach(d => console.log(`   - وثيقة #${d.id}: ${d.status}`));

  // طلبات الاسترداد
  const refunds = await prisma.refundRequest.findMany({
    select: { id: true, status: true, amount: true },
  });
  console.log('\n💰 طلبات الاسترداد:', refunds.length);
  refunds.forEach(r => console.log(`   - استرداد #${r.id}: ${r.status} - ${r.amount}`));

  // طلبات السحب
  const payouts = await prisma.payoutRequest.findMany({
    select: { id: true, status: true, amount: true },
  });
  console.log('\n💸 طلبات السحب:', payouts.length);
  payouts.forEach(p => console.log(`   - سحب #${p.id}: ${p.status} - ${p.amount}`));

  // طلبات التدخل
  const interventions = await prisma.interventionRequest.findMany({
    select: { id: true, status: true },
  });
  console.log('\n🚨 طلبات التدخل:', interventions.length);
  interventions.forEach(i => console.log(`   - تدخل #${i.id}: ${i.status}`));

  await prisma.$disconnect();
}

checkData().catch(console.error);
