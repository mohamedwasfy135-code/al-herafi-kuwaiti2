const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const allServices = await prisma.service.findMany();
  console.log('All services:', JSON.stringify(allServices, null, 2));
}
main().catch(e => console.error(e)).finally(() => prisma.$disconnect());
