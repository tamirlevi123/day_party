/**
 * Import script for comments from text file
 * 
 * This script imports comments from the proposals_comments.txt file
 * and creates nodes as replies to the proposal nodes (root nodes) in threads.
 * 
 * Usage:
 *   tsx scripts/import-comments.ts --comments-file "C:\Temp\proposals_comments.txt" [--dry-run]
 * 
 * Arguments:
 *   --comments-file <path>   Path to comments text file (required)
 *   --dry-run                Test parsing without importing (recommended first!)
 */

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import * as fs from 'fs';
import { htmlToDelta } from './html-to-delta';
import { parseCommentsText, CommentData } from './parse-comments-text';

dotenv.config();

const prisma = new PrismaClient();

// Parse command line arguments
function parseArgs() {
  const args: Record<string, string | boolean> = {};
  const argv = process.argv.slice(2);
  
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      if (key === 'dry-run') {
        args[key] = true;
      } else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        args[key] = argv[i + 1];
        i++;
      }
    }
  }
  
  return args;
}

const args = parseArgs();
const COMMENTS_FILE = args['comments-file'] as string | undefined;
const DRY_RUN = args['dry-run'] === true;

/**
 * Get or create a user for importing based on author name
 * Creates a user for each unique author name
 */
const authorUserMap = new Map<string, string>(); // authorName -> userId

async function getOrCreateImportUser(authorName?: string): Promise<string> {
  // If no author name, use default import user
  if (!authorName || authorName.trim().length === 0) {
    return getOrCreateDefaultImportUser();
  }

  const normalizedName = authorName.trim();
  
  // Check cache first
  if (authorUserMap.has(normalizedName)) {
    return authorUserMap.get(normalizedName)!;
  }

  // Try to find existing user by display name (case-sensitive exact match)
  // This will catch users created during proposal import
  const existingUser = await prisma.user.findFirst({
    where: { displayName: normalizedName },
  });

  if (existingUser) {
    authorUserMap.set(normalizedName, existingUser.id);
    console.log(`  ♻️  Reusing existing user: ${normalizedName} (${existingUser.email})`);
    return existingUser.id;
  }

  // Create new user for this author
  // Generate a unique email based on author name
  const emailBase = normalizedName
    .toLowerCase()
    .replace(/[^a-z0-9א-ת]/g, '_')
    .substring(0, 50);
  const email = `${emailBase}_import@dayparty.com`;

  // Make sure email is unique
  let uniqueEmail = email;
  let counter = 1;
  while (await prisma.user.findUnique({ where: { email: uniqueEmail } })) {
    uniqueEmail = `${emailBase}_${counter}_import@dayparty.com`;
    counter++;
  }

  const newUser = await prisma.user.create({
    data: {
      id: randomUUID(),
      displayName: normalizedName,
      email: uniqueEmail,
      locale: 'he-IL',
      role: 'user',
    },
  });

  authorUserMap.set(normalizedName, newUser.id);
  console.log(`  👤 Created user: ${normalizedName} (${uniqueEmail})`);
  return newUser.id;
}

/**
 * Get or create default import user (for comments without authors)
 */
async function getOrCreateDefaultImportUser(): Promise<string> {
  const defaultUser = await prisma.user.findFirst({
    where: { email: 'import@dayparty.com' },
  });

  if (defaultUser) {
    return defaultUser.id;
  }

  const importUser = await prisma.user.create({
    data: {
      id: randomUUID(),
      displayName: 'Import User',
      email: 'import@dayparty.com',
      locale: 'he-IL',
      role: 'user',
    },
  });

  return importUser.id;
}

/**
 * Convert comment body to Delta format
 */
function convertToDelta(content: string | null | undefined): string {
  if (!content || content.trim().length === 0) {
    return JSON.stringify({ ops: [{ insert: '\n' }] });
  }

  // Check if it's already HTML
  const isHtml = /<[a-z][\s\S]*>/i.test(content);
  
  if (isHtml) {
    return htmlToDelta(content);
  }

  // Plain text - convert to Delta
  const lines = content.split('\n').filter(line => line.trim().length > 0);
  if (lines.length === 0) {
    return JSON.stringify({ ops: [{ insert: '\n' }] });
  }

  const ops = lines.map((line, index) => ({
    insert: line + (index < lines.length - 1 ? '\n' : ''),
  }));

  // Ensure ends with newline
  if (!ops[ops.length - 1].insert.endsWith('\n')) {
    ops.push({ insert: '\n' });
  }

  return JSON.stringify({ ops });
}

/**
 * Import a comment as a neutral node
 */
