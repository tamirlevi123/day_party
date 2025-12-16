import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * In-memory cache for Knesset status descriptions
 * Loaded once at server startup
 */
let statusCache: Map<number, string> = new Map();
let isLoaded = false;

/**
 * Load all statuses from _KNS_Status table into memory
 * Should be called once at server startup
 */
export async function loadStatusCache(): Promise<void> {
  try {
    console.log('[KnessetStatus] Loading status cache from MySQL...');
    
    const sqlQuery = `
      SELECT StatusID, \`Desc\`
      FROM \`_KNS_Status\`
    `;
    console.log(`[SQL] Executing status cache query:`);
    console.log(`[SQL] ${sqlQuery}`);
    
    // Query all statuses from MySQL
    // Note: Using raw query since _KNS_Status is not in Prisma schema yet
    const statuses = await prisma.$queryRawUnsafe<Array<{
      StatusID: number;
      Desc: string;
    }>>(sqlQuery);

    console.log(`[SQL] Status cache query returned ${statuses.length} rows`);
    if (statuses.length > 0) {
      console.log(`[SQL] Sample statuses (first 5):`, statuses.slice(0, 5).map(s => `StatusID=${s.StatusID}, Desc="${s.Desc}"`).join(', '));
    }

    // Build in-memory map
    statusCache.clear();
    for (const status of statuses) {
      statusCache.set(status.StatusID, status.Desc);
    }

    isLoaded = true;
    console.log(`[KnessetStatus] Loaded ${statusCache.size} statuses into memory`);
  } catch (error: any) {
    console.error('[KnessetStatus] Error loading status cache:', error);
    // Don't throw - allow server to start even if cache fails
    // Will just return null for status descriptions
  }
}

/**
 * Get status description for a status ID
 * Returns null if not found or cache not loaded
 */
export function getStatusDescription(statusID: number | undefined | null): string | null {
  if (!isLoaded) {
    console.warn(`[KnessetStatus] Cache not loaded yet, returning null for statusID=${statusID}`);
    return null;
  }
  if (!statusID) {
    return null;
  }
  const description = statusCache.get(statusID) || null;
  if (!description) {
    console.warn(`[KnessetStatus] StatusID ${statusID} not found in cache (cache has ${statusCache.size} entries)`);
  }
  return description;
}

/**
 * Check if cache is loaded
 */
export function isStatusCacheLoaded(): boolean {
  return isLoaded;
}

/**
 * Reload cache (useful for testing or after data updates)
 */
export async function reloadStatusCache(): Promise<void> {
  await loadStatusCache();
}
