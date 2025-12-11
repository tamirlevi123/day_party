/**
 * Import script for Knesset Bills from JSON files
 * 
 * This script imports bills from the Knesset OData JSON files into Day Party platform.
 * 
 * Usage:
 *   tsx scripts/import-knesset-bills.ts --bills-file "E:\Knesset\Downloader\data\_KNS_Bill.json" --persons-file "E:\Knesset\Downloader\data\_KNS_Person.json" --dry-run
 * 
 * Arguments:
 *   --bills-file <path>     Path to _KNS_Bill.json file
 *   --persons-file <path>   Path to _KNS_Person.json file (optional, for creating MK users)
 *   --topic-name <name>     Topic name to import into (default: "חוקי הכנסת")
 *   --dry-run              Test parsing without importing
 */

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import * as fs from 'fs';
import { htmlToDelta } from './html-to-delta';

dotenv.config();

const prisma = new PrismaClient();

// Parse command line arguments
function parseArgs() {
  const args: Record<string, string | boolean> = {};
  const argv = process.argv.slice(2);
  
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].substring(2);
      if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        args[key] = argv[i + 1];
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  
  return args;
}

const args = parseArgs();
const BILLS_FILE = (args['bills-file'] as string) || process.env.KNESSET_BILLS_FILE;
const PERSONS_FILE = (args['persons-file'] as string) || process.env.KNESSET_PERSONS_FILE;
const TOPIC_NAME = (args['topic-name'] as string) || 'חוקי הכנסת';
const DRY_RUN = args['dry-run'] === true || process.env.DRY_RUN === 'true';

interface KnessetBill {
  BillID: number;
  KnessetNum: number;
  Name: string;
  SummaryLaw?: string | null;
  PublicationDate?: string | null;
  StatusID?: number | null;
  CommitteeID?: number | null;
  Number?: number | null;
  PrivateNumber?: number | null;
  SubTypeDesc?: string | null;
  LastUpdatedDate?: string | null;
  DYID?: number;
}

interface KnessetPerson {
  PersonID: number;
  FirstName: string;
  LastName: string;
  GenderID?: number | null;
  GenderDesc?: string | null;
  Email?: string | null;
  IsCurrent?: boolean | null;
  LastUpdatedDate?: string | null;
  DYID?: number;
}

/**
 * Get or create the import topic
 */
async function getOrCreateTopic(adminUserId: string) {
  const existingTopic = await prisma.topic.findFirst({
    where: {
      name: TOPIC_NAME,
      createdBy: adminUserId,
    },
  });

  if (existingTopic) {
    console.log(`✅ Using existing topic: ${TOPIC_NAME}`);
    return existingTopic;
  }

  const topic = await prisma.topic.create({
    data: {
      id: randomUUID(),
      name: TOPIC_NAME,
      description: 'חוקים והצעות חוק מהכנסת',
      visibility: 'public',
      createdBy: adminUserId,
    },
  });

  console.log(`✅ Created topic: ${TOPIC_NAME}`);
  return topic;
}

/**
 * Get or create admin user for topic creation
 */
async function getOrCreateAdminUser() {
  let adminUser = await prisma.user.findFirst({
    where: { role: 'admin' },
  });

  if (!adminUser) {
    // Create a default admin user if none exists
    adminUser = await prisma.user.create({
      data: {
        id: randomUUID(),
        email: 'admin@dayparty.com',
        displayName: 'System Admin',
        role: 'admin',
      },
    });
    console.log('✅ Created default admin user');
  }

  return adminUser;
}

/**
 * Load and parse bills from JSON file
 */
