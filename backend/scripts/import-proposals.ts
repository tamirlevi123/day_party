/**
 * Import script for proposals from PostgreSQL database or dump file
 * 
 * This script imports proposals from the "אזרחים כותבים חוקה" PostgreSQL database
 * or dump file and creates threads and nodes in the Day Party platform.
 * 
 * Usage:
 *   # From dump file (recommended):
 *   tsx scripts/import-proposals.ts --dump-file "C:\Temp\consul_production_backup_21_05_2025.dump" --locale he --dry-run
 *   
 *   # From live database:
 *   tsx scripts/import-proposals.ts --host localhost --port 5432 --user postgres --password pass --database consul_production --locale he
 * 
 * Arguments:
 *   --dump-file <path>     Path to PostgreSQL dump file (alternative to DB connection)
 *   --host <host>          Source PostgreSQL host (default: localhost)
 *   --port <port>          Source PostgreSQL port (default: 5432)
 *   --user <user>          Source PostgreSQL user (default: postgres)
 *   --password <password>  Source PostgreSQL password
 *   --database <name>      Source PostgreSQL database name (default: consul_production)
 *   --locale <locale>      Locale for translations (default: he)
 *   --dry-run              Test parsing without importing (recommended first!)
 */

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import { Pool } from 'pg';
import * as fs from 'fs';
import { execSync } from 'child_process';
import { htmlToDelta } from './html-to-delta';
import { parsePgDumpDirect } from './parse-pg-dump-direct';
import { parseProposalsText } from './parse-proposals-text';

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
      } else {
        args[key] = true;
      }
    }
  }
  
  return args;
}

const args = parseArgs();

// Source database configuration (from args or env vars as fallback)
const SOURCE_DB_CONFIG = {
  host: (args['host'] as string) || process.env.SOURCE_DB_HOST || 'localhost',
  port: parseInt((args['port'] as string) || process.env.SOURCE_DB_PORT || '5432', 10),
  user: (args['user'] as string) || process.env.SOURCE_DB_USER || 'postgres',
  password: (args['password'] as string) || process.env.SOURCE_DB_PASSWORD || '',
  database: (args['database'] as string) || process.env.SOURCE_DB_NAME || 'consul_production',
};

const SOURCE_LOCALE = (args['locale'] as string) || process.env.SOURCE_DB_LOCALE || 'he';
const DRY_RUN = args['dry-run'] === true || process.env.DRY_RUN === 'true' || process.env.DRY_RUN === '1';
const DUMP_FILE = (args['dump-file'] as string) || process.env.SOURCE_DB_DUMP_FILE;
const TEXT_FILE = (args['text-file'] as string) || process.env.SOURCE_TEXT_FILE;

// Topic name
const TOPIC_NAME = 'אזרחים כותבים חוקה';
const TOPIC_DESCRIPTION = 'הצעות ודיונים מאתר החקיקה האזרחי';

interface ProposalRow {
  id: number;
  title: string;
  description: string | null;
  summary: string | null;
  author_id: number | null;
  author_name?: string; // For text file imports
  created_at: Date | string;
  published_at: Date | string | null;
}

interface CommentRow {
  id: number;
  commentable_id: number;
  commentable_type: string;
  body: string | null;
  user_id: number;
  created_at: Date | string;
  ancestry: string | null; // For nested comments: "1/2/3" format
}

/**
 * Get or create the import topic
 */
async function getOrCreateTopic(adminUserId: string) {
  // Try to find existing topic
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

  // Create new topic
  const topic = await prisma.topic.create({
    data: {
      id: randomUUID(),
      name: TOPIC_NAME,
      description: TOPIC_DESCRIPTION,
      visibility: 'public',
      createdBy: adminUserId,
    },
  });

  console.log(`✅ Created topic: ${TOPIC_NAME}`);
  return topic;
}

/**
 * Get or create a user for importing based on author name
 * Creates a user for each unique author name
 */
const authorUserMap = new Map<string, string>(); // authorName -> userId
const authorIdToUserIdMap = new Map<number, string>(); // source author_id -> Day Party userId

/**
 * Pre-create all users for thread creators before importing threads
 * This ensures users exist and are properly mapped before thread creation
 */
