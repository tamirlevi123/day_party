import 'package:flutter/material.dart';
import '../../services/knesset/knesset_api_service.dart';
import '../../models/knesset/knesset_bill.dart';
import '../../models/knesset/knesset_document_bill.dart';
import '../../core/logger.dart';

/// Provider for Knesset API service (replaces SQLite database service)
class KnessetDatabaseProvider with ChangeNotifier {
  final KnessetApiService _service = KnessetApiService();
  
  KnessetApiService get service => _service;

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
    appLogger.i('🟣 KnessetDatabaseProvider: getAllStatuses called');
    final statuses = await _service.getAllStatuses();
    appLogger.i('🟣 KnessetDatabaseProvider: Received ${statuses.length} statuses from service');
    if (statuses.isEmpty) {
      appLogger.w('🟣 KnessetDatabaseProvider: WARNING - No statuses returned from service!');
    }
    return statuses;
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
  /// Note: Status descriptions are now provided by backend in thread metadata
  /// This method is kept for compatibility but may return null
  Future<String?> getStatusDescription(int statusID) async {
    try {
      final statuses = await _service.getAllStatuses();
      final status = statuses.firstWhere(
        (s) => s['StatusID'] == statusID,
        orElse: () => <String, dynamic>{},
      );
      return status['Desc'] as String?;
    } catch (e) {
      return null;
    }
  }
}

