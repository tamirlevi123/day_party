/**
 * Import meme images from GoodMemes directory into the "ממים" topic
 * 
 * Usage:
 *   tsx scripts/import-memes.ts --memes-dir "E:\day_party\GoodMemes" --dry-run
 * 
 * Arguments:
 *   --memes-dir <path>    Path to directory containing meme images (default: E:\day_party\GoodMemes)
 *   --dry-run             Test without importing (recommended first!)
 */

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';

dotenv.config();

const prisma = new PrismaClient();

// Parse command line arguments
function parseArgs() {
  const args: Record<string, string | boolean> = {};
  const argv = process.argv.slice(2);
  
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2).replace(/-/g, '');
      if (key === 'dryrun') {
        args['dry-run'] = true;
      } else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
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
const MEMES_DIR = (args['memesdir'] as string) || 'E:\\day_party\\GoodMemes';
const DRY_RUN = args['dry-run'] === true || process.env.DRY_RUN === 'true';

const TOPIC_NAME = 'ממים';
const PUBLIC_MEMES_DIR = path.join(__dirname, '../public/memes');

// Supported image extensions
const IMAGE_EXTENSIONS = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];

/**
 * Get or create admin user
 */
async function getOrCreateAdminUser() {
  let adminUser = await prisma.user.findFirst({
    where: { role: 'admin' },
  });

  if (!adminUser) {
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
 * Get or create the memes topic
 */
async function getOrCreateMemesTopic(adminUserId: string) {
  const existingTopic = await prisma.topic.findFirst({
    where: {
      name: TOPIC_NAME,
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
      description: 'תמונות וסרטונים מצחיקים להארת האווירה בדיונים',
      visibility: 'public',
      createdBy: adminUserId,
    },
  });

  console.log(`✅ Created topic: ${TOPIC_NAME}`);
  return topic;
}

/**
 * Copy image to public directory and return public URL
 */
function copyImageToPublic(imagePath: string): string | null {
  try {
    // Ensure public/memes directory exists
    if (!fs.existsSync(PUBLIC_MEMES_DIR)) {
      fs.mkdirSync(PUBLIC_MEMES_DIR, { recursive: true });
    }

    const fileName = path.basename(imagePath);
    const destPath = path.join(PUBLIC_MEMES_DIR, fileName);
    
    // Copy file to public directory
    fs.copyFileSync(imagePath, destPath);
    
    // Return public URL (relative to server root)
    return `/memes/${encodeURIComponent(fileName)}`;
  } catch (error: any) {
    console.error(`  ❌ Error copying image ${imagePath}:`, error.message);
    return null;
  }
}

/**
 * Create Delta JSON with embedded image
 * Uses relative URLs so the client can construct the correct absolute URL based on device type
 */
function createImageDelta(imageUrl: string, fileName: string): string {
  // Use relative URL - the Flutter app will construct the absolute URL based on device type
  // This ensures images work on both emulator (10.0.2.2:3000) and physical devices (Azure VM)
  const relativeUrl = imageUrl.startsWith('http') 
    ? imageUrl.replace(/^https?:\/\/[^\/]+/, '') // Extract path from absolute URL
    : imageUrl; // Already relative
  
  // Create Delta JSON with an image embed
  // Using HTML format since Delta doesn't natively support images
  const htmlContent = `<img src="${relativeUrl}" alt="${fileName}" style="max-width: 100%; height: auto;" />`;
  
  // Convert to Delta format (simplified - just insert the HTML)
  const delta = {
    ops: [
      { insert: htmlContent },
      { insert: '\n' }
    ]
  };
  
  return JSON.stringify(delta);
}

/**
 * Import a single meme image
 */
async function importMeme(
  imagePath: string,
  topicId: string,
  adminUserId: string
): Promise<string | null> {
  try {
    const fileName = path.basename(imagePath);
    const title = fileName.replace(/\.[^/.]+$/, ''); // Remove extension
    
    if (DRY_RUN) {
      console.log(`  📸 Would import: ${fileName}`);
      return null;
    }

    // Copy image to public directory
    console.log(`  📤 Copying ${fileName}...`);
    const imageUrl = copyImageToPublic(imagePath);
    
    if (!imageUrl) {
      console.error(`  ❌ Failed to copy ${fileName}`);
      return null;
    }
    
    console.log(`  ✅ Copied: ${imageUrl}`);

    // Create Delta content with embedded image
    const deltaContent = createImageDelta(imageUrl, fileName);

    // Create thread
    const thread = await prisma.thread.create({
      data: {
        id: randomUUID(),
        topicId: topicId,
        title: title.substring(0, 500),
        description: null,
        createdBy: adminUserId,
        status: 'open',
      },
    });

    // Create root node with the image
    await prisma.node.create({
      data: {
        id: randomUUID(),
        threadId: thread.id,
        parentNodeId: null,
        parentRelation: null,
        title: title.substring(0, 500),
        textContent: deltaContent,
        textFormat: 'delta',
        authorId: adminUserId,
        isAnonymous: false,
        moderationState: 'visible',
        textStatus: 'provided',
        videoStatus: 'missing',
        votingEnabled: false, // Memes are not votable
        createdAt: new Date(),
      },
    });

    console.log(`  ✅ Created thread: ${title.substring(0, 50)}...`);
    return thread.id;
  } catch (error: any) {
    console.error(`  ❌ Error importing meme ${imagePath}:`, error.message);
    return null;
  }
}

/**
 * Main import function
 */
async function importMemes() {
  try {
    console.log('🎭 Starting meme images import...\n');

    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
    }

    // Check if directory exists
    if (!fs.existsSync(MEMES_DIR)) {
      console.error(`❌ Directory not found: ${MEMES_DIR}`);
      process.exit(1);
    }

    // Get admin user
    const adminUser = await getOrCreateAdminUser();

    // Get or create memes topic
    const topic = await getOrCreateMemesTopic(adminUser.id);

    // Find all image files
    const files = fs.readdirSync(MEMES_DIR);
    const imageFiles = files.filter(file => {
      const ext = path.extname(file).toLowerCase();
      return IMAGE_EXTENSIONS.includes(ext);
    });

    if (imageFiles.length === 0) {
      console.log('ℹ️  No image files found in directory');
      return;
    }

    console.log(`📁 Found ${imageFiles.length} image file(s)\n`);

    // Import each image
    let successCount = 0;
    let failCount = 0;

    for (const file of imageFiles) {
      const imagePath = path.join(MEMES_DIR, file);
      const threadId = await importMeme(imagePath, topic.id, adminUser.id);
      
      if (threadId) {
        successCount++;
      } else if (!DRY_RUN) {
        failCount++;
      }
    }

    console.log(`\n✅ Import complete!`);
    console.log(`   Success: ${successCount}`);
    if (!DRY_RUN && failCount > 0) {
      console.log(`   Failed: ${failCount}`);
    }
  } catch (error: any) {
    console.error('❌ Fatal error:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

importMemes()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

