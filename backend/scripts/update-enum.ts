import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function updateEnum() {
  try {
    console.log('Updating text_format enum to include "html"...');
    
    await prisma.$executeRawUnsafe(`
      ALTER TABLE nodes 
      MODIFY COLUMN text_format ENUM('markdown', 'plain', 'html') 
      NOT NULL DEFAULT 'plain';
    `);
    
    console.log('✅ Enum updated successfully!');
    console.log('Now run: npm run db:generate');
  } catch (error: any) {
    console.error('❌ Error updating enum:', error.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

updateEnum();

