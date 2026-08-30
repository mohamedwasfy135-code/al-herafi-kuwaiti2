const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const id = 'c6744264-9cc8-42fc-988e-9fd19da1f0a2';
  try {
    const user = await prisma.user.findUnique({ where: { id } });
    console.log('User:', user);
  } catch (e) {
    console.error('Error:', e);
  }
  await prisma.$disconnect();
}
main();
