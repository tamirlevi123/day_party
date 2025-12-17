import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/logger.dart';

/// Service for fetching Knesset data from the backend API
class KnessetApiService {
  /// Get all statuses
  Future<List<Map<String, dynamic>>> getAllStatuses({int? knessetNum}) async {
    try {
      appLogger.i('🔵 KnessetApiService: Fetching statuses from /knesset/statuses (knessetNum=$knessetNum)');
      final response = await ApiClient.instance.get(
        '/knesset/statuses',
        queryParameters: knessetNum != null ? {'knessetNum': knessetNum} : null,
      );
      appLogger.i('🔵 KnessetApiService: Received response, status: ${response.statusCode}');
      
      final data = response.data as Map<String, dynamic>;
      final statuses = data['statuses'] as List<dynamic>;
      
      appLogger.i('🔵 KnessetApiService: Parsed ${statuses.length} statuses');
      if (statuses.isNotEmpty) {
        appLogger.i('🔵 KnessetApiService: First 5 statuses: ${statuses.take(5).map((s) => '${s['StatusID']}: ${s['Desc']}').join(", ")}');
      } else {
        appLogger.w('🔵 KnessetApiService: WARNING - No statuses returned!');
      }
      
      return statuses.cast<Map<String, dynamic>>();
    } catch (e, s) {
      appLogger.e('🔵 KnessetApiService: Error fetching statuses', error: e, stackTrace: s);
      if (e is DioException) {
        appLogger.e('🔵 KnessetApiService: DioException details - status: ${e.response?.statusCode}, message: ${e.message}');
        appLogger.e('🔵 KnessetApiService: Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  /// Get committee map (CommitteeID -> Name)
  Future<Map<int, String>> getCommitteeMap() async {
    try {
      final response = await ApiClient.instance.get('/knesset/committees');
      final data = response.data as Map<String, dynamic>;
      final committees = data['committees'] as Map<String, dynamic>;
      
      final committeeMap = <int, String>{};
      committees.forEach((key, value) {
        final id = int.tryParse(key);
        if (id != null && value is String) {
          committeeMap[id] = value;
        }
      });
      
      return committeeMap;
    } catch (e, s) {
      appLogger.e('KnessetApiService: Error fetching committees', error: e, stackTrace: s);
      return {};
    }
  }

  /// Get bills filtered by Knesset number and optionally by StatusID
  Future<List<Map<String, dynamic>>> getBillsByKnesset({
    required int knessetNum,
    int? statusID,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'knessetNum': knessetNum.toString(),
      };
      if (statusID != null) {
        queryParams['statusID'] = statusID.toString();
      }

      final response = await ApiClient.instance.get(
        '/knesset/bills',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final bills = data['bills'] as List<dynamic>;
      return bills.cast<Map<String, dynamic>>();
    } catch (e, s) {
      appLogger.e('KnessetApiService: Error fetching bills', error: e, stackTrace: s);
      return [];
    }
  }

  /// Get documents for a specific bill
  Future<List<Map<String, dynamic>>> getDocumentsByBillId(int billId) async {
    try {
      final response = await ApiClient.instance.get('/knesset/bills/$billId/documents');
      final data = response.data as Map<String, dynamic>;
      final documents = data['documents'] as List<dynamic>;
      return documents.cast<Map<String, dynamic>>();
    } catch (e, s) {
      appLogger.e('KnessetApiService: Error fetching documents', error: e, stackTrace: s);
      return [];
    }
  }

  /// Get bill by ID (from bills list)
  Future<Map<String, dynamic>?> getBillById(int billId) async {
    try {
      // Since we don't have a direct endpoint, we'll search in bills
      // For now, we can get bills and filter, but ideally we'd have a dedicated endpoint
      // For simplicity, we'll get all bills for Knesset 25 (most common case)
      final bills = await getBillsByKnesset(knessetNum: 25);
      final bill = bills.firstWhere(
        (b) => b['BillID'] == billId,
        orElse: () => <String, dynamic>{},
      );
      
      if (bill.isEmpty) {
        return null;
      }
      
      return bill;
    } catch (e, s) {
      appLogger.e('KnessetApiService: Error fetching bill by ID', error: e, stackTrace: s);
      return null;
    }
  }

  /// Get all bills (for compatibility - gets Knesset 25 by default)
  Future<List<Map<String, dynamic>>> getAllBills() async {
    return getBillsByKnesset(knessetNum: 25);
  }
}
