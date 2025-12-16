import 'dart:async';
import 'dart:convert';
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

      // Open the database if it exists (must open before we can check for incremental updates)
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final finalSize = await dbFile.length();
        if (finalSize > 0) {
          appLogger.i('KnessetDatabaseService: Opening database at $dbPath (size: $finalSize bytes)');
          _database = await openDatabase(dbPath, readOnly: false);
          appLogger.i('KnessetDatabaseService: Database opened successfully');
          
          // Verify that tables exist (database might be empty after corruption/deletion)
          final tablesExist = await _verifyTablesExist();
          if (!tablesExist) {
            appLogger.w('KnessetDatabaseService: Database opened but tables are missing. Copying from assets...');
            await _database!.close();
            _database = null;
            // Delete the empty database and copy from assets
            try {
              await dbFile.delete();
            } catch (e) {
              appLogger.w('KnessetDatabaseService: Could not delete empty database', error: e);
            }
            await _copyDatabaseFromAssets(dbPath);
            // Reopen the database after copying
            _database = await openDatabase(dbPath, readOnly: false);
            appLogger.i('KnessetDatabaseService: Database copied from assets and reopened');
          }
          
          // Log database statistics for debugging
          try {
            await _logDatabaseStatistics();
          } catch (e) {
            appLogger.w('KnessetDatabaseService: Could not log database statistics', error: e);
          }
          
          // Now check for incremental updates (database must be open to query max IDs)
          try {
            final needsUpdate = await _checkForUpdate();
            if (needsUpdate) {
              appLogger.i('KnessetDatabaseService: Update available on server, applying incremental updates...');
              try {
                // Use incremental updates instead of full download
                await _applyIncrementalUpdates();
                appLogger.i('KnessetDatabaseService: Database updated incrementally from server successfully');
                // Log statistics again after update
                try {
                  await _logDatabaseStatistics();
                } catch (e) {
                  appLogger.w('KnessetDatabaseService: Could not log database statistics after update', error: e);
                }
              } catch (updateError) {
                appLogger.w('KnessetDatabaseService: Incremental update failed, using existing database', error: updateError);
                // Continue with existing database if update fails
              }
            } else {
              appLogger.i('KnessetDatabaseService: Local database is up to date');
            }
          } catch (updateCheckError) {
            appLogger.w('KnessetDatabaseService: Could not check for updates, using existing database', error: updateCheckError);
            // Continue with existing database if update check fails
          }
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
        Uri.parse('$baseUrl/knesset-database/info'),
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
    final baseUrl = ApiClient.baseUrl;
    final uri = Uri.parse('$baseUrl/knesset-database/download');
    
    appLogger.i('KnessetDatabaseService: Starting download from $uri');
    
    // Ensure directory exists
    await Directory(path.dirname(dbPath)).create(recursive: true);
    
    final file = File(dbPath);
    final sink = file.openWrite();
    
    try {
      final request = await http.Client().send(
        http.Request('GET', uri),
      ).timeout(const Duration(minutes: 10)); // Large file, allow more time

      if (request.statusCode != 200) {
        await sink.close();
        throw Exception('Failed to download database: ${request.statusCode}');
      }

      appLogger.i('KnessetDatabaseService: Response received, status: ${request.statusCode}, content-length: ${request.contentLength}');
      
      // Stream the response to file
      int bytesReceived = 0;
      await for (final chunk in request.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (bytesReceived % (10 * 1024 * 1024) == 0) {
          // Log progress every 10MB
          appLogger.d('KnessetDatabaseService: Downloaded ${bytesReceived ~/ (1024 * 1024)}MB');
        }
      }
      
      await sink.flush();
      await sink.close();
      
      appLogger.i('KnessetDatabaseService: Database downloaded successfully, total bytes: $bytesReceived');

      // Save last update time
      final prefs = await SharedPreferences.getInstance();
      final lastModified = request.headers['last-modified'] ?? DateTime.now().toIso8601String();
      await prefs.setString(_lastUpdateKey, lastModified);

      // Verify download
      if (await file.exists()) {
        final size = await file.length();
        appLogger.i('KnessetDatabaseService: Verified download, size: $size bytes');
        if (size == 0) {
          throw Exception('Downloaded database file is empty');
        }
      } else {
        throw Exception('Downloaded file not found after write');
      }
    } catch (e, s) {
      await sink.close();
      // Delete partial file on error
      if (await file.exists()) {
        try {
          await file.delete();
          appLogger.w('KnessetDatabaseService: Deleted partial download');
        } catch (deleteError) {
          appLogger.w('KnessetDatabaseService: Could not delete partial file', error: deleteError);
        }
      }
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

  /// Get bills filtered by Knesset number and optionally by StatusID
  Future<List<Map<String, dynamic>>> getBillsByKnesset({
    required int knessetNum,
    int? statusID,
  }) async {
    final db = await database;
    appLogger.d('KnessetDatabaseService: Querying bills for Knesset $knessetNum${statusID != null ? " with StatusID $statusID" : ""}...');
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        '_KNS_Bill',
        where: statusID != null 
          ? 'KnessetNum = ? AND StatusID = ?'
          : 'KnessetNum = ?',
        whereArgs: statusID != null 
          ? [knessetNum, statusID]
          : [knessetNum],
        orderBy: 'PublicationDate DESC, BillID DESC',
      );
      appLogger.d('KnessetDatabaseService: Fetched ${maps.length} bills for Knesset $knessetNum');
      return maps;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying bills by Knesset', error: e, stackTrace: s);
      return [];
    }
  }

  /// Get status description by StatusID
  Future<String?> getStatusDescription(int statusID) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        '_KNS_Status',
        where: 'StatusID = ?',
        whereArgs: [statusID],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return maps.first['Desc']?.toString();
      }
      return null;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error querying status', error: e, stackTrace: s);
      return null;
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

  /// Apply incremental updates to all tables
  Future<void> _applyIncrementalUpdates() async {
    // Database should already be open at this point
    if (_database == null) {
      appLogger.w('KnessetDatabaseService: Cannot apply incremental updates - database not open');
      return;
    }
    
    // Tables to update with their primary keys
    final tablesToUpdate = [
      {'table': '_KNS_DocumentBill', 'primaryKey': 'DocumentBillID'},
      {'table': '_KNS_Bill', 'primaryKey': 'BillID'},
      {'table': '_KNS_Committee', 'primaryKey': 'CommitteeID'},
      {'table': '_KNS_Person', 'primaryKey': 'PersonID'},
      {'table': '_KNS_CommitteeSession', 'primaryKey': 'CommitteeSessionID'},
      {'table': '_KNS_Faction', 'primaryKey': 'FactionID'},
      {'table': '_KNS_Status', 'primaryKey': 'StatusID'},
    ];
    
    for (final tableInfo in tablesToUpdate) {
      try {
        await _updateTableIncremental(
          tableInfo['table']!,
          tableInfo['primaryKey']!,
        );
      } catch (e) {
        appLogger.w('KnessetDatabaseService: Failed to update ${tableInfo['table']} during init', error: e);
        // Continue with other tables
      }
    }
  }

  /// Verify that required tables exist in the database
  Future<bool> _verifyTablesExist() async {
    if (_database == null) return false;
    
    try {
      // Check if at least one of the expected tables exists
      final result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='_KNS_DocumentBill'",
      );
      return result.isNotEmpty;
    } catch (e) {
      appLogger.w('KnessetDatabaseService: Error verifying tables exist', error: e);
      return false;
    }
  }

  /// Get max ID for a table
  Future<dynamic> _getMaxIdForTable(String tableName, String primaryKey) async {
    final db = await database;
    try {
      // For DocumentBillID (TEXT), we need to handle it differently
      if (primaryKey == 'DocumentBillID') {
        final result = await db.rawQuery(
          'SELECT MAX(CAST("$primaryKey" AS INTEGER)) as max_id FROM "$tableName"',
        );
        final maxIdStr = result.first['max_id'] as int?;
        return maxIdStr?.toString() ?? '0';
      } else {
        final result = await db.rawQuery(
          'SELECT MAX("$primaryKey") as max_id FROM "$tableName"',
        );
        return result.first['max_id'] as int? ?? 0;
      }
    } catch (e) {
      appLogger.w('KnessetDatabaseService: Error getting max ID for $tableName', error: e);
      return primaryKey == 'DocumentBillID' ? '0' : 0;
    }
  }

  /// Update a single table incrementally
  Future<int> _updateTableIncremental(String tableName, String primaryKey) async {
    final db = await database;
    int totalUpdated = 0;
    dynamic currentMaxId = await _getMaxIdForTable(tableName, primaryKey);
    
    appLogger.i('KnessetDatabaseService: Updating $tableName, starting from maxId: $currentMaxId');
    
    while (true) {
      final baseUrl = ApiClient.baseUrl;
      final uri = Uri.parse('$baseUrl/knesset-database/updates/$tableName').replace(
        queryParameters: {'maxId': currentMaxId.toString()},
      );
      
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 30));
        
        if (response.statusCode != 200) {
          appLogger.w('KnessetDatabaseService: Failed to get updates for $tableName: ${response.statusCode}');
          break;
        }
        
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final records = data['records'] as List<dynamic>? ?? [];
        final hasMore = data['hasMore'] as bool? ?? false;
        
        if (records.isEmpty) {
          appLogger.i('KnessetDatabaseService: No new records for $tableName');
          break;
        }
        
        appLogger.i('KnessetDatabaseService: Received ${records.length} new records for $tableName');
        
        // Insert or replace records
        for (final record in records) {
          try {
            final recordMap = Map<String, dynamic>.from(record as Map);
            await db.insert(
              tableName,
              recordMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            totalUpdated++;
            
            // Update currentMaxId
            final pkValue = recordMap[primaryKey];
            if (primaryKey == 'DocumentBillID') {
              final pkInt = int.tryParse(pkValue.toString()) ?? 0;
              final currentInt = int.tryParse(currentMaxId.toString()) ?? 0;
              if (pkInt > currentInt) {
                currentMaxId = pkValue.toString();
              }
            } else {
              final pkInt = pkValue as int? ?? 0;
              if (pkInt > (currentMaxId as int? ?? 0)) {
                currentMaxId = pkInt;
              }
            }
          } catch (e) {
            appLogger.w('KnessetDatabaseService: Error inserting record into $tableName', error: e);
          }
        }
        
        if (!hasMore) {
          break;
        }
        
        appLogger.d('KnessetDatabaseService: More records available for $tableName, continuing...');
      } catch (e) {
        appLogger.e('KnessetDatabaseService: Error fetching updates for $tableName', error: e);
        break;
      }
    }
    
    appLogger.i('KnessetDatabaseService: Updated $tableName with $totalUpdated records');
    return totalUpdated;
  }

  /// Manually update database from server using incremental updates
  /// Returns true if update was successful, false otherwise
  Future<bool> updateDatabase() async {
    try {
      appLogger.i('KnessetDatabaseService: Manual incremental update requested');
      
      // Ensure database is initialized
      await database;
      
      // Tables to update with their primary keys
      final tablesToUpdate = [
        {'table': '_KNS_DocumentBill', 'primaryKey': 'DocumentBillID'},
        {'table': '_KNS_Bill', 'primaryKey': 'BillID'},
        {'table': '_KNS_Committee', 'primaryKey': 'CommitteeID'},
        {'table': '_KNS_Person', 'primaryKey': 'PersonID'},
        {'table': '_KNS_CommitteeSession', 'primaryKey': 'CommitteeSessionID'},
        {'table': '_KNS_Faction', 'primaryKey': 'FactionID'},
        {'table': '_KNS_Status', 'primaryKey': 'StatusID'},
      ];
      
      int totalUpdated = 0;
      
      for (final tableInfo in tablesToUpdate) {
        try {
          final count = await _updateTableIncremental(
            tableInfo['table']!,
            tableInfo['primaryKey']!,
          );
          totalUpdated += count;
        } catch (e) {
          appLogger.w('KnessetDatabaseService: Failed to update ${tableInfo['table']}', error: e);
          // Continue with other tables
        }
      }
      
      appLogger.i('KnessetDatabaseService: Incremental update complete. Total records updated: $totalUpdated');
      
      // Save last update time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error updating database incrementally', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Log database statistics for debugging (compare between devices)
  Future<void> _logDatabaseStatistics() async {
    if (_database == null) return;
    
    try {
      // Count rows in key tables
      final statusCount = await _database!.rawQuery('SELECT COUNT(*) as count FROM _KNS_Status');
      final billCount = await _database!.rawQuery('SELECT COUNT(*) as count FROM _KNS_Bill');
      final knesset25BillCount = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM _KNS_Bill WHERE KnessetNum = 25'
      );
      final status114Exists = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM _KNS_Status WHERE StatusID = 114'
      );
      final status114Desc = await _database!.rawQuery(
        'SELECT Desc FROM _KNS_Status WHERE StatusID = 114 LIMIT 1'
      );
      
      final statusCountNum = statusCount.first['count'] as int? ?? 0;
      final billCountNum = billCount.first['count'] as int? ?? 0;
      final knesset25CountNum = knesset25BillCount.first['count'] as int? ?? 0;
      final status114ExistsNum = status114Exists.first['count'] as int? ?? 0;
      final status114DescText = status114Desc.isNotEmpty 
        ? status114Desc.first['Desc']?.toString() 
        : null;
      
      appLogger.i('═══════════════════════════════════════════════════════════');
      appLogger.i('📊 SQLite Database Statistics:');
      appLogger.i('   Total Statuses: $statusCountNum');
      appLogger.i('   Total Bills: $billCountNum');
      appLogger.i('   Knesset 25 Bills: $knesset25CountNum');
      appLogger.i('   Status 114 exists: ${status114ExistsNum > 0}');
      if (status114DescText != null) {
        appLogger.i('   Status 114 description: "$status114DescText"');
      } else {
        appLogger.w('   Status 114 description: NOT FOUND');
      }
      appLogger.i('═══════════════════════════════════════════════════════════');
    } catch (e, s) {
      appLogger.e('KnessetDatabaseService: Error logging database statistics', error: e, stackTrace: s);
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