async function importComment(
  comment: CommentData,
  threadId: string,
  parentNodeId: string | null,
  authorUserId: string
): Promise<string | null> {
  try {
    const body = comment.body || '';
    if (!body.trim()) {
      return null; // Skip empty comments
    }

    const deltaContent = convertToDelta(body);
    const title = body.substring(0, 200).replace(/\n/g, ' ').trim() || 'תגובה';

    // Parse created date
    const createdAt = comment.createdAt ? new Date(comment.createdAt) : new Date();

    // Create node
    const node = await prisma.node.create({
      data: {
        id: randomUUID(),
        threadId: threadId,
        parentNodeId: parentNodeId,
        parentRelation: parentNodeId ? 'neutral' : null, // Neutral relation for comments
        title: title.substring(0, 500),
        textContent: deltaContent,
        textFormat: 'delta',
        authorId: authorUserId,
        isAnonymous: false,
        moderationState: 'visible',
        textStatus: 'provided',
        videoStatus: 'missing',
        votingEnabled: true,
        createdAt: createdAt,
      },
    });

    return node.id;
  } catch (error: any) {
    console.error(`  ❌ Error importing comment ${comment.id}:`, error.message);
    return null;
  }
}

/**
 * Pre-load all existing users into cache
 * This ensures we reuse users created during proposal import
 */
async function preloadExistingUsers(): Promise<void> {
  console.log('👤 Pre-loading existing users...\n');
  
  const existingUsers = await prisma.user.findMany({
    select: {
      id: true,
      displayName: true,
      email: true,
    },
  });

  for (const user of existingUsers) {
    if (user.displayName) {
      authorUserMap.set(user.displayName.trim(), user.id);
    }
  }

  console.log(`  ✅ Loaded ${existingUsers.length} existing users into cache\n`);
}

/**
 * Main import function
 */
