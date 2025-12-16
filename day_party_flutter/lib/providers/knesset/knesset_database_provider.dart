import 'package:flutter/material.dart';
import '../../services/knesset/knesset_database_service.dart';
import '../../models/knesset/knesset_bill.dart';
import '../../models/knesset/knesset_document_bill.dart';

/// Provider for KnessetDatabaseService
class KnessetDatabaseProvider with ChangeNotifier {
  final KnessetDatabaseService _service = KnessetDatabaseService();
  
  KnessetDatabaseService get service => _service;

  /// Get all bills
  Future<List<KnessetBill>> getAllBills() async {
    try {
      final maps = await _service.getAllBills();
      return maps.map((map) => KnessetBill.fromJson(map)).toList()
        ..sort((a, b) {
          // Sort by KnessetNum desc, then Name asc
          final knessetComp = b.knessetNum.compareTo(a.knessetNum);
          if (knessetComp != 0) return knessetComp;
          return a.name.compareTo(b.name);
        });
    } catch (e) {
      return [];
    }
  }

  /// Get bill by ID
  Future<KnessetBill?> getBillById(int billId) async {
    try {
      final map = await _service.getBillById(billId);
      if (map != null) {
        return KnessetBill.fromJson(map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get documents for a specific bill
  Future<List<KnessetDocumentBill>> getDocumentsByBillId(int billId) async {
    try {
      final maps = await _service.getDocumentsByBillId(billId);
      return maps.map((map) => KnessetDocumentBill.fromJson(map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get committee map
  Future<Map<int, String>> getCommitteeMap() async {
    return await _service.getCommitteeMap();
  }

  /// Get all statuses
  Future<List<Map<String, dynamic>>> getAllStatuses() async {
    return await _service.getAllStatuses();
  }

  /// Get bills filtered by Knesset number and optionally by StatusID
  Future<List<KnessetBill>> getBillsByKnesset({
    required int knessetNum,
    int? statusID,
  }) async {
    try {
      final maps = await _service.getBillsByKnesset(
        knessetNum: knessetNum,
        statusID: statusID,
      );
      return maps.map((map) => KnessetBill.fromJson(map)).toList()
        ..sort((a, b) {
          // Sort by PublicationDate desc, then BillID desc
          if (a.publicationDate != null && b.publicationDate != null) {
            return b.publicationDate!.compareTo(a.publicationDate!);
          }
          if (a.publicationDate != null) return -1;
          if (b.publicationDate != null) return 1;
          return b.billID.compareTo(a.billID);
        });
    } catch (e) {
      return [];
    }
  }

  /// Get status description by StatusID
  Future<String?> getStatusDescription(int statusID) async {
    return await _service.getStatusDescription(statusID);
  }

  /// Close database connection
  Future<void> close() async {
    await _service.close();
  }
}