function loadBills(filePath: string): KnessetBill[] {
  console.log(`📁 Loading bills from: ${filePath}`);
  
  if (!fs.existsSync(filePath)) {
    throw new Error(`Bills file not found: ${filePath}`);
  }

  const fileContent = fs.readFileSync(filePath, 'utf-8');
  const data = JSON.parse(fileContent);

  // Handle both dict format { "dyid": {...} } and list format [...]
  let bills: KnessetBill[] = [];
  if (Array.isArray(data)) {
    bills = data;
  } else if (typeof data === 'object') {
    bills = Object.values(data) as KnessetBill[];
  } else {
    throw new Error('Invalid JSON format: expected array or object');
  }

  console.log(`✅ Loaded ${bills.length} bills`);
  return bills;
}

/**
 * Load and parse persons from JSON file (optional)
 */
function loadPersons(filePath: string): KnessetPerson[] {
  if (!filePath || !fs.existsSync(filePath)) {
    console.log('⚠️  Persons file not provided or not found, skipping person import');
    return [];
  }

  console.log(`📁 Loading persons from: ${filePath}`);
  const fileContent = fs.readFileSync(filePath, 'utf-8');
  const data = JSON.parse(fileContent);

  let persons: KnessetPerson[] = [];
  if (Array.isArray(data)) {
    persons = data;
  } else if (typeof data === 'object') {
    persons = Object.values(data) as KnessetPerson[];
  }

  console.log(`✅ Loaded ${persons.length} persons`);
  return persons;
}

/**
 * Create users for Knesset members (optional)
 */
async function createPersonUsers(persons: KnessetPerson[]): Promise<Map<number, string>> {
  const personIdToUserIdMap = new Map<number, string>();
  
  if (persons.length === 0) {
    return personIdToUserIdMap;
  }

  console.log(`👤 Creating users for ${persons.length} Knesset members...`);
  
  for (const person of persons) {
    // Skip if no name
    if (!person.FirstName && !person.LastName) {
      continue;
    }

    const displayName = `${person.FirstName || ''} ${person.LastName || ''}`.trim();
    const email = person.Email || `knesset_${person.PersonID}@dayparty.com`;

    // Check if user already exists
    let user = await prisma.user.findFirst({
      where: { email },
    });

    if (!user) {
      user = await prisma.user.create({
        data: {
          id: randomUUID(),
          email,
          displayName,
          locale: 'he-IL',
          role: 'user',
        },
      });
    }

    personIdToUserIdMap.set(person.PersonID, user.id);
  }

  console.log(`✅ Created/found ${personIdToUserIdMap.size} users for Knesset members`);
  return personIdToUserIdMap;
}

/**
 * Import a single bill as a thread with root node
 */
async function importBill(
  bill: KnessetBill,
  topicId: string,
  defaultUserId: string
): Promise<string | null> {
  try {
    const title = bill.Name || `חוק ${bill.BillID}`;
    const summary = bill.SummaryLaw || '';
    
    // Convert summary to Delta format
    const deltaContent = summary.trim().length > 0 
      ? htmlToDelta(summary)
      : null;

    // Parse publication date
    let createdAt = new Date();
    if (bill.PublicationDate) {
      const parsedDate = new Date(bill.PublicationDate);
      if (!isNaN(parsedDate.getTime())) {
        createdAt = parsedDate;
      }
    }

    // Create thread
    const thread = await prisma.thread.create({
      data: {
        id: randomUUID(),
        topicId: topicId,
        title: title.substring(0, 500),
        description: null,
        createdBy: defaultUserId,
        status: 'open',
        createdAt: createdAt,
      },
    });

    // Create root node with the bill summary as content
    if (deltaContent && deltaContent.ops && deltaContent.ops.length > 0) {
      await prisma.node.create({
        data: {
          id: randomUUID(),
          threadId: thread.id,
          parentNodeId: null,
          parentRelation: null,
          title: title.substring(0, 500),
          textContent: JSON.stringify(deltaContent),
          textFormat: 'delta',
          authorId: defaultUserId,
          isAnonymous: false,
          moderationState: 'visible',
          textStatus: 'provided',
          videoStatus: 'missing',
          votingEnabled: true,
          createdAt: createdAt,
        },
      });
    }

    const knessetInfo = bill.KnessetNum ? ` (כנסת ${bill.KnessetNum})` : '';
    console.log(`  ✅ Created thread: ${title.substring(0, 50)}...${knessetInfo}`);
    return thread.id;
  } catch (error: any) {
    console.error(`  ❌ Error importing bill ${bill.BillID}:`, error.message);
    return null;
  }
}

