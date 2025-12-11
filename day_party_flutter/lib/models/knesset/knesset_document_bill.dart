import '../../core/logger.dart';

/// Knesset Document Bill model - represents a document linked to a bill
class KnessetDocumentBill {
  final int? documentBillID;
  final int? billID;
  final int? groupTypeID;
  final String groupTypeDesc;
  final int? applicationID;
  final String? applicationDesc;
  final String? filePath;
  final String? fileName;
  final DateTime? lastUpdatedDate;

  KnessetDocumentBill({
    this.documentBillID,
    this.billID,
    this.groupTypeID,
    required this.groupTypeDesc,
    this.applicationID,
    this.applicationDesc,
    this.filePath,
    this.fileName,
    this.lastUpdatedDate,
  });

  /// Create from JSON map (from SQLite query result)
  factory KnessetDocumentBill.fromJson(Map<String, dynamic> json) {
    // GroupTypeDesc is required, but handle null/empty gracefully
    final groupTypeDesc = json['GroupTypeDesc']?.toString() ?? '';
    if (groupTypeDesc.isEmpty) {
      appLogger.w('[KnessetDocumentBill] GroupTypeDesc is empty for DocumentBillID: ${json['DocumentBillID']}');
    }
    
    return KnessetDocumentBill(
      documentBillID: _parseInt(json['DocumentBillID']),
      billID: _parseInt(json['BillID']),
      groupTypeID: _parseInt(json['GroupTypeID']),
      groupTypeDesc: groupTypeDesc,
      applicationID: _parseInt(json['ApplicationID']),
      applicationDesc: json['ApplicationDesc']?.toString(),
      filePath: json['FilePath']?.toString(),
      fileName: json['FileName']?.toString(), // This column doesn't exist in DB, but handle gracefully
      lastUpdatedDate: _parseDateTime(json['LastUpdatedDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DocumentBillID': documentBillID,
      'BillID': billID,
      'GroupTypeID': groupTypeID,
      'GroupTypeDesc': groupTypeDesc,
      'ApplicationID': applicationID,
      'ApplicationDesc': applicationDesc,
      'FilePath': filePath,
      'FileName': fileName,
      'LastUpdatedDate': lastUpdatedDate?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed == null) {
        appLogger.w('[KnessetDocumentBill] Failed to parse String to int: "$value"');
      }
      return parsed;
    }
    if (value is double) return value.toInt();
    appLogger.w('[KnessetDocumentBill] Unexpected type for int: ${value.runtimeType}');
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      // Handle OData date format: /Date(1609459200000+0200)/
      final odataMatch = RegExp(r'/Date\((\d+)(?:[+-]\d+)?\)/').firstMatch(value);
      if (odataMatch != null) {
        final timestampString = odataMatch.group(1);
        if (timestampString != null) {
          final timestamp = int.tryParse(timestampString);
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }
      // Try standard ISO 8601 parsing
      return DateTime.tryParse(value);
    }
    return null;
  }
}

