import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

async function setAdmin(email: string) {
  try {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      console.error(`User with email ${email} not found.`);
      process.exit(1);
    }

    if (user.role === Role.admin) {
      console.log(`User ${email} already has admin role.`);
      await prisma.$disconnect();
      return;
    }

    const updated = await prisma.user.update({
      where: { email },
      data: { role: Role.admin },
    });

    console.log(`✅ Successfully updated ${email} to admin role.`);
    console.log(`   User ID: ${updated.id}`);
    console.log(`   Display Name: ${updated.displayName}`);
    console.log(`   Role: ${updated.role}`);
  } catch (error) {
    console.error('Error updating user role:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Get email from command line argument
const email = process.argv[2];

if (!email) {
  console.error('Usage: ts-node scripts/set-admin.ts <email>');
  console.error('Example: ts-node scripts/set-admin.ts tamirlevi123@gmail.com');
  process.exit(1);
}

setAdmin(email);

