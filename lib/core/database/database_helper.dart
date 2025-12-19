import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  } 

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'stuffbi.db');
    debugPrint('Database path: $path');
    return await openDatabase(
      path,
      version: 7, // Updated for sync support
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Items table with sync columns
    await db.execute('''
      CREATE TABLE items(
        id TEXT PRIMARY KEY,
        name TEXT,
        category TEXT,
        bundleId TEXT,
        imagePath TEXT,
        details TEXT,
        isSynced INTEGER,
        is_checked INTEGER DEFAULT 0,
        last_checked_at TEXT,
        server_id INTEGER,
        sync_status TEXT DEFAULT 'pending',
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    
    // Bundles table with sync columns
    await db.execute('''
      CREATE TABLE bundles(
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        imagePath TEXT,
        isSynced INTEGER,
        is_favorite INTEGER DEFAULT 0,
        server_id INTEGER,
        sync_status TEXT DEFAULT 'pending',
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    
    // Activity logs table with sync columns
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs(
        id TEXT PRIMARY KEY,
        item_id TEXT,
        action_type TEXT,
        timestamp TEXT,
        details TEXT,
        server_id INTEGER,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');
    
    // Create indexes for sync queries
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_sync ON items(sync_status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bundles_sync ON bundles(sync_status)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE bundles(
          id TEXT PRIMARY KEY,
          name TEXT,
          description TEXT,
          imagePath TEXT,
          isSynced INTEGER
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE bundles ADD COLUMN is_favorite INTEGER DEFAULT 0',
        );
      } catch (e) {
        debugPrint('Error adding is_favorite column: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE items ADD COLUMN is_checked INTEGER DEFAULT 0',
        );
      } catch (e) {
        debugPrint('Error adding is_checked column: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE items ADD COLUMN last_checked_at TEXT');
      } catch (e) {
        debugPrint('Error adding last_checked_at column: $e');
      }
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs(
          id TEXT PRIMARY KEY,
          item_id TEXT,
          action_type TEXT,
          timestamp TEXT,
          details TEXT
        )
      ''');
    }
    
    // Add sync columns
    if (oldVersion < 7) {
      debugPrint('Upgrading to version 7: Adding sync columns...');
      
      try {
        await db.execute('ALTER TABLE items ADD COLUMN server_id INTEGER');
      } catch (e) {
        debugPrint('server_id column may already exist: $e');
      }
      try {
        await db.execute("ALTER TABLE items ADD COLUMN sync_status TEXT DEFAULT 'pending'");
      } catch (e) {
        debugPrint('sync_status column may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE items ADD COLUMN updated_at TEXT');
      } catch (e) {
        debugPrint('updated_at column may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE items ADD COLUMN deleted_at TEXT');
      } catch (e) {
        debugPrint('deleted_at column may already exist: $e');
      }
      
      try {
        await db.execute('ALTER TABLE bundles ADD COLUMN server_id INTEGER');
      } catch (e) {
        debugPrint('server_id column may already exist: $e');
      }
      try {
        await db.execute("ALTER TABLE bundles ADD COLUMN sync_status TEXT DEFAULT 'pending'");
      } catch (e) {
        debugPrint('sync_status column may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE bundles ADD COLUMN updated_at TEXT');
      } catch (e) {
        debugPrint('updated_at column may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE bundles ADD COLUMN deleted_at TEXT');
      } catch (e) {
        debugPrint('deleted_at column may already exist: $e');
      }
      
      // Add sync columns to activity_logs
      try {
        await db.execute('ALTER TABLE activity_logs ADD COLUMN server_id INTEGER');
      } catch (e) {
        debugPrint('server_id column may already exist: $e');
      }
      try {
        await db.execute("ALTER TABLE activity_logs ADD COLUMN sync_status TEXT DEFAULT 'pending'");
      } catch (e) {
        debugPrint('sync_status column may already exist: $e');
      }
      
      // Create indexes for sync queries
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_items_sync ON items(sync_status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_bundles_sync ON bundles(sync_status)');
      } catch (e) {
        debugPrint('Error creating indexes: $e');
      }
      
      // Mark all existing items as pending sync
      await db.execute("UPDATE items SET sync_status = 'pending', updated_at = datetime('now') WHERE sync_status IS NULL");
      await db.execute("UPDATE bundles SET sync_status = 'pending', updated_at = datetime('now') WHERE sync_status IS NULL");
      
      debugPrint('Database upgrade to version 7 complete');
    }
  }
}
