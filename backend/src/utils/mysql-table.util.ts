import type { PrismaClient } from '@prisma/client';

type ResolveTableOptions = {
  /** Limit lookup to current DB (DATABASE()). Default: true */
  useCurrentDatabase?: boolean;
};

/**
 * Resolve a MySQL table name in a case-insensitive way (useful when moving between
 * Windows/MySQL (often case-insensitive) and Linux/MySQL (often case-sensitive)).
 *
 * Returns the actual table name as stored in MySQL, or null if none match.
 */
export async function resolveMySqlTableName(
  prisma: PrismaClient,
  candidates: string[],
  options: ResolveTableOptions = {}
): Promise<string | null> {
  const useCurrentDatabase = options.useCurrentDatabase ?? true;
  if (candidates.length === 0) return null;

  // We only use known, hardcoded table names here.
  const lowered = candidates.map((t) => t.toLowerCase());
  const inList = lowered.map((t) => `'${t.replace(/'/g, "''")}'`).join(', ');

  const schemaPredicate = useCurrentDatabase ? 'TABLE_SCHEMA = DATABASE()' : '1=1';

  const sql = `
    SELECT TABLE_NAME as tableName
    FROM INFORMATION_SCHEMA.TABLES
    WHERE ${schemaPredicate}
      AND LOWER(TABLE_NAME) IN (${inList})
    ORDER BY
      -- Prefer exact match on first candidate, then stable by name
      CASE WHEN LOWER(TABLE_NAME) = '${lowered[0].replace(/'/g, "''")}' THEN 0 ELSE 1 END,
      TABLE_NAME
    LIMIT 1
  `;

  const rows = await prisma.$queryRawUnsafe<Array<{ tableName: string }>>(sql);
  return rows?.[0]?.tableName ?? null;
}

export async function listMySqlTablesLike(
  prisma: PrismaClient,
  likePattern: string,
  options: ResolveTableOptions = {}
): Promise<string[]> {
  const useCurrentDatabase = options.useCurrentDatabase ?? true;
  const schemaPredicate = useCurrentDatabase ? 'TABLE_SCHEMA = DATABASE()' : '1=1';

  const sql = `
    SELECT TABLE_NAME as tableName
    FROM INFORMATION_SCHEMA.TABLES
    WHERE ${schemaPredicate}
      AND TABLE_NAME LIKE '${likePattern.replace(/'/g, "''")}'
    ORDER BY TABLE_NAME
  `;

  const rows = await prisma.$queryRawUnsafe<Array<{ tableName: string }>>(sql);
  return rows.map((r) => r.tableName);
}

export async function getCurrentDatabaseName(prisma: PrismaClient): Promise<string | null> {
  const rows = await prisma.$queryRawUnsafe<Array<{ db: string | null }>>(`SELECT DATABASE() as db`);
  return rows?.[0]?.db ?? null;
}

