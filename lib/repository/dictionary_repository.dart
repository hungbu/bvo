import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../model/dictionary_entry.dart';

class DictionaryRepository {
  static Database? _database;
  static const String _dbName = 'edict.db';
  static const String _tableName = 'tbl_edict';

  /// Initialize database - copy from assets if needed
  Future<Database> _initDatabase() async {
    if (_database != null) {
      return _database!;
    }

    // Get the database path
    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);

    // Check if database exists, if not copy from assets
    if (!await dbFile.exists()) {
      // Copy from assets
      final data = await rootBundle.load('assets/data/dictionary/$_dbName');
      final bytes = data.buffer.asUint8List();
      await dbFile.create(recursive: true);
      await dbFile.writeAsBytes(bytes);
    }

    // Open database
    _database = await openDatabase(
      dbPath,
      readOnly: true, // Read-only since it's an asset
      singleInstance: true,
    );

    return _database!;
  }

  /// Get database path in app documents directory
  Future<String> _getDatabasePath() async {
    // For assets, we need to copy to a writable location first
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, _dbName);
  }

  /// Search for words matching the query
  Future<List<DictionaryEntry>> searchWord(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final db = await _initDatabase();
    final searchQuery = query.trim().toLowerCase();

    // Search for exact match first, then partial matches
    final results = await db.query(
      _tableName,
      where: 'LOWER(word) = ? OR LOWER(word) LIKE ?',
      whereArgs: [searchQuery, '$searchQuery%'],
      orderBy: 'word ASC',
      limit: 50,
    );

    return results.map((map) => DictionaryEntry.fromMap(map)).toList();
  }

  /// Get exact word match
  Future<DictionaryEntry?> getWord(String word) async {
    if (word.trim().isEmpty) {
      return null;
    }

    final db = await _initDatabase();
    final results = await db.query(
      _tableName,
      where: 'LOWER(word) = ?',
      whereArgs: [word.trim().toLowerCase()],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return DictionaryEntry.fromMap(results.first);
  }

  /// Search words with fuzzy matching
  Future<List<DictionaryEntry>> fuzzySearch(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final db = await _initDatabase();
    final searchQuery = query.trim().toLowerCase();

    // Use LIKE for fuzzy search
    final results = await db.query(
      _tableName,
      where: 'LOWER(word) LIKE ?',
      whereArgs: ['%$searchQuery%'],
      orderBy: 'word ASC',
      limit: 100,
    );

    return results.map((map) => DictionaryEntry.fromMap(map)).toList();
  }

  /// Get random words (for learning)
  Future<List<DictionaryEntry>> getRandomWords({int count = 10}) async {
    final db = await _initDatabase();
    
    // SQLite random function
    final results = await db.query(
      _tableName,
      orderBy: 'RANDOM()',
      limit: count,
    );

    return results.map((map) => DictionaryEntry.fromMap(map)).toList();
  }

  /// Get word count
  Future<int> getWordCount() async {
    final db = await _initDatabase();
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

