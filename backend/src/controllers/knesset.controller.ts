import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { getCurrentDatabaseName, listMySqlTablesLike, resolveMySqlTableName } from '../utils/mysql-table.util';

const prisma = new PrismaClient();

/**
 * GET /api/knesset/statuses
 * Get all statuses from Knesset status table.
 * Optional query params:
 * - knessetNum: if provided, returns only statuses that appear in bills for that Knesset number
 */
export const getStatuses = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    console.log('[KnessetController] getStatuses called');

    const knessetNumParam = req.query.knessetNum as string | undefined;
    const knessetNum = knessetNumParam ? parseInt(knessetNumParam, 10) : null;
    if (knessetNumParam && (knessetNum === null || Number.isNaN(knessetNum))) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'knessetNum must be a valid number',
      });
    }

    const tableName = await resolveMySqlTableName(prisma, [
      '_KNS_Status',
      '_kns_status',
      'KNS_Status',
      'KNS_Statuses',
      'kns_status',
      'kns_statuses',
    ]);

    if (!tableName) {
      const db = await getCurrentDatabaseName(prisma);
      const knessetTables = await listMySqlTablesLike(prisma, '%KNS%');
      console.error('[KnessetController] Knesset status table not found in DB', {
        db,
        expected: '_KNS_Status',
        foundKnessetTables: knessetTables.slice(0, 50),
        foundCount: knessetTables.length,
      });
      return res.status(500).json({
        error: 'internal_error',
        message: 'Knesset status table not found on server database',
        details: {
          expectedTable: '_KNS_Status',
          db,
          foundKnessetTablesCount: knessetTables.length,
        },
      });
    }

    console.log(`[SQL] Querying status table: ${tableName}`);

    // If knessetNum is provided, filter statuses to those used by bills in that Knesset.
    // This prevents the client from downloading the entire bills table just to build a dropdown.
    if (knessetNum !== null) {
      const billTable = await resolveMySqlTableName(prisma, [
        '_KNS_Bill',
        '_kns_bill',
        'KNS_Bill',
        'KNS_Bills',
        'kns_bill',
        'kns_bills',
      ]);

      if (!billTable) {
        const db = await getCurrentDatabaseName(prisma);
        return res.status(500).json({
          error: 'internal_error',
          message: 'Knesset bill table not found on server database (required for knessetNum filter)',
          details: {
            expectedTable: '_KNS_Bill',
            db,
          },
        });
      }

      console.log(`[SQL] Filtering statuses by bills table ${billTable} for KnessetNum=${knessetNum}`);

      const statuses = await prisma.$queryRawUnsafe<Array<{
        StatusID: number;
        Desc: string;
        TypeID: number | null;
        TypeDesc: string | null;
      }>>(`
        SELECT DISTINCT s.StatusID, s.\`Desc\`, s.TypeID, s.TypeDesc
        FROM \`${tableName}\` s
        INNER JOIN \`${billTable}\` b ON b.StatusID = s.StatusID
        WHERE b.KnessetNum = ${knessetNum}
        ORDER BY s.TypeID, s.\`Desc\`
      `);

      return res.status(200).json({ statuses });
    }

    const statuses = await prisma.$queryRawUnsafe<Array<{
      StatusID: number;
      Desc: string;
      TypeID: number | null;
      TypeDesc: string | null;
    }>>(`
      SELECT StatusID, \`Desc\`, TypeID, TypeDesc
      FROM \`${tableName}\`
      ORDER BY TypeID, \`Desc\`
    `);

    console.log(`[SQL] Found ${statuses.length} statuses`);
    if (statuses.length > 0) {
      console.log(`[KnessetController] First 5 statuses:`, statuses.slice(0, 5).map(s => ({
        StatusID: s.StatusID,
        Desc: s.Desc,
      })));
    }

    const formattedStatuses = statuses.map(s => ({
      StatusID: s.StatusID,
      Desc: s.Desc,
      TypeID: s.TypeID,
      TypeDesc: s.TypeDesc,
    }));

    console.log(`[KnessetController] Returning ${formattedStatuses.length} statuses to client`);

    return res.status(200).json({
      statuses: formattedStatuses,
    });
  } catch (error: any) {
    console.error('[KnessetController] Error fetching statuses:', error);
    console.error('[KnessetController] Error details:', {
      name: error?.name,
      code: error?.code,
      message: error?.message,
      meta: error?.meta,
    });
    console.error('[KnessetController] Error stack:', error.stack);
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch statuses',
    });
  }
};

/**
 * GET /api/knesset/committees
 * Get all committees as a map (CommitteeID -> Name)
 */
export const getCommittees = async (_req: Request, res: Response): Promise<Response | void> => {
  try {
    const committees = await prisma.$queryRawUnsafe<Array<{
      CommitteeID: number;
      Name: string;
    }>>(`
      SELECT CommitteeID, \`Name\`
      FROM \`_KNS_Committee\`
      ORDER BY \`Name\`
    `);

    const committeeMap: Record<number, string> = {};
    for (const committee of committees) {
      committeeMap[committee.CommitteeID] = committee.Name;
    }

    return res.status(200).json({
      committees: committeeMap,
    });
  } catch (error: any) {
    console.error('Error fetching committees:', error);
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch committees',
    });
  }
};

/**
 * GET /api/knesset/bills
 * Get bills filtered by KnessetNum and optionally StatusID
 * Query params: knessetNum (required), statusID (optional)
 */
