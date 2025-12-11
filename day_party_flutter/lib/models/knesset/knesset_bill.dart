/// Knesset Bill model - represents a bill/law from the Knesset
class KnessetBill {
  final int billID;
  final int knessetNum;
  final String name;
  final int? privateNumber;
  final int statusID;
  final String? statusDesc;
  final DateTime? publicationDate;
  final int? magazineNumber;
  final int? pageNumber;
  final bool? isContinuationBill;
  final String? summaryLaw;
  final int? subTypeID;
  final String? subTypeDesc;
  final int? committeeID;
  final int? number;
  final int? postponementReasonID;
  final String? postponementReasonDesc;
  final int? publicationSeriesID;
  final String? publicationSeriesDesc;
  final String? publicationSeriesFirstCall;
  final DateTime? lastUpdatedDate;
  final int? dyid;

  KnessetBill({
    required this.billID,
    required this.knessetNum,
    required this.name,
    required this.statusID,
    this.privateNumber,
    this.statusDesc,
    this.publicationDate,
    this.magazineNumber,
    this.pageNumber,
    this.isContinuationBill,
    this.summaryLaw,
    this.subTypeID,
    this.subTypeDesc,
    this.committeeID,
    this.number,
    this.postponementReasonID,
    this.postponementReasonDesc,
    this.publicationSeriesID,
    this.publicationSeriesDesc,
    this.publicationSeriesFirstCall,
    this.lastUpdatedDate,
    this.dyid,
  });

  /// Create from JSON map (from SQLite query result)
  factory KnessetBill.fromJson(Map<String, dynamic> json) {
    return KnessetBill(
      billID: _parseInt(json['BillID']) ?? 0,
      knessetNum: _parseInt(json['KnessetNum']) ?? 0,
      name: json['Name']?.toString() ?? '',
      privateNumber: _parseInt(json['PrivateNumber']),
      statusID: _parseInt(json['StatusID']) ?? 0,
      statusDesc: json['StatusDesc']?.toString(),
      publicationDate: _parseDateTime(json['PublicationDate']),
      magazineNumber: _parseInt(json['MagazineNumber']),
      pageNumber: _parseInt(json['PageNumber']),
      isContinuationBill: _parseBool(json['IsContinuationBill']),
      summaryLaw: json['SummaryLaw']?.toString(),
      subTypeID: _parseInt(json['SubTypeID']),
      subTypeDesc: json['SubTypeDesc']?.toString(),
      committeeID: _parseInt(json['CommitteeID']),
      number: _parseInt(json['Number']),
      postponementReasonID: _parseInt(json['PostponementReasonID']),
      postponementReasonDesc: json['PostponementReasonDesc']?.toString(),
      publicationSeriesID: _parseInt(json['PublicationSeriesID']),
      publicationSeriesDesc: json['PublicationSeriesDesc']?.toString(),
      publicationSeriesFirstCall: json['PublicationSeriesFirstCall']?.toString(),
      lastUpdatedDate: _parseDateTime(json['LastUpdatedDate']),
      dyid: _parseInt(json['DYID']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BillID': billID,
      'KnessetNum': knessetNum,
      'Name': name,
      'PrivateNumber': privateNumber,
      'StatusID': statusID,
      'StatusDesc': statusDesc,
      'PublicationDate': publicationDate?.toIso8601String(),
      'MagazineNumber': magazineNumber,
      'PageNumber': pageNumber,
      'IsContinuationBill': isContinuationBill,
      'SummaryLaw': summaryLaw,
      'SubTypeID': subTypeID,
      'SubTypeDesc': subTypeDesc,
      'CommitteeID': committeeID,
      'Number': number,
      'PostponementReasonID': postponementReasonID,
      'PostponementReasonDesc': postponementReasonDesc,
      'PublicationSeriesID': publicationSeriesID,
      'PublicationSeriesDesc': publicationSeriesDesc,
      'PublicationSeriesFirstCall': publicationSeriesFirstCall,
      'LastUpdatedDate': lastUpdatedDate?.toIso8601String(),
      'DYID': dyid,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
      return value == '1';
    }
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