async function importComments() {
  try {
    console.log('🚀 Starting comment import...\n');
    
    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
    }

    if (!COMMENTS_FILE || !fs.existsSync(COMMENTS_FILE)) {
      throw new Error(`Comments file not found: ${COMMENTS_FILE || 'not specified'}`);
    }

    // Parse comments from text file
    console.log(`📁 Parsing comments file: ${COMMENTS_FILE}\n`);
    const comments = parseCommentsText(COMMENTS_FILE);
    console.log(`✅ Parsed ${comments.length} comments\n`);

    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
      
      // Print sample comments
      console.log('📋 Sample Comments (first 10):');
      console.log('='.repeat(80));
      for (let i = 0; i < Math.min(10, comments.length); i++) {
        const c = comments[i];
        console.log(`\nComment ${i + 1}:`);
        console.log(`  ID: ${c.id}`);
        console.log(`  Proposal ID: ${c.proposalId}`);
        console.log(`  Proposal Title: ${c.proposalTitle}`);
        console.log(`  Author: ${c.authorName}`);
        console.log(`  Parent Comment ID: ${c.parentCommentId || '(root)'}`);
        console.log(`  Created: ${c.createdAt}`);
        console.log(`  Body length: ${c.body.length} chars`);
        if (c.body) {
          const preview = c.body.substring(0, 150).replace(/\n/g, ' ');
          console.log(`  Body preview: ${preview}...`);
        }
      }
      
      // Print statistics
      console.log('\n\n📊 Statistics:');
      console.log('='.repeat(80));
      console.log(`Total comments: ${comments.length}`);
      
      const rootComments = comments.filter(c => !c.parentCommentId).length;
      const replyComments = comments.length - rootComments;
      const uniqueAuthors = new Set(comments.map(c => c.authorName)).size;
      const uniqueProposals = new Set(comments.map(c => c.proposalId)).size;
      
      console.log(`\nComments:`);
      console.log(`  Root comments: ${rootComments}`);
      console.log(`  Reply comments: ${replyComments}`);
      console.log(`  Unique authors: ${uniqueAuthors}`);
      console.log(`  Unique proposals: ${uniqueProposals}`);
      
      // Group comments by proposal
      const commentsByProposal = new Map<number, number>();
      for (const c of comments) {
        const count = commentsByProposal.get(c.proposalId) || 0;
        commentsByProposal.set(c.proposalId, count + 1);
      }
      
      console.log(`\nComments per proposal:`);
      const sortedProposals = Array.from(commentsByProposal.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10);
      for (const [proposalId, count] of sortedProposals) {
        const proposal = comments.find(c => c.proposalId === proposalId);
        console.log(`  Proposal ${proposalId} (${proposal?.proposalTitle.substring(0, 40)}...): ${count} comments`);
      }
      
      console.log('\n✅ Dry run complete - no data imported\n');
      return;
    }

    // Get the topic
    const topic = await prisma.topic.findFirst({
      where: { name: 'אזרחים כותבים חוקה' },
    });

    if (!topic) {
      throw new Error('Topic "אזרחים כותבים חוקה" not found. Please import proposals first.');
    }

    // Pre-load existing users (including those created during proposal import)
    const usersBeforeImport = await prisma.user.count();
    await preloadExistingUsers();
    const initialCacheSize = authorUserMap.size;

    // Get all threads in this topic with their root nodes
    // Comments should be attached to the root node (proposal node), not the thread
    const threads = await prisma.thread.findMany({
      where: { topicId: topic.id },
      include: {
        nodes: {
          where: { parentNodeId: null }, // Get root nodes only
          take: 1,
          select: {
            id: true,
          },
        },
      },
    });

    console.log(`📋 Found ${threads.length} threads in topic\n`);

    // Build mapping: proposal title -> root node ID (for root comments)
    // Also: proposal title -> thread ID (for finding threads)
    const proposalTitleToRootNodeId = new Map<string, string>();
    const proposalTitleToThreadId = new Map<string, string>();
    
    for (const thread of threads) {
      const rootNode = thread.nodes[0];
      if (rootNode) {
        proposalTitleToRootNodeId.set(thread.title.trim(), rootNode.id);
        proposalTitleToThreadId.set(thread.title.trim(), thread.id);
      }
    }

    // Import comments
    console.log(`📥 Importing ${comments.length} comments...\n`);
    const nodeMap = new Map<number, string>(); // comment_id -> node_id
    let importedNodes = 0;
    let failedNodes = 0;
    let skippedComments = 0;

    // First pass: import root comments (no parent)
    // Root comments should be children of the proposal's root node
    for (const comment of comments) {
      const threadId = proposalTitleToThreadId.get(comment.proposalTitle.trim());
      const rootNodeId = proposalTitleToRootNodeId.get(comment.proposalTitle.trim());
      
      if (!threadId || !rootNodeId) {
        console.log(`  ⚠️  Skipping comment ${comment.id}: Thread/root node not found for proposal "${comment.proposalTitle}"`);
        skippedComments++;
        continue;
      }

      // Only process root comments in first pass
      // Root comments are attached to the proposal's root node
      if (!comment.parentCommentId) {
        const authorUserId = await getOrCreateImportUser(comment.authorName);
        const nodeId = await importComment(comment, threadId, rootNodeId, authorUserId);
        if (nodeId) {
          nodeMap.set(comment.id, nodeId);
          importedNodes++;
        } else {
          failedNodes++;
        }
      }
    }

    // Second pass: import reply comments (with parent)
    // Process in order to ensure parents are imported first
    const replyComments = comments.filter(c => c.parentCommentId !== null);
    replyComments.sort((a, b) => {
      // Sort by parent comment ID to ensure parents come before children
      const aParent = a.parentCommentId || 0;
      const bParent = b.parentCommentId || 0;
      return aParent - bParent;
    });

    for (const comment of replyComments) {
      const threadId = proposalTitleToThreadId.get(comment.proposalTitle.trim());
      
      if (!threadId) {
        skippedComments++;
        continue;
      }

      // Get parent node ID from comment ID mapping
      const parentNodeId = comment.parentCommentId ? nodeMap.get(comment.parentCommentId) : null;

      // If parent node doesn't exist, skip (orphaned reply)
      if (!parentNodeId) {
        console.log(`  ⚠️  Skipping comment ${comment.id}: Parent comment ${comment.parentCommentId} not found`);
        skippedComments++;
        continue;
      }

      const authorUserId = await getOrCreateImportUser(comment.authorName);
      const nodeId = await importComment(comment, threadId, parentNodeId, authorUserId);
      if (nodeId) {
        nodeMap.set(comment.id, nodeId);
        importedNodes++;
      } else {
        failedNodes++;
      }
    }

    console.log(`\n📊 Nodes imported: ${importedNodes}, failed: ${failedNodes}, skipped: ${skippedComments}\n`);

    console.log('✅ Import complete!\n');

    // Count how many users were reused vs created
    const totalUniqueAuthors = new Set(comments.map(c => c.authorName?.trim()).filter(Boolean)).size;
    const usersAfterImport = await prisma.user.count();
    const usersCreated = usersAfterImport - usersBeforeImport;
    const usersReused = totalUniqueAuthors - usersCreated;
    
    console.log('📈 Summary:');
    console.log(`  Comments processed: ${comments.length}`);
    console.log(`  Nodes created: ${importedNodes} (${failedNodes} failed, ${skippedComments} skipped)`);
    console.log(`  Unique authors found: ${totalUniqueAuthors}`);
    console.log(`  Users reused: ${usersReused} (from proposal import)`);
    console.log(`  Users created: ${usersCreated} (new comment authors)`);
    console.log(`  Total users in database: ${usersAfterImport}`);
  } catch (error: any) {
    console.error('❌ Import failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Show usage if no arguments provided
if (!COMMENTS_FILE) {
  console.log(`
Usage:
  tsx scripts/import-comments.ts [options]

Options:
  --comments-file <path>   Path to comments text file (required)
  --dry-run                Test parsing without importing

Examples:
  # Test parsing from comments file:
  tsx scripts/import-comments.ts --comments-file "C:\\Temp\\proposals_comments.txt" --dry-run
  
  # Import comments:
  tsx scripts/import-comments.ts --comments-file "C:\\Temp\\proposals_comments.txt"
`);
  process.exit(0);
}

// Run import
importComments()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

