import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../model/word.dart';
import 'dart:convert';

/// Repository for querying dictionary.db with words table
class DictionaryWordsRepository {
  static Database? _database;
  static const String _dbName = 'dictionary.db';
  static const String _tableName = 'words';

  /// Initialize database - copy from assets if needed
  Future<Database> _initDatabase() async {
    if (_database != null) {
      return _database!;
    }

    try {
      // Get the database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      print('📁 Database path: $dbPath');
      print('📁 Database exists: ${await dbFile.exists()}');

      // Check if database exists, if not copy from assets
      if (!await dbFile.exists()) {
        print('📦 Copying database from assets...');
        try {
          final data = await rootBundle.load('assets/data/dictionary/$_dbName');
          final bytes = data.buffer.asUint8List();
          print('📦 Loaded ${bytes.length} bytes from assets');
          await dbFile.create(recursive: true);
          await dbFile.writeAsBytes(bytes);
          print('✅ Database copied successfully');
        } catch (e) {
          print('❌ Error loading database from assets: $e');
          print('   Asset path: assets/data/dictionary/$_dbName');
          rethrow;
        }
      } else {
        print('✅ Database file already exists');
      }

      // Open database
      _database = await openDatabase(
        dbPath,
        readOnly: true, // Read-only since it's an asset
        singleInstance: true,
      );
      
      print('✅ Database opened successfully');
      
      // Verify table exists and has data
      try {
        final tableCheck = await _database!.rawQuery(
          "SELECT COUNT(*) as count FROM $_tableName"
        );
        final count = Sqflite.firstIntValue(tableCheck) ?? 0;
        print('📊 Table "$_tableName" has $count rows');
        
        if (count == 0) {
          print('⚠️ WARNING: Table "$_tableName" exists but is EMPTY!');
          // List all tables to help debug
          final allTables = await _database!.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'"
          );
          print('📋 Available tables: ${allTables.map((t) => t['name']).join(', ')}');
        }
      } catch (e) {
        print('❌ Error checking table "$_tableName": $e');
        // List all tables to help debug
        try {
          final allTables = await _database!.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'"
          );
          print('📋 Available tables: ${allTables.map((t) => t['name']).join(', ')}');
        } catch (e2) {
          print('❌ Error listing tables: $e2');
        }
        rethrow;
      }

