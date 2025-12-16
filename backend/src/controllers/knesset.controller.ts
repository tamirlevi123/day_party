import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * GET /api/knesset/statuses
 * Get all statuses from _KNS_Status table
 */
export const getStatuses = async (_req: Request, res: Response): Promise<Response | void> => {
  try {
    console.log('[KnessetController] getStatuses called');
    console.log('[SQL] Querying _KNS_Status table...');
    
    const statuses = await prisma.$queryRawUnsafe<Array<{
      StatusID: number;
      Desc: string;
      TypeID: number | null;
      TypeDesc: string | null;
    }>>(`
      SELECT StatusID, \`Desc\`, TypeID, TypeDesc
      FROM \`_KNS_Status\`
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

    if (statusID !== null) {
      query = `
        SELECT *
        FROM \`_KNS_Bill\`
        WHERE KnessetNum = ${knessetNum} AND StatusID = ${statusID}
        ORDER BY PublicationDate DESC, BillID DESC
      `;
    } else {
      query = `
        SELECT *
        FROM \`_KNS_Bill\`
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
      FROM \`_KNS_DocumentBill\`
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
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch bill documents',
    });
  }
};
