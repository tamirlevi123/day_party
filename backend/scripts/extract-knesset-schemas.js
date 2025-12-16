const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

(async () => {
  const tables = [
    '_KNS_Status',
    '_KNS_Faction',
    '_KNS_Person',
    '_KNS_Committee',
    '_KNS_Bill',
    '_KNS_DocumentBill',
    '_KNS_CommitteeSession',
  ];

  console.log('-- Knesset Tables Migration');
  console.log('-- Generated from existing MySQL tables\n');

  for (const table of tables) {
    try {
      const result = await prisma.$queryRawUnsafe(`SHOW CREATE TABLE \`${table}\``);
      const createTable = result[0]?.f1 || result[0]?.['Create Table'] || result[0]?.['CREATE TABLE'];
      if (createTable) {
        // Replace lowercase table name with original uppercase name
        // MySQL converts table names to lowercase, so we need to restore the original case
        const tableNameMap = {
          '_kns_status': '_KNS_Status',
          '_kns_faction': '_KNS_Faction',
          '_kns_person': '_KNS_Person',
          '_kns_committee': '_KNS_Committee',
          '_kns_bill': '_KNS_Bill',
          '_kns_documentbill': '_KNS_DocumentBill',
          '_kns_committeesession': '_KNS_CommitteeSession',
        };
        let fixedCreateTable = createTable;
        for (const [lower, upper] of Object.entries(tableNameMap)) {
          fixedCreateTable = fixedCreateTable.replace(new RegExp(`\`${lower}\``, 'gi'), `\`${upper}\``);
        }
        console.log(fixedCreateTable);
        console.log(';\n');
      } else {
        console.error(`-- Could not extract CREATE TABLE for ${table}`);
      }
    } catch (e) {
      console.error(`-- Error getting schema for ${table}: ${e.message}`);
    }
  }

  await prisma.$disconnect();
})();
