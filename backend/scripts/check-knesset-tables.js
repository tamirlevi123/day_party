const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkTables() {
  try {
    // Check for Knesset tables
    const knessetTables = await prisma.$queryRawUnsafe(`
      SHOW TABLES LIKE '_KNS_%'
    `);
    
    console.log('Knesset tables found:');
    console.log(JSON.stringify(knessetTables, null, 2));
    
    // Check if metadata_json column exists
    const columns = await prisma.$queryRawUnsafe(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'nodes' 
      AND COLUMN_NAME = 'metadata_json'
    `);
    
    console.log('\nmetadata_json column exists:', columns.length > 0);
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

checkTables();