/**
 * Main import function
 */
async function importKnessetBills() {
  try {
    console.log('🚀 Starting Knesset bills import...\n');

    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
    }

    if (!BILLS_FILE) {
      throw new Error('--bills-file is required');
    }

    // Load bills
    const bills = loadBills(BILLS_FILE);
    
    if (bills.length === 0) {
      console.log('⚠️  No bills found in file');
      return;
    }

    // Load persons (optional)
    const persons = PERSONS_FILE ? loadPersons(PERSONS_FILE) : [];

    if (DRY_RUN) {
      console.log('\n📋 Sample Bills (first 5):');
      console.log('='.repeat(80));
      bills.slice(0, 5).forEach((bill, idx) => {
        console.log(`\nBill ${idx + 1}:`);
        console.log(`  ID: ${bill.BillID}`);
        console.log(`  Name: ${bill.Name}`);
        console.log(`  Knesset: ${bill.KnessetNum || 'N/A'}`);
        console.log(`  Summary length: ${bill.SummaryLaw?.length || 0} chars`);
        console.log(`  Publication Date: ${bill.PublicationDate || 'N/A'}`);
      });

      console.log('\n✅ Dry run complete - no data imported\n');
      return;
    }

    // Get or create admin user
    const adminUser = await getOrCreateAdminUser();
    console.log(`👤 Admin user ID: ${adminUser.id}\n`);

    // Get or create topic
    const topic = await getOrCreateTopic(adminUser.id);
    console.log(`📁 Topic ID: ${topic.id}\n`);

    // Create users for Knesset members (optional)
    const personUserMap = await createPersonUsers(persons);
    console.log('');

    // Use admin user as default author for bills (since we don't have bill authors in the data)
    const defaultUserId = adminUser.id;

    // Import bills
    console.log(`📥 Importing ${bills.length} bills...\n`);
    let importedThreads = 0;
    let failedThreads = 0;

    for (const bill of bills) {
      const threadId = await importBill(bill, topic.id, defaultUserId);
      if (threadId) {
        importedThreads++;
      } else {
        failedThreads++;
      }
    }

    console.log(`\n📊 Threads imported: ${importedThreads}, failed: ${failedThreads}\n`);

    console.log('✅ Import complete!\n');

    console.log('📈 Summary:');
    console.log(`  Topics: 1`);
    console.log(`  Threads: ${importedThreads} (${failedThreads} failed)`);
    console.log(`  Users created: ${personUserMap.size} Knesset members`);
  } catch (error: any) {
    console.error('❌ Import failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Show usage if no arguments provided
if (!BILLS_FILE && process.argv.length === 2) {
  console.log(`
Usage:
  tsx scripts/import-knesset-bills.ts [options]

Options:
  --bills-file <path>     Path to _KNS_Bill.json file (required)
  --persons-file <path>   Path to _KNS_Person.json file (optional)
  --topic-name <name>     Topic name (default: "חוקי הכנסת")
  --dry-run              Test parsing without importing

Examples:
  # Dry run to test parsing:
  tsx scripts/import-knesset-bills.ts --bills-file "E:\\Knesset\\Downloader\\data\\_KNS_Bill.json" --dry-run
  
  # Import bills:
  tsx scripts/import-knesset-bills.ts --bills-file "E:\\Knesset\\Downloader\\data\\_KNS_Bill.json"
  
  # Import with Knesset members as users:
  tsx scripts/import-knesset-bills.ts --bills-file "E:\\Knesset\\Downloader\\data\\_KNS_Bill.json" --persons-file "E:\\Knesset\\Downloader\\data\\_KNS_Person.json"
`);
  process.exit(0);
}

// Run import
importKnessetBills()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

