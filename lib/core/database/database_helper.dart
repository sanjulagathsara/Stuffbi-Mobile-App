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
    debugPrint('Database path: $path'); // Print path for debugging
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
        last_checked_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE bundles(
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        imagePath TEXT,
        isSynced INTEGER,
        is_favorite INTEGER DEFAULT 0
      )
    ''');
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
  }
}