async function preCreateUsersForAuthors(
  proposals: ProposalRow[],
  authorIdToNameMap: Map<number, string>
): Promise<void> {
  console.log('👤 Pre-creating users for thread creators...\n');
  
  // Collect all unique author names
  const uniqueAuthorNames = new Set<string>();
  
  for (const proposal of proposals) {
    if (proposal.author_id && authorIdToNameMap.has(proposal.author_id)) {
      const authorName = authorIdToNameMap.get(proposal.author_id)!;
      if (authorName && authorName.trim().length > 0) {
        uniqueAuthorNames.add(authorName.trim());
      }
    } else if (proposal.author_name && proposal.author_name.trim().length > 0) {
      uniqueAuthorNames.add(proposal.author_name.trim());
    }
  }
  
  console.log(`  Found ${uniqueAuthorNames.size} unique authors\n`);
  
  // Create or get users for each author name
  for (const authorName of uniqueAuthorNames) {
    const normalizedName = authorName.trim();
    
    // Check cache first
    if (authorUserMap.has(normalizedName)) {
      continue;
    }
    
    // Try to find existing user by display name
    const existingUser = await prisma.user.findFirst({
      where: { displayName: normalizedName },
    });
    
    if (existingUser) {
      authorUserMap.set(normalizedName, existingUser.id);
      continue;
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
    console.log(`  ✅ Created user: ${normalizedName} (${uniqueEmail})`);
  }
  
  // Build author_id -> userId mapping
  for (const proposal of proposals) {
    if (proposal.author_id && authorIdToNameMap.has(proposal.author_id)) {
      const authorName = authorIdToNameMap.get(proposal.author_id)!;
      if (authorName && authorUserMap.has(authorName.trim())) {
        authorIdToUserIdMap.set(proposal.author_id, authorUserMap.get(authorName.trim())!);
      }
    } else if (proposal.author_name && authorUserMap.has(proposal.author_name.trim())) {
      // For text file imports, we don't have author_id, so we'll use author_name directly
      // This will be handled in importProposal
    }
  }
  
  console.log(`\n✅ Pre-created ${authorUserMap.size} users\n`);
}

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

  // Try to find existing user by display name
  const existingUser = await prisma.user.findFirst({
    where: { displayName: normalizedName },
  });

  if (existingUser) {
    authorUserMap.set(normalizedName, existingUser.id);
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
 * Get or create default import user (for proposals without authors)
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
 * Convert proposal body to Delta format
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
 * Import a single proposal as a thread with root node
 */
async function importProposal(
  proposal: ProposalRow,
  topicId: string
): Promise<string | null> {
  try {
    const title = proposal.title?.trim() || `הצעה ${proposal.id}`;
    // Use description if available, otherwise summary, otherwise empty
    const body = proposal.description || proposal.summary || '';
    const deltaContent = convertToDelta(body);

    // Use published_at if available, otherwise created_at
    const createdAt = proposal.published_at 
      ? new Date(proposal.published_at) 
      : (proposal.created_at ? new Date(proposal.created_at) : new Date());

    // Get user for this author
    // First try to get from author_id mapping (for database/dump imports)
    let authorUserId: string;
    if (proposal.author_id && authorIdToUserIdMap.has(proposal.author_id)) {
      authorUserId = authorIdToUserIdMap.get(proposal.author_id)!;
    } else if (proposal.author_name) {
      // Fall back to author_name (for text file imports or if mapping not found)
      authorUserId = await getOrCreateImportUser(proposal.author_name);
    } else {
      // No author info - use default import user
      authorUserId = await getOrCreateDefaultImportUser();
    }

    // Create thread
    const thread = await prisma.thread.create({
      data: {
        id: randomUUID(),
        topicId: topicId,
        title: title.substring(0, 500), // Ensure title fits
        description: deltaContent, // Keep description for thread list preview
        createdBy: authorUserId,
        status: 'open',
        createdAt: createdAt,
      },
    });

    // Create root node with the proposal description as content
    // This matches the behavior when creating threads organically
    if (body.trim().length > 0) {
      await prisma.node.create({
        data: {
          id: randomUUID(),
          threadId: thread.id,
          parentNodeId: null,
          parentRelation: null,
          title: title.substring(0, 500), // Use proposal title as node title
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
    }

    // Get author name for logging (use proposal author_name if available, otherwise lookup from map)
    const authorName = proposal.author_name || 
      (proposal.author_id && authorIdToUserIdMap.has(proposal.author_id) ? 'user' : 'unknown');
    console.log(`  ✅ Created thread with root node: ${title.substring(0, 50)}... (author: ${authorName})`);
    return thread.id;
  } catch (error: any) {
    console.error(`  ❌ Error importing proposal ${proposal.id}:`, error.message);
    return null;
  }
}

/**
 * Import a comment as a neutral node
 */
async function importComment(
  comment: CommentRow,
  threadId: string,
  parentNodeId: string | null,
  importUserId: string
): Promise<string | null> {
  try {
    const body = comment.body || '';
    if (!body.trim()) {
      return null; // Skip empty comments
    }

    const deltaContent = convertToDelta(body);
    const title = body.substring(0, 200).replace(/\n/g, ' ').trim() || 'תגובה';

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
        authorId: importUserId,
        isAnonymous: false,
        moderationState: 'visible',
        textStatus: 'provided',
        videoStatus: 'missing',
        votingEnabled: true,
        createdAt: comment.created_at ? new Date(comment.created_at) : new Date(),
      },
    });

    return node.id;
  } catch (error: any) {
    console.error(`  ❌ Error importing comment ${comment.id}:`, error.message);
    return null;
  }
}

/**
 * Parse ancestry string to get parent comment ID
 * Ancestry format: "1/2/3" where 3 is the immediate parent
 */
function getParentCommentId(ancestry: string | null): number | null {
  if (!ancestry || ancestry.trim().length === 0) {
    return null;
  }
  const parts = ancestry.split('/');
  if (parts.length === 0) {
    return null;
  }
  // Get the last part (immediate parent)
  const parentId = parseInt(parts[parts.length - 1], 10);
  return isNaN(parentId) ? null : parentId;
}

/**
 * Extract data from dump file by parsing it directly
 */
async function extractDataFromDump(dumpFilePath: string): Promise<{ 
  proposals: ProposalRow[], 
  comments: CommentRow[],
  authorIdToNameMap: Map<number, string>
}> {
  console.log(`📦 Parsing dump file directly: ${dumpFilePath}\n`);
  
  try {
    // Parse the dump file directly
    const tableData = await parsePgDumpDirect(dumpFilePath);
    
    // Extract proposals data
    const proposalsData = tableData.get('proposals');
    const proposalTranslationsData = tableData.get('proposal_translations');
    
    if (!proposalsData) {
      throw new Error('proposals table not found in dump file');
    }
    
    // Extract comments data
    const commentsData = tableData.get('comments');
    const commentTranslationsData = tableData.get('comment_translations');
    
    if (!commentsData) {
      throw new Error('comments table not found in dump file');
    }
    
    // Helper to get column index safely
    const getColIdx = (colMap: Map<string, number>, colName: string): number | null => {
      const idx = colMap.get(colName.toLowerCase());
      return idx !== undefined ? idx : null;
    };
    
    // Extract users data to get author names
    const usersData = tableData.get('users');
    const authorIdToNameMap = new Map<number, string>();
    
    if (usersData) {
      const usersCols = usersData.columns;
      const usersColMap = new Map(usersCols.map((col, idx) => [col.toLowerCase(), idx]));
      const userIdIdx = getColIdx(usersColMap, 'id');
      const nameIdx = getColIdx(usersColMap, 'name') ?? getColIdx(usersColMap, 'display_name') ?? getColIdx(usersColMap, 'username');
      
      if (userIdIdx !== null && nameIdx !== null) {
        for (const row of usersData.rows) {
          const userId = parseInt(String(row[userIdIdx] || ''), 10);
          const name = String(row[nameIdx] || '').trim();
          if (!isNaN(userId) && name.length > 0) {
            authorIdToNameMap.set(userId, name);
          }
        }
        console.log(`  Found ${authorIdToNameMap.size} users in dump file\n`);
      }
    }
    
    // Map column names to indices
    const proposalsCols = proposalsData.columns;
    const proposalsColMap = new Map(proposalsCols.map((col, idx) => [col.toLowerCase(), idx]));
    
    const proposalTranslationsCols = proposalTranslationsData?.columns || [];
    const proposalTranslationsColMap = new Map(proposalTranslationsCols.map((col, idx) => [col.toLowerCase(), idx]));
    
    const commentsCols = commentsData.columns;
    const commentsColMap = new Map(commentsCols.map((col, idx) => [col.toLowerCase(), idx]));
    
    const commentTranslationsCols = commentTranslationsData?.columns || [];
    const commentTranslationsColMap = new Map(commentTranslationsCols.map((col, idx) => [col.toLowerCase(), idx]));
    
    // Build proposals with translations
    const proposals: ProposalRow[] = [];
    const proposalTranslationsByProposalId = new Map<number, Map<string, any>>();
    
    // Index translations by proposal_id and locale
    if (proposalTranslationsData) {
      const proposalIdIdx = getColIdx(proposalTranslationsColMap, 'proposal_id');
      const localeIdx = getColIdx(proposalTranslationsColMap, 'locale');
      const titleIdx = getColIdx(proposalTranslationsColMap, 'title');
      const descriptionIdx = getColIdx(proposalTranslationsColMap, 'description');
      const summaryIdx = getColIdx(proposalTranslationsColMap, 'summary');
      
      if (proposalIdIdx !== null && localeIdx !== null) {
        for (const row of proposalTranslationsData.rows) {
          const proposalId = parseInt(String(row[proposalIdIdx] || ''), 10);
          const locale = String(row[localeIdx] || '');
          
          if (!isNaN(proposalId) && locale) {
            if (!proposalTranslationsByProposalId.has(proposalId)) {
              proposalTranslationsByProposalId.set(proposalId, new Map());
            }
            
            const translationMap = proposalTranslationsByProposalId.get(proposalId)!;
            translationMap.set(locale, {
              title: titleIdx !== null ? row[titleIdx] : null,
              description: descriptionIdx !== null ? row[descriptionIdx] : null,
              summary: summaryIdx !== null ? row[summaryIdx] : null,
            });
          }
        }
      }
    }
    
    // Build proposals array
    const idIdx = getColIdx(proposalsColMap, 'id');
    const authorIdIdx = getColIdx(proposalsColMap, 'author_id');
    const createdAtIdx = getColIdx(proposalsColMap, 'created_at');
    const publishedAtIdx = getColIdx(proposalsColMap, 'published_at');
    
    if (idIdx === null || createdAtIdx === null || publishedAtIdx === null) {
      throw new Error('Missing required columns in proposals table');
    }
    
    for (const row of proposalsData.rows) {
      const id = parseInt(String(row[idIdx] || ''), 10);
      const publishedAt = row[publishedAtIdx];
      
      // Only include published proposals
      if (isNaN(id) || !publishedAt) continue;
      
      const translation = proposalTranslationsByProposalId.get(id)?.get(SOURCE_LOCALE);
      
      proposals.push({
        id,
        author_id: authorIdIdx !== null && row[authorIdIdx] ? parseInt(String(row[authorIdIdx]), 10) : null,
        created_at: String(row[createdAtIdx] || ''),
        published_at: String(publishedAt),
        title: translation?.title ? String(translation.title) : null,
        description: translation?.description ? String(translation.description) : null,
        summary: translation?.summary ? String(translation.summary) : null,
      });
    }
    
    // Build comments with translations
    const comments: CommentRow[] = [];
    const commentTranslationsByCommentId = new Map<number, Map<string, any>>();
    
    // Index comment translations
    if (commentTranslationsData) {
      const commentIdIdx = getColIdx(commentTranslationsColMap, 'comment_id');
      const localeIdx = getColIdx(commentTranslationsColMap, 'locale');
      const bodyIdx = getColIdx(commentTranslationsColMap, 'body');
      
      if (commentIdIdx !== null && localeIdx !== null) {
        for (const row of commentTranslationsData.rows) {
          const commentId = parseInt(String(row[commentIdIdx] || ''), 10);
          const locale = String(row[localeIdx] || '');
          
          if (!isNaN(commentId) && locale) {
            if (!commentTranslationsByCommentId.has(commentId)) {
              commentTranslationsByCommentId.set(commentId, new Map());
            }
            
            const translationMap = commentTranslationsByCommentId.get(commentId)!;
            translationMap.set(locale, {
              body: bodyIdx !== null ? row[bodyIdx] : null,
            });
          }
        }
      }
    }
    
    // Build comments array
    const commentIdIdx = getColIdx(commentsColMap, 'id');
    const commentableIdIdx = getColIdx(commentsColMap, 'commentable_id');
    const commentableTypeIdx = getColIdx(commentsColMap, 'commentable_type');
    const userIdIdx = getColIdx(commentsColMap, 'user_id');
    const commentCreatedAtIdx = getColIdx(commentsColMap, 'created_at');
    const ancestryIdx = getColIdx(commentsColMap, 'ancestry');
    
    if (commentIdIdx === null || commentableIdIdx === null || commentableTypeIdx === null || userIdIdx === null || commentCreatedAtIdx === null) {
      throw new Error('Missing required columns in comments table');
    }
    
    for (const row of commentsData.rows) {
      const commentableType = String(row[commentableTypeIdx] || '');
      
      // Only include Proposal comments
      if (commentableType !== 'Proposal') continue;
      
      const id = parseInt(String(row[commentIdIdx] || ''), 10);
      if (isNaN(id)) continue;
      
      const translation = commentTranslationsByCommentId.get(id)?.get(SOURCE_LOCALE);
      
      comments.push({
        id,
        commentable_id: parseInt(String(row[commentableIdIdx] || ''), 10),
        commentable_type: commentableType,
        user_id: parseInt(String(row[userIdIdx] || ''), 10),
        created_at: String(row[commentCreatedAtIdx] || ''),
        ancestry: ancestryIdx !== null && row[ancestryIdx] ? String(row[ancestryIdx]) : null,
        body: translation?.body ? String(translation.body) : null,
      });
    }
    
    return { proposals, comments, authorIdToNameMap };
  } catch (error: any) {
    console.error('❌ Error parsing dump file:', error);
    throw new Error(`Failed to parse dump file: ${error.message}`);
  }
}

/**
 * Main import function
 */
async function importProposals() {
  let proposalRows: ProposalRow[] = [];
  let commentRows: CommentRow[] = [];
  let authorIdToNameMap = new Map<number, string>();
  
  try {
    console.log('🚀 Starting proposal import...\n');
    
    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
    }

    if (TEXT_FILE && fs.existsSync(TEXT_FILE)) {
      // Import from text file (simpler format)
      console.log(`📁 Using text file: ${TEXT_FILE}\n`);
      const proposals = parseProposalsText(TEXT_FILE);
      proposalRows = proposals.map(p => ({
        id: p.id,
        title: p.title,
        description: p.description || null,
        summary: null,
        author_id: null,
        author_name: p.authorName,
        created_at: new Date().toISOString(),
        published_at: new Date().toISOString(),
      }));
      commentRows = []; // No comments in text file format
      // authorIdToNameMap stays empty for text file imports (no author_id)
      console.log(`✅ Parsed ${proposalRows.length} proposals from text file\n`);
    } else if (DUMP_FILE && fs.existsSync(DUMP_FILE)) {
      // Import from dump file
      console.log(`📁 Using dump file: ${DUMP_FILE}\n`);
      const extracted = await extractDataFromDump(DUMP_FILE);
      proposalRows = extracted.proposals;
      commentRows = extracted.comments;
      authorIdToNameMap = extracted.authorIdToNameMap;
      console.log(`✅ Extracted ${proposalRows.length} proposals and ${commentRows.length} comments\n`);
    } else {
      // Import from live database
      const pool = new Pool(SOURCE_DB_CONFIG);
      
      try {
        console.log(`📡 Connecting to source database: ${SOURCE_DB_CONFIG.host}:${SOURCE_DB_CONFIG.port}/${SOURCE_DB_CONFIG.database}`);
        await pool.query('SELECT 1'); // Test connection
        console.log('✅ Connected to source database\n');

        // Fetch users to get author names
        console.log(`📥 Fetching users from source database...`);
        const usersQuery = `
          SELECT id, name, display_name, username
          FROM users
          WHERE id IS NOT NULL
        `;
        const usersResult = await pool.query(usersQuery);
        for (const user of usersResult.rows) {
          const userId = parseInt(String(user.id || ''), 10);
          const name = String(user.name || user.display_name || user.username || '').trim();
          if (!isNaN(userId) && name.length > 0) {
            authorIdToNameMap.set(userId, name);
          }
        }
        console.log(`✅ Found ${authorIdToNameMap.size} users\n`);

        // Fetch proposals with translations from source database
        console.log(`📥 Fetching proposals with translations (locale: ${SOURCE_LOCALE})...`);
        const proposalQuery = `
          SELECT 
            p.id,
            p.author_id,
            p.created_at,
            p.published_at,
            pt.title,
            pt.description,
            pt.summary
          FROM proposals p
          LEFT JOIN proposal_translations pt ON p.id = pt.proposal_id AND pt.locale = $1
          WHERE p.published_at IS NOT NULL
          ORDER BY p.created_at ASC
        `;
        const proposalResult = await pool.query<ProposalRow>(proposalQuery, [SOURCE_LOCALE]);
        proposalRows = proposalResult.rows;
        console.log(`✅ Found ${proposalRows.length} proposals\n`);

        // Fetch comments with translations from source database
        console.log(`📥 Fetching comments with translations (locale: ${SOURCE_LOCALE})...`);
        const commentQuery = `
          SELECT 
            c.id,
            c.commentable_id,
            c.commentable_type,
            c.user_id,
            c.created_at,
            c.ancestry,
            ct.body
          FROM comments c
          LEFT JOIN comment_translations ct ON c.id = ct.comment_id AND ct.locale = $1
          WHERE c.commentable_type = 'Proposal'
          ORDER BY c.created_at ASC
        `;
        const commentResult = await pool.query<CommentRow>(commentQuery, [SOURCE_LOCALE]);
        commentRows = commentResult.rows;
        console.log(`✅ Found ${commentRows.length} comments\n`);
      } finally {
        await pool.end();
      }
    }

    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
      
      // Print sample proposals
      console.log('📋 Sample Proposals (first 5):');
      console.log('='.repeat(80));
      for (let i = 0; i < Math.min(5, proposalRows.length); i++) {
        const p = proposalRows[i];
        console.log(`\nProposal ${i + 1}:`);
        console.log(`  ID: ${p.id}`);
        console.log(`  Title: ${p.title || '(no title)'}`);
        console.log(`  Description length: ${p.description?.length || 0} chars`);
        console.log(`  Summary length: ${p.summary?.length || 0} chars`);
        console.log(`  Author ID: ${p.author_id || '(none)'}`);
        console.log(`  Author Name: ${p.author_name || '(none)'}`);
        console.log(`  Created: ${p.created_at}`);
        console.log(`  Published: ${p.published_at}`);
        if (p.description) {
          const preview = p.description.substring(0, 200).replace(/\n/g, ' ');
          console.log(`  Description preview: ${preview}...`);
        }
      }
      
      // Print sample comments
      console.log('\n\n📋 Sample Comments (first 10):');
      console.log('='.repeat(80));
      for (let i = 0; i < Math.min(10, commentRows.length); i++) {
        const c = commentRows[i];
        console.log(`\nComment ${i + 1}:`);
        console.log(`  ID: ${c.id}`);
        console.log(`  Proposal ID: ${c.commentable_id}`);
        console.log(`  User ID: ${c.user_id}`);
        console.log(`  Ancestry: ${c.ancestry || '(root)'}`);
        console.log(`  Body length: ${c.body?.length || 0} chars`);
        console.log(`  Created: ${c.created_at}`);
        if (c.body) {
          const preview = c.body.substring(0, 150).replace(/\n/g, ' ');
          console.log(`  Body preview: ${preview}...`);
        }
      }
      
      // Print statistics
      console.log('\n\n📊 Statistics:');
      console.log('='.repeat(80));
      console.log(`Total proposals: ${proposalRows.length}`);
      console.log(`Total comments: ${commentRows.length}`);
      
      const proposalsWithTitle = proposalRows.filter(p => p.title).length;
      const proposalsWithDescription = proposalRows.filter(p => p.description).length;
      const commentsWithBody = commentRows.filter(c => c.body).length;
      const rootComments = commentRows.filter(c => !c.ancestry || c.ancestry.trim().length === 0).length;
      const nestedComments = commentRows.length - rootComments;
      
      console.log(`\nProposals:`);
      console.log(`  With title: ${proposalsWithTitle}`);
      console.log(`  With description: ${proposalsWithDescription}`);
      
      // Count unique authors and show author mapping
      const uniqueAuthorNames = new Set<string>();
      const uniqueAuthorIds = new Set<number>();
      
      for (const p of proposalRows) {
        if (p.author_name && p.author_name.trim().length > 0) {
          uniqueAuthorNames.add(p.author_name.trim());
        }
        if (p.author_id) {
          uniqueAuthorIds.add(p.author_id);
        }
      }
      
      console.log(`  Unique authors (by name): ${uniqueAuthorNames.size}`);
      console.log(`  Unique authors (by ID): ${uniqueAuthorIds.size}`);
      
      // Show author ID to name mapping
      if (authorIdToNameMap.size > 0) {
        console.log(`\n  Author ID → Name mapping (first 20):`);
        let count = 0;
        for (const [authorId, authorName] of authorIdToNameMap.entries()) {
          if (count++ >= 20) break;
          const proposalCount = proposalRows.filter(p => p.author_id === authorId).length;
          console.log(`    Author ID ${authorId}: "${authorName}" (${proposalCount} proposal(s))`);
        }
        if (authorIdToNameMap.size > 20) {
          console.log(`    ... and ${authorIdToNameMap.size - 20} more authors`);
        }
      }
      
      if (uniqueAuthorNames.size > 0 && uniqueAuthorNames.size <= 20) {
        console.log(`\n  Author names (from proposals): ${Array.from(uniqueAuthorNames).join(', ')}`);
      }
      
      console.log(`\nComments:`);
      console.log(`  With body: ${commentsWithBody}`);
      console.log(`  Root comments: ${rootComments}`);
      console.log(`  Nested comments: ${nestedComments}`);
      
      // Group comments by proposal
      const commentsByProposal = new Map<number, number>();
      for (const c of commentRows) {
        const count = commentsByProposal.get(c.commentable_id) || 0;
        commentsByProposal.set(c.commentable_id, count + 1);
      }
      
      console.log(`\nComments per proposal:`);
      const sortedProposals = Array.from(commentsByProposal.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10);
      for (const [proposalId, count] of sortedProposals) {
        console.log(`  Proposal ${proposalId}: ${count} comments`);
      }
      
      console.log('\n✅ Dry run complete - no data imported\n');
      return;
    }

    // Get or create admin user for topic creation
    const adminUser = await prisma.user.findFirst({
      where: { role: 'admin' },
    });

    if (!adminUser) {
      throw new Error('No admin user found. Please create an admin user first.');
    }

    // Get or create topic
    const topic = await getOrCreateTopic(adminUser.id);
    console.log(`📁 Topic ID: ${topic.id}\n`);

    // Pre-create all users for thread creators BEFORE importing threads
    await preCreateUsersForAuthors(proposalRows, authorIdToNameMap);

    // Get default import user for comments (if no author info available)
    const defaultImportUserId = await getOrCreateDefaultImportUser();
    console.log(`👤 Default import user ID: ${defaultImportUserId}\n`);

    // Import proposals (users are already created)
    console.log(`📥 Importing ${proposalRows.length} proposals...\n`);
    const threadMap = new Map<number, string>(); // proposal_id -> thread_id
    let importedThreads = 0;
    let failedThreads = 0;

    for (const proposal of proposalRows) {
      const threadId = await importProposal(proposal, topic.id);
      if (threadId) {
        threadMap.set(proposal.id, threadId);
        importedThreads++;
      } else {
        failedThreads++;
      }
    }

    console.log(`\n📊 Threads imported: ${importedThreads}, failed: ${failedThreads}\n`);

    // Import comments as nodes
    console.log(`📥 Importing ${commentRows.length} comments...\n`);
    const nodeMap = new Map<number, string>(); // comment_id -> node_id
    let importedNodes = 0;
    let failedNodes = 0;

    // First pass: import root comments (no ancestry)
    for (const comment of commentRows) {
      const proposalId = comment.commentable_id;
      const threadId = threadMap.get(proposalId);

      if (!threadId) {
        // Skip comments for proposals that weren't imported
        continue;
      }

      // Only process root comments in first pass (no ancestry)
      if (!comment.ancestry || comment.ancestry.trim().length === 0) {
        const nodeId = await importComment(comment, threadId, null, defaultImportUserId);
        if (nodeId) {
          nodeMap.set(comment.id, nodeId);
          importedNodes++;
        } else {
          failedNodes++;
        }
      }
    }

    // Second pass: import reply comments (with ancestry)
    // Process in order of ancestry depth (shallowest first)
    const commentsWithAncestry = commentRows.filter(c => c.ancestry && c.ancestry.trim().length > 0);
    commentsWithAncestry.sort((a, b) => {
      const depthA = (a.ancestry || '').split('/').length;
      const depthB = (b.ancestry || '').split('/').length;
      return depthA - depthB;
    });

    for (const comment of commentsWithAncestry) {
      const proposalId = comment.commentable_id;
      const threadId = threadMap.get(proposalId);

      if (!threadId) {
        continue;
      }

      // Get parent comment ID from ancestry
      const parentCommentId = getParentCommentId(comment.ancestry);
      const parentNodeId = parentCommentId ? nodeMap.get(parentCommentId) : null;

      // If parent node exists, use it; otherwise make it a root node
      const nodeId = await importComment(comment, threadId, parentNodeId || null, defaultImportUserId);
      if (nodeId) {
        nodeMap.set(comment.id, nodeId);
        importedNodes++;
      } else {
        failedNodes++;
      }
    }

    console.log(`\n📊 Nodes imported: ${importedNodes}, failed: ${failedNodes}\n`);

    console.log('✅ Import complete!\n');

    console.log('📈 Summary:');
    console.log(`  Topics: 1`);
    console.log(`  Threads: ${importedThreads} (${failedThreads} failed)`);
    console.log(`  Nodes: ${importedNodes} (${failedNodes} failed)`);
    console.log(`  Users created: ${authorUserMap.size} unique authors`);
  } catch (error: any) {
    console.error('❌ Import failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Show usage if no arguments provided
if (process.argv.length === 2 && !TEXT_FILE && !DUMP_FILE && !process.env.SOURCE_TEXT_FILE && !process.env.SOURCE_DB_DUMP_FILE) {
  console.log(`
Usage:
  tsx scripts/import-proposals.ts [options]

Options:
  --text-file <path>     Path to proposals text file (simplest - recommended!)
  --dump-file <path>     Path to PostgreSQL dump file
  --host <host>          PostgreSQL host (default: localhost)
  --port <port>          PostgreSQL port (default: 5432)
  --user <user>          PostgreSQL user (default: postgres)
  --password <password>  PostgreSQL password
  --database <name>      PostgreSQL database name (default: consul_production)
  --locale <locale>      Locale for translations (default: he)
  --dry-run              Test parsing without importing

Examples:
  # Test parsing from text file (easiest - recommended first!):
  tsx scripts/import-proposals.ts --text-file "\\\\wsl.localhost\\Ubuntu-24.04\\home\\tamir\\projects\\2.3.1\\prposals_for_dayparty.txt" --dry-run
  
  # Import from text file:
  tsx scripts/import-proposals.ts --text-file "\\\\wsl.localhost\\Ubuntu-24.04\\home\\tamir\\projects\\2.3.1\\prposals_for_dayparty.txt"
  
  # Import from dump file:
  tsx scripts/import-proposals.ts --dump-file "C:\\Temp\\consul_production_backup_21_05_2025.dump" --locale he
  
  # Import from live database:
  tsx scripts/import-proposals.ts --host localhost --port 5432 --user postgres --password mypass --database consul_production --locale he
`);
  process.exit(0);
}

// Run import
importProposals()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

