import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/logger.dart';

/// Service for managing the Knesset SQLite database
/// Downloads from server and manages local copy
class KnessetDatabaseService {
  static const String _dbName = 'knesset_data.db';
  static const String _lastUpdateKey = 'knesset_db_last_update';
  
  Database? _database;
  Completer<Database>? _dbCompleter;

  /// Get the database instance, initializing if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    if (_dbCompleter == null) {
      _dbCompleter = Completer<Database>();
      _initDatabase();
    }
    
    return _dbCompleter!.future;
  }

  /// Initialize the database - check for updates and copy from assets if needed
  Future<void> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDirectory.path, _dbName);
      
      appLogger.i('KnessetDatabaseService: Checking DB at path: $dbPath');

      // Check if database exists
      final exists = await databaseExists(dbPath);
      
      int? size;
      if (exists) {
        try {
          final file = File(dbPath);
          size = await file.length();
          appLogger.i('KnessetDatabaseService: Database exists, size: $size bytes');
        } catch (e) {
          appLogger.w('KnessetDatabaseService: Could not get size', error: e);
        }
      }

      // If database doesn't exist or is empty, copy from assets (PRIMARY SOURCE)
      if (!exists || size == null || size == 0) {
        appLogger.i('KnessetDatabaseService: Database not found locally, copying from assets...');
        try {
          await _copyDatabaseFromAssets(dbPath);
          appLogger.i('KnessetDatabaseService: Database copied from assets successfully');
        } catch (assetError) {
          appLogger.e('KnessetDatabaseService: Failed to copy database from assets', error: assetError);
          rethrow; // Can't continue without database from assets
        }
      }

      // Check server for updates (ONLY for updates, not primary source)
      try {
        final needsUpdate = await _checkForUpdate();
        if (needsUpdate) {
          appLogger.i('KnessetDatabaseService: Update available on server, downloading...');
          try {
            await _downloadDatabaseFromServer(dbPath);
            appLogger.i('KnessetDatabaseService: Database updated from server successfully');
          } catch (downloadError) {
            appLogger.w('KnessetDatabaseService: Update download failed, using existing database', error: downloadError);
            // Continue with existing database if update fails
          }
        } else {
          appLogger.i('KnessetDatabaseService: Local database is up to date');
        }
      } catch (updateCheckError) {
        appLogger.w('KnessetDatabaseService: Could not check for updates, using existing database', error: updateCheckError);
        // Continue with existing database if update check fails
      }

      // Open the database if it exists
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final finalSize = await dbFile.length();
        if (finalSize > 0) {
          appLogger.i('KnessetDatabaseService: Opening database at $dbPath (size: $finalSize bytes)');
          _database = await openDatabase(dbPath, readOnly: false);
          appLogger.i('KnessetDatabaseService: Database opened successfully');
        } else {
          appLogger.w('KnessetDatabaseService: Database file exists but is empty');
        }
      } else {
        appLogger.w('KnessetDatabaseService: Database file does not exist. Documents will not be available until database is downloaded.');
      }

      if (_dbCompleter != null && !_dbCompleter!.isCompleted) {
        _dbCompleter!.complete(_database);
      }
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error initializing database', error: e, stackTrace: s);
      if (_dbCompleter != null && !_dbCompleter!.isCompleted) {
        _dbCompleter!.completeError(e, s);
      }
      rethrow;
    }
  }

  /// Check if database update is available from server
  Future<bool> _checkForUpdate() async {
    try {
      final baseUrl = ApiClient.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/knesset-database/info'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        appLogger.w('KnessetDatabaseService: Could not check for updates: ${response.statusCode}');
        return false;
      }

      final data = response.body;
      // Parse JSON manually (or use jsonDecode if available)
      final serverLastModified = _parseLastModified(data);
      
      if (serverLastModified == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final localLastUpdate = prefs.getString(_lastUpdateKey);
      
      if (localLastUpdate == null || localLastUpdate != serverLastModified) {
        return true;
      }

      return false;
    } catch (e) {
      appLogger.w('KnessetDatabaseService: Error checking for updates', error: e);
      return false; // Don't update if check fails
    }
  }

  /// Parse lastModified from JSON response
  String? _parseLastModified(String json) {
    try {
      // Simple JSON parsing for "lastModifiedUtc" field
      final match = RegExp(r'"lastModifiedUtc"\s*:\s*"([^"]+)"').firstMatch(json);
      return match?.group(1);
    } catch (e) {
      appLogger.w('KnessetDatabaseService: Error parsing lastModified', error: e);
      return null;
    }
  }

  /// Download database from server
  Future<void> _downloadDatabaseFromServer(String dbPath) async {
    try {
      final baseUrl = ApiClient.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/knesset-database/download'),
      ).timeout(const Duration(minutes: 5)); // Large file, allow more time

      if (response.statusCode != 200) {
        throw Exception('Failed to download database: ${response.statusCode}');
      }

      // Ensure directory exists
      await Directory(path.dirname(dbPath)).create(recursive: true);

      // Write file
      final file = File(dbPath);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      
      appLogger.i('KnessetDatabaseService: Database downloaded successfully');

      // Save last update time
      final prefs = await SharedPreferences.getInstance();
      final lastModified = response.headers['last-modified'] ?? DateTime.now().toIso8601String();
      await prefs.setString(_lastUpdateKey, lastModified);

      // Verify download
      if (await file.exists()) {
        final size = await file.length();
        appLogger.i('KnessetDatabaseService: Verified download, size: $size bytes');
      } else {
        throw Exception('Downloaded file not found after write');
      }
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error downloading database', error: e, stackTrace: s);
      // Don't fall back to assets here - let the caller handle it
      rethrow;
    }
  }

  /// Copy database from assets (primary source)
  Future<void> _copyDatabaseFromAssets(String dbPath) async {
    try {
      // Ensure directory exists
      await Directory(path.dirname(dbPath)).create(recursive: true);

      // Load from assets - this is the primary source
      appLogger.d('KnessetDatabaseService: Loading database from assets: assets/data/$_dbName');
      final ByteData data = await rootBundle.load('assets/data/$_dbName');
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write file
      await File(dbPath).writeAsBytes(bytes, flush: true);
      appLogger.i('KnessetDatabaseService: Database copied from assets to $dbPath');

      // Verify copy
      final file = File(dbPath);
      if (await file.exists()) {
        final size = await file.length();
        appLogger.i('KnessetDatabaseService: Verified copy, size: $size bytes');
        if (size == 0) {
          throw Exception('Copied database file is empty');
        }
      } else {
        throw Exception('Copied file not found after write');
      }
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error copying database from assets', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Get committee map (CommitteeID -> Name)
  Future<Map<int, String>> getCommitteeMap() async {
    final db = await database;
    appLogger.d('KnessetDatabaseService: Querying committee map...');
    
    final committeeMap = <int, String>{};
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        '_KNS_Committee',
        columns: ['CommitteeID', 'Name'],
      );
      
      for (var map in maps) {
        final id = map['CommitteeID'] as int?;
        final name = map['Name'] as String?;
        if (id != null && name != null) {
          committeeMap[id] = name;
        }
      }
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying committee map', error: e, stackTrace: s);
    }
    
    appLogger.d('KnessetDatabaseService: Returning committee map with ${committeeMap.length} entries');
    return committeeMap;
  }

  /// Get all bills
  Future<List<Map<String, dynamic>>> getAllBills() async {
    final db = await database;
    appLogger.d('KnessetDatabaseService: Querying all bills...');
    
    try {
      final List<Map<String, dynamic>> maps = await db.query('_KNS_Bill');
      appLogger.d('KnessetDatabaseService: Fetched ${maps.length} bills');
      return maps;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying bills', error: e, stackTrace: s);
      return [];
    }
  }

  /// Get all statuses
  Future<List<Map<String, dynamic>>> getAllStatuses() async {
    final db = await database;
    appLogger.d('KnessetDatabaseService: Querying all statuses...');
    
    try {
      final List<Map<String, dynamic>> maps = await db.query('_KNS_Status');
      appLogger.d('KnessetDatabaseService: Fetched ${maps.length} statuses');
      return maps;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying statuses', error: e, stackTrace: s);
      return [];
    }
  }

  /// Get bill by ID
  Future<Map<String, dynamic>?> getBillById(int billId) async {
    final db = await database;
    appLogger.d('KnessetDatabaseService: Querying bill $billId...');
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        '_KNS_Bill',
        where: 'BillID = ?',
        whereArgs: [billId],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying bill', error: e, stackTrace: s);
      return null;
    }
  }

  /// Get documents for a specific bill
  Future<List<Map<String, dynamic>>> getDocumentsByBillId(int billId) async {
    final db = await database;
    appLogger.d('KnessetDatabaseService: Querying documents for bill $billId...');
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        '_KNS_DocumentBill',
        where: 'BillID = ?',
        whereArgs: [billId],
        orderBy: 'GroupTypeID, ApplicationID, DocumentBillID',
      );
      
      appLogger.d('KnessetDatabaseService: Fetched ${maps.length} documents for bill $billId');
      return maps;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying documents', error: e, stackTrace: s);
      return [];
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _dbCompleter = null;
    }
  }
}