      return _database!;
    } catch (e, stackTrace) {
      print('❌ Error initializing database: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get database path in app documents directory
  Future<String> _getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, _dbName);
  }

  /// Convert database row to Word model
  Word _mapToWord(Map<String, dynamic> map) {
    // Parse JSON fields
    List<String> tags = [];
    List<String> synonyms = [];
    List<String> antonyms = [];
    
    try {
      if (map['tags'] != null) {
        final tagsData = map['tags'] is String 
            ? json.decode(map['tags'] as String) 
            : map['tags'];
        tags = List<String>.from(tagsData ?? []);
      }
      if (map['synonyms'] != null) {
        final synonymsData = map['synonyms'] is String 
            ? json.decode(map['synonyms'] as String) 
            : map['synonyms'];
        synonyms = List<String>.from(synonymsData ?? []);
      }
      if (map['antonyms'] != null) {
        final antonymsData = map['antonyms'] is String 
            ? json.decode(map['antonyms'] as String) 
            : map['antonyms'];
        antonyms = List<String>.from(antonymsData ?? []);
      }
    } catch (e) {
      print('Error parsing JSON fields: $e');
    }

    // Parse level
    WordLevel level = WordLevel.BASIC;
    try {
      final levelStr = (map['level'] as String? ?? 'BASIC').toUpperCase();
      level = WordLevel.values.firstWhere(
        (e) => e.toString().split('.').last == levelStr,
        orElse: () => WordLevel.BASIC,
      );
    } catch (e) {
      print('Error parsing level: $e');
    }

    // Parse type
    WordType type = WordType.noun;
    try {
      final typeStr = (map['type'] as String? ?? 'noun').toLowerCase();
      type = WordType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
        orElse: () => WordType.noun,
      );
    } catch (e) {
      print('Error parsing type: $e');
    }

    // Parse dates
    DateTime? nextReview;
    DateTime? lastReviewed;
    try {
      if (map['nextReview'] != null) {
        nextReview = DateTime.parse(map['nextReview'] as String);
      }
      if (map['lastReviewed'] != null) {
        lastReviewed = DateTime.parse(map['lastReviewed'] as String);
      }
    } catch (e) {
      print('Error parsing dates: $e');
    }

    return Word(
      id: map['id'] as int?,
      en: map['en'] as String? ?? '',
      vi: map['vi'] as String? ?? '',
      sentence: map['sentence'] as String? ?? '',
      sentenceVi: map['sentenceVi'] as String? ?? '',
      topic: map['topic'] as String? ?? 'general',
      pronunciation: map['pronunciation'] as String? ?? '',
      level: level,
      type: type,
      synonyms: synonyms,
      antonyms: antonyms,
      difficulty: map['difficulty'] as int? ?? 3,
      tags: tags,
      reviewCount: map['reviewCount'] as int? ?? 0,
      nextReview: nextReview ?? DateTime.now().add(const Duration(days: 1)),
      masteryLevel: (map['masteryLevel'] as num?)?.toDouble() ?? 0.0,
      lastReviewed: lastReviewed,
      correctAnswers: map['correctAnswers'] as int? ?? 0,
      totalAttempts: map['totalAttempts'] as int? ?? 0,
      currentInterval: map['currentInterval'] as int? ?? 1,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      isKidFriendly: (map['isKidFriendly'] as int? ?? 0) == 1,
      mnemonicTip: map['mnemonicTip'] as String?,
    );
  }

  /// Search for words matching the query with smart ranking
  Future<List<Word>> searchWord(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final db = await _initDatabase();
      final searchQuery = query.trim().toLowerCase();
      
      print('🔍 DictionaryWordsRepository.searchWord: query="$searchQuery"');

      // Check if table exists
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$_tableName'"
      );
      print('📋 Table "$_tableName" exists: ${tableInfo.isNotEmpty}');
      
      if (tableInfo.isEmpty) {
        print('❌ Table "$_tableName" does not exist in database!');
        // List all available tables
        final allTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'"
        );
        print('📋 Available tables: ${allTables.map((t) => t['name']).join(', ')}');
        
        // Try to find similar table names
        final similarTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%word%'"
        );
        if (similarTables.isNotEmpty) {
          print('💡 Found similar tables: ${similarTables.map((t) => t['name']).join(', ')}');
        }
        return [];
      }
      
      // Check table structure
      final tableSchema = await db.rawQuery(
        "PRAGMA table_info($_tableName)"
      );
      print('📋 Table "$_tableName" columns: ${tableSchema.map((c) => c['name']).join(', ')}');
      
      // Check if 'en' and 'vi' columns exist
      final columnNames = tableSchema.map((c) => c['name'] as String).toList();
      if (!columnNames.contains('en')) {
        print('❌ Column "en" does not exist in table "$_tableName"!');
        print('   Available columns: ${columnNames.join(', ')}');
        return [];
      }

      // Search with smart ranking: exact match > starts with > contains
      // Use CASE to assign priority, then sort by priority
      final results = await db.rawQuery('''
        SELECT *, 
          CASE 
            WHEN LOWER(en) = ? THEN 1
            WHEN LOWER(en) LIKE ? THEN 2
            WHEN LOWER(vi) LIKE ? THEN 3
            WHEN LOWER(en) LIKE ? THEN 4
            WHEN LOWER(vi) LIKE ? THEN 5
            ELSE 6
          END as match_rank
        FROM $_tableName
        WHERE LOWER(en) = ? 
           OR LOWER(en) LIKE ?
           OR LOWER(vi) LIKE ?
           OR LOWER(en) LIKE ?
           OR LOWER(vi) LIKE ?
        ORDER BY match_rank ASC, 
                 CASE WHEN LOWER(en) = ? THEN 0 ELSE 1 END,
                 LENGTH(en) ASC,
                 en ASC
        LIMIT 100
      ''', [
        // For match_rank CASE calculation
        searchQuery,                    // 1: exact match
        '$searchQuery%',                // 2: en starts with
        '$searchQuery%',                // 3: vi starts with  
        '%$searchQuery%',               // 4: en contains
        '%$searchQuery%',               // 5: vi contains
        // For WHERE clause
        searchQuery,                    // exact match
        '$searchQuery%',                // en starts with
        '$searchQuery%',                // vi starts with
        '%$searchQuery%',               // en contains
        '%$searchQuery%',               // vi contains
        // For ORDER BY exact match priority
        searchQuery,                    // exact match priority
      ]);

      print('📊 Query returned ${results.length} raw results');
      
      final words = results.map((map) {
        // Remove match_rank from map before converting to Word
        final wordMap = Map<String, dynamic>.from(map);
        wordMap.remove('match_rank');
        return _mapToWord(wordMap);
      }).toList();
      
      print('✅ Mapped to ${words.length} Word objects');
      print('📊 Results sorted by: exact match > starts with > contains');
      
      return words;
    } catch (e, stackTrace) {
      print('❌ Error in searchWord: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get exact word match
  Future<Word?> getWord(String word) async {
    if (word.trim().isEmpty) {
      return null;
    }

    final db = await _initDatabase();
    final results = await db.query(
      _tableName,
      where: 'LOWER(en) = ?',
      whereArgs: [word.trim().toLowerCase()],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return _mapToWord(results.first);
  }

  /// Search words with fuzzy matching
  Future<List<Word>> fuzzySearch(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final db = await _initDatabase();
    final searchQuery = query.trim().toLowerCase();

    // Use LIKE for fuzzy search
    final results = await db.query(
      _tableName,
      where: 'LOWER(en) LIKE ? OR LOWER(vi) LIKE ?',
      whereArgs: ['%$searchQuery%', '%$searchQuery%'],
      orderBy: 'en ASC',
      limit: 100,
    );

    return results.map((map) => _mapToWord(map)).toList();
  }

  /// Get random words (for learning)
  Future<List<Word>> getRandomWords({int count = 10}) async {
    final db = await _initDatabase();
    
    // SQLite random function
    final results = await db.query(
      _tableName,
      orderBy: 'RANDOM()',
      limit: count,
    );

    return results.map((map) => _mapToWord(map)).toList();
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