export const getBills = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const knessetNumParam = req.query.knessetNum as string | undefined;
    const statusIDParam = req.query.statusID as string | undefined;

    if (!knessetNumParam) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'knessetNum query parameter is required',
      });
    }

    const knessetNum = parseInt(knessetNumParam, 10);
    if (isNaN(knessetNum)) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'knessetNum must be a valid number',
      });
    }

    const statusID = statusIDParam ? parseInt(statusIDParam, 10) : null;
    if (statusIDParam && isNaN(statusID!)) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'statusID must be a valid number',
      });
    }

    let query: string;
    const billTable = await resolveMySqlTableName(prisma, [
      '_KNS_Bill',
      '_kns_bill',
      'KNS_Bill',
      'KNS_Bills',
      'kns_bill',
      'kns_bills',
    ]);

    if (!billTable) {
      const db = await getCurrentDatabaseName(prisma);
      const knessetTables = await listMySqlTablesLike(prisma, '%KNS%');
      console.error('[KnessetController] Knesset bill table not found in DB', {
        db,
        expected: '_KNS_Bill',
        foundKnessetTables: knessetTables.slice(0, 50),
        foundCount: knessetTables.length,
      });
      return res.status(500).json({
        error: 'internal_error',
        message: 'Knesset bill table not found on server database',
        details: {
          expectedTable: '_KNS_Bill',
          db,
          foundKnessetTablesCount: knessetTables.length,
        },
      });
    }

    if (statusID !== null) {
      query = `
        SELECT *
        FROM \`${billTable}\`
        WHERE KnessetNum = ${knessetNum} AND StatusID = ${statusID}
        ORDER BY PublicationDate DESC, BillID DESC
      `;
    } else {
      query = `
        SELECT *
        FROM \`${billTable}\`
        WHERE KnessetNum = ${knessetNum}
        ORDER BY PublicationDate DESC, BillID DESC
      `;
    }

    const bills = await prisma.$queryRawUnsafe<Array<Record<string, any>>>(query);

    return res.status(200).json({
      bills: bills,
      count: bills.length,
    });
  } catch (error: any) {
    console.error('Error fetching bills:', error);
    console.error('[KnessetController] Bills error details:', {
      name: error?.name,
      code: error?.code,
      message: error?.message,
      meta: error?.meta,
    });
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch bills',
    });
  }
};

/**
 * GET /api/knesset/bills/:billId/documents
 * Get all documents for a specific bill
 */
export const getBillDocuments = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const billIdParam = req.params.billId;
    const billId = parseInt(billIdParam, 10);

    if (isNaN(billId)) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'billId must be a valid number',
      });
    }

    const docTable = await resolveMySqlTableName(prisma, [
      '_KNS_DocumentBill',
      '_kns_documentbill',
      'KNS_DocumentBill',
      'KNS_DocumentBills',
    ]);

    if (!docTable) {
      const db = await getCurrentDatabaseName(prisma);
      return res.status(500).json({
        error: 'internal_error',
        message: 'Knesset document table not found on server database',
        details: {
          expectedTable: '_KNS_DocumentBill',
          db,
        },
      });
    }

    const documents = await prisma.$queryRawUnsafe<Array<{
      DocumentBillID: string;
      BillID: number;
      GroupTypeID: number | null;
      GroupTypeDesc: string | null;
      ApplicationID: number | null;
      ApplicationDesc: string | null;
      FilePath: string | null;
      LastUpdatedDate: string | null;
    }>>(`
      SELECT 
        DocumentBillID,
        BillID,
        GroupTypeID,
        GroupTypeDesc,
        ApplicationID,
        ApplicationDesc,
        FilePath,
        LastUpdatedDate
      FROM \`${docTable}\`
      WHERE BillID = ${billId}
      ORDER BY GroupTypeID, ApplicationID, DocumentBillID
    `);

    return res.status(200).json({
      billId: billId,
      documents: documents,
      count: documents.length,
    });
  } catch (error: any) {
    console.error('Error fetching bill documents:', error);
    console.error('[KnessetController] Documents error details:', {
      name: error?.name,
      code: error?.code,
      message: error?.message,
      meta: error?.meta,
    });
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch bill documents',
    });
  }
};

/**
 * GET /api/knesset/diagnostics
 * Returns information about Knesset tables on the current MySQL database.
 * Useful for debugging VM-only failures.
 */
export const getKnessetDiagnostics = async (_req: Request, res: Response): Promise<Response | void> => {
  try {
    const db = await getCurrentDatabaseName(prisma);
    const knessetTables = await listMySqlTablesLike(prisma, '%KNS%');

    const resolved = {
      statusTable: await resolveMySqlTableName(prisma, ['_KNS_Status', '_kns_status', 'KNS_Status', 'KNS_Statuses']),
      billTable: await resolveMySqlTableName(prisma, ['_KNS_Bill', '_kns_bill', 'KNS_Bill', 'KNS_Bills']),
      documentBillTable: await resolveMySqlTableName(prisma, ['_KNS_DocumentBill', '_kns_documentbill', 'KNS_DocumentBill']),
      committeeTable: await resolveMySqlTableName(prisma, ['_KNS_Committee', '_kns_committee', 'KNS_Committee', 'KNS_Committees']),
    };

    let statusCount: number | null = null;
    if (resolved.statusTable) {
      const rows = await prisma.$queryRawUnsafe<Array<{ c: number }>>(
        `SELECT COUNT(*) as c FROM \`${resolved.statusTable}\``
      );
      statusCount = rows?.[0]?.c ?? null;
    }

    return res.status(200).json({
      db,
      knessetTablesCount: knessetTables.length,
      knessetTables: knessetTables.slice(0, 200),
      resolved,
      statusCount,
    });
  } catch (error: any) {
    console.error('[KnessetController] Diagnostics error:', error);
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch knesset diagnostics',
    });
  }
};
