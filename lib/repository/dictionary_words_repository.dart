import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../model/word.dart';
import '../service/performance_monitor.dart';
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

    final stopwatch = Stopwatch()..start();
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

      // Open database (writable for progress tracking)
      _database = await openDatabase(
        dbPath,
        readOnly: false, // Allow writes for progress tracking
        singleInstance: true,
        version: 1,
        onCreate: (db, version) async {
          // This should not be called if database exists, but just in case
          print('⚠️ Database onCreate called - this should not happen if database was copied from assets');
        },
      );
      
      print('✅ Database opened successfully');
      
      // OPTIMIZED: Create indexes to speed up queries
      try {
        final indexStopwatch = Stopwatch()..start();
        // Index on en column for fast lookups
        await _database!.execute('CREATE INDEX IF NOT EXISTS idx_words_en ON $_tableName(en)');
        // Index on topic column for fast topic queries
        await _database!.execute('CREATE INDEX IF NOT EXISTS idx_words_topic ON $_tableName(topic)');
        // Index on LOWER(en) for case-insensitive queries (if supported)
        // Note: SQLite doesn't support functional indexes directly, but we can use COLLATE NOCASE
        indexStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('_initDatabase.createIndexes', indexStopwatch.elapsed);
        print('✅ Database indexes created/verified');
      } catch (e) {
        print('⚠️ Warning: Could not create indexes (may already exist): $e');
      }
      
      // OPTIMIZED: Create topic_words mapping table for faster topic queries
      // This denormalized table pre-computes topic-word relationships
      try {
        final tableStopwatch = Stopwatch()..start();
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS topic_words (
            topic TEXT NOT NULL,
            word_en TEXT NOT NULL,
            word_id INTEGER,
            PRIMARY KEY (topic, word_en),
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
        
        // Create indexes on topic_words table
        await _database!.execute('CREATE INDEX IF NOT EXISTS idx_topic_words_topic ON topic_words(topic)');
        await _database!.execute('CREATE INDEX IF NOT EXISTS idx_topic_words_word_en ON topic_words(word_en)');
        
        // Populate topic_words table if empty (one-time migration)
        final countResult = await _database!.rawQuery('SELECT COUNT(*) as count FROM topic_words');
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        
        if (count == 0) {
          print('📦 Populating topic_words table (one-time migration)...');
          final populateStopwatch = Stopwatch()..start();
          
          // Insert all topic-word relationships from words table
          await _database!.execute('''
            INSERT INTO topic_words (topic, word_en, word_id)
            SELECT DISTINCT topic, en, id FROM words WHERE topic IS NOT NULL AND topic != ''
          ''');
          
          populateStopwatch.stop();
          PerformanceMonitor.trackAsyncOperation('_initDatabase.populateTopicWords', populateStopwatch.elapsed);
          print('✅ Populated topic_words table');
        }
        
        tableStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('_initDatabase.createTopicWordsTable', tableStopwatch.elapsed);
        print('✅ topic_words table created/verified');
      } catch (e) {
        print('⚠️ Warning: Could not create topic_words table: $e');
        // Continue without topic_words table - fallback to regular queries
      }
      
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('_initDatabase', stopwatch.elapsed, metadata: {
        'database_path': dbPath,
        'database_exists': await dbFile.exists(),
      });
      
      // Verify table exists and has data
      try {
        final tableCheckStopwatch = Stopwatch()..start();
        final tableCheck = await _database!.rawQuery(
          "SELECT COUNT(*) as count FROM $_tableName"
        );
        tableCheckStopwatch.stop();
        PerformanceMonitor.trackDatabaseQuery(
          "SELECT COUNT(*) as count FROM $_tableName",
          tableCheckStopwatch.elapsed,
          method: '_initDatabase.tableCheck',
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

    final methodStopwatch = Stopwatch()..start();
    try {
      final db = await _initDatabase();
      final searchQuery = query.trim().toLowerCase();
      
      print('🔍 DictionaryWordsRepository.searchWord: query="$searchQuery"');

      // Check if table exists
      var queryStopwatch = Stopwatch()..start();
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$_tableName'"
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$_tableName'",
        queryStopwatch.elapsed,
        method: 'searchWord.tableCheck',
      );
      print('📋 Table "$_tableName" exists: ${tableInfo.isNotEmpty}');
      
      if (tableInfo.isEmpty) {
        print('❌ Table "$_tableName" does not exist in database!');
        // List all available tables
        queryStopwatch = Stopwatch()..start();
        final allTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'"
        );
        queryStopwatch.stop();
        PerformanceMonitor.trackDatabaseQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
          queryStopwatch.elapsed,
          method: 'searchWord.listTables',
        );
        print('📋 Available tables: ${allTables.map((t) => t['name']).join(', ')}');
        
        // Try to find similar table names
        queryStopwatch = Stopwatch()..start();
        final similarTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%word%'"
        );
        queryStopwatch.stop();
        PerformanceMonitor.trackDatabaseQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%word%'",
          queryStopwatch.elapsed,
          method: 'searchWord.similarTables',
        );
        if (similarTables.isNotEmpty) {
          print('💡 Found similar tables: ${similarTables.map((t) => t['name']).join(', ')}');
        }
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('searchWord', methodStopwatch.elapsed, metadata: {
          'query': query,
          'found': false,
          'error': 'table_not_found',
        });
        return [];
      }
      
      // Check table structure
      queryStopwatch = Stopwatch()..start();
      final tableSchema = await db.rawQuery(
        "PRAGMA table_info($_tableName)"
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        "PRAGMA table_info($_tableName)",
        queryStopwatch.elapsed,
        method: 'searchWord.tableSchema',
      );
      print('📋 Table "$_tableName" columns: ${tableSchema.map((c) => c['name']).join(', ')}');
      
      // Check if 'en' and 'vi' columns exist
      final columnNames = tableSchema.map((c) => c['name'] as String).toList();
      if (!columnNames.contains('en')) {
        print('❌ Column "en" does not exist in table "$_tableName"!');
        print('   Available columns: ${columnNames.join(', ')}');
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('searchWord', methodStopwatch.elapsed, metadata: {
          'query': query,
          'found': false,
          'error': 'column_not_found',
        });
        return [];
      }

      // Search with smart ranking: exact match > starts with > contains
      // Use CASE to assign priority, then sort by priority
      queryStopwatch = Stopwatch()..start();
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
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) = ? OR LOWER(en) LIKE ? ... (searchWord main query)',
        queryStopwatch.elapsed,
        method: 'searchWord.main',
      );

      print('📊 Query returned ${results.length} raw results');
      
      final words = results.map((map) {
        // Remove match_rank from map before converting to Word
        final wordMap = Map<String, dynamic>.from(map);
        wordMap.remove('match_rank');
        return _mapToWord(wordMap);
      }).toList();
      
      print('✅ Mapped to ${words.length} Word objects');
      print('📊 Results sorted by: exact match > starts with > contains');
      
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('searchWord', methodStopwatch.elapsed, metadata: {
        'query': query,
        'found': true,
        'count': words.length,
      });
      
      return words;
    } catch (e, stackTrace) {
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('searchWord', methodStopwatch.elapsed, metadata: {
        'query': query,
        'error': e.toString(),
      });
      print('❌ Error in searchWord: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Normalize word for database query
  /// Handles special characters, case, and whitespace
  String _normalizeWord(String word) {
    // Trim whitespace
    String normalized = word.trim();
    
    // Convert to lowercase for case-insensitive matching
    normalized = normalized.toLowerCase();
    
    // Handle common special characters that might be stored differently
    // Keep the original characters but ensure consistent comparison
    
    return normalized;
  }

  /// Normalize topic for database query
  /// Handles special characters (e.g., "1.1", "1.2"), case, and whitespace
  String _normalizeTopic(String topic) {
    // Trim whitespace
    String normalized = topic.trim();
    
    // Convert to lowercase for case-insensitive matching
    normalized = normalized.toLowerCase();
    
    // Handle common special characters that might be stored differently
    // Keep the original characters but ensure consistent comparison
    
    return normalized;
  }

  /// Test method: Query specific words and check their topics
  Future<Map<String, dynamic>> testWordsTopics(List<String> words) async {
    final db = await _initDatabase();
    final results = <String, Map<String, dynamic>>{};
    
    for (final word in words) {
      try {
        // Query directly to get topic
        final wordResults = await db.rawQuery(
          'SELECT en, topic, LENGTH(topic) as topic_length, HEX(topic) as topic_hex FROM $_tableName WHERE LOWER(en) = ? LIMIT 1',
          [word.toLowerCase()],
        );
        
        if (wordResults.isNotEmpty) {
          final row = wordResults.first;
          results[word] = {
            'found': true,
            'en': row['en'],
            'topic': row['topic'],
            'topic_length': row['topic_length'],
            'topic_hex': row['topic_hex'],
            'topic_codeUnits': (row['topic'] as String?)?.codeUnits,
          };
        } else {
          results[word] = {'found': false};
        }
      } catch (e) {
        results[word] = {'found': false, 'error': e.toString()};
      }
    }
    
    return {'words': results};
  }

  /// Test method: Query all words with topic "1.1" using different methods
  Future<Map<String, dynamic>> testTopicQuery(String topic) async {
    final db = await _initDatabase();
    final results = <String, dynamic>{};
    
    try {
      // Method 1: Exact match
      final exact = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE topic = ?',
        [topic],
      );
      results['exact_match'] = Sqflite.firstIntValue(exact) ?? 0;
      
      // Method 2: Case-insensitive
      final lower = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE LOWER(topic) = ?',
        [topic.toLowerCase()],
      );
      results['lower_match'] = Sqflite.firstIntValue(lower) ?? 0;
      
      // Method 3: Get sample rows
      final samples = await db.rawQuery(
        'SELECT en, topic, LENGTH(topic) as len, HEX(topic) as hex FROM $_tableName WHERE topic = ? LIMIT 5',
        [topic],
      );
      results['sample_rows'] = samples.map((r) => {
        'en': r['en'],
        'topic': r['topic'],
        'length': r['len'],
        'hex': r['hex'],
        'codeUnits': (r['topic'] as String?)?.codeUnits,
      }).toList();
      
      // Method 4: Check if topic exists with different formats
      final allTopics = await db.rawQuery(
        'SELECT DISTINCT topic, COUNT(*) as count FROM $_tableName WHERE topic LIKE ? OR topic LIKE ? GROUP BY topic LIMIT 10',
        ['%1.1%', '1.1%'],
      );
      results['similar_topics'] = allTopics.map((r) => {
        'topic': r['topic'],
        'count': r['count'],
        'codeUnits': (r['topic'] as String?)?.codeUnits,
      }).toList();
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Debug method: Check what topics exist in database (for troubleshooting)
  Future<Map<String, dynamic>> debugTopicExists(String topic) async {
    final db = await _initDatabase();
    final trimmedTopic = topic.trim();
    final normalizedTopic = _normalizeTopic(trimmedTopic);
    
    final results = <String, dynamic>{
      'original': topic,
      'trimmed': trimmedTopic,
      'normalized': normalizedTopic,
      'found': false,
      'matches': <String>[],
      'sampleTopics': <String>[],
    };
    
    try {
      // Get sample topics (only target topics + a few others for debugging)
      var sampleTopics = await db.rawQuery(
        'SELECT DISTINCT topic FROM $_tableName WHERE topic IN (?, ?, ?, ?, ?, ?) OR topic LIKE ? ORDER BY topic LIMIT 20',
        ['1.1', '1.2', '1.3', '1.4', '1.5', '2.0', 'general%'],
      );
      results['sampleTopics'] = sampleTopics.map((r) => r['topic'] as String).toList();
      
      // Check exact match
      var exactMatches = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE topic = ?',
        [trimmedTopic],
      );
      final exactCount = Sqflite.firstIntValue(exactMatches) ?? 0;
      if (exactCount > 0) {
        results['found'] = true;
        results['exactCount'] = exactCount;
      }
      
      // Check case-insensitive
      var lowerMatches = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE LOWER(topic) = ?',
        [normalizedTopic],
      );
      final lowerCount = Sqflite.firstIntValue(lowerMatches) ?? 0;
      if (lowerCount > 0) {
        results['found'] = true;
        results['lowerCount'] = lowerCount;
      }
      
      // Get actual topic values that match
      var actualTopics = await db.rawQuery(
        'SELECT DISTINCT topic FROM $_tableName WHERE topic LIKE ? OR LOWER(topic) LIKE ? LIMIT 10',
        ['%$trimmedTopic%', '%$normalizedTopic%'],
      );
      results['matches'] = actualTopics.map((r) => r['topic'] as String).toList();
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Debug method: Check if word exists in database (for troubleshooting)
  Future<Map<String, dynamic>> debugWordExists(String word) async {
    final db = await _initDatabase();
    final trimmedWord = word.trim();
    final normalizedWord = _normalizeWord(trimmedWord);
    
    final results = <String, dynamic>{
      'original': word,
      'trimmed': trimmedWord,
      'normalized': normalizedWord,
      'found': false,
      'matches': <String>[],
    };
    
    try {
      // Check exact match
      var exactMatches = await db.rawQuery(
        'SELECT en FROM $_tableName WHERE LOWER(TRIM(en)) = ? LIMIT 5',
        [normalizedWord],
      );
      if (exactMatches.isNotEmpty) {
        results['found'] = true;
        results['matches'].addAll(exactMatches.map((r) => r['en'] as String));
      }
      
      // Check LIKE match
      var likeMatches = await db.rawQuery(
        'SELECT en FROM $_tableName WHERE LOWER(en) LIKE ? LIMIT 5',
        ['%$normalizedWord%'],
      );
      for (var match in likeMatches) {
        final matchWord = match['en'] as String;
        if (!results['matches'].contains(matchWord)) {
          results['matches'].add(matchWord);
        }
      }
      
      // Check similar words (for debugging)
      var similarWords = await db.rawQuery(
        'SELECT en FROM $_tableName WHERE LOWER(en) LIKE ? OR LOWER(en) LIKE ? LIMIT 10',
        ['${normalizedWord}%', '%$normalizedWord'],
      );
      results['similar'] = similarWords.map((r) => r['en'] as String).toList();
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Get exact word match with multiple fallback strategies
  /// Handles case-insensitive matching and special characters
  /// OPTIMIZED: Added logging to track where calls are coming from
  Future<Word?> getWord(String word) async {
    if (word.trim().isEmpty) {
      return null;
    }

    final methodStopwatch = Stopwatch()..start();
    final db = await _initDatabase();
    final trimmedWord = word.trim();
    final normalizedWord = _normalizeWord(trimmedWord);
    
    try {
      // OPTIMIZED Strategy 1: Use indexed column with COLLATE NOCASE (fastest, uses index)
      var queryStopwatch = Stopwatch()..start();
      var results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE en = ? COLLATE NOCASE LIMIT 1',
        [trimmedWord],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE en = ? COLLATE NOCASE LIMIT 1',
        queryStopwatch.elapsed,
        method: 'getWord.strategy1_indexed',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
          'word': word,
          'found': true,
          'strategy': 'strategy1_indexed',
        });
        return _mapToWord(results.first);
      }

      // Strategy 2: Exact case-insensitive match with LOWER (fallback)
      queryStopwatch = Stopwatch()..start();
      results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) = ? LIMIT 1',
        [normalizedWord],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) = ? LIMIT 1',
        queryStopwatch.elapsed,
        method: 'getWord.strategy2',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
          'word': word,
          'found': true,
          'strategy': 'strategy2',
        });
    return _mapToWord(results.first);
      }

      // Strategy 3: Try with TRIM (for words with whitespace)
      queryStopwatch = Stopwatch()..start();
      results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE LOWER(TRIM(en)) = ? LIMIT 1',
        [normalizedWord],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE LOWER(TRIM(en)) = ? LIMIT 1',
        queryStopwatch.elapsed,
        method: 'getWord.strategy3',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
          'word': word,
          'found': true,
          'strategy': 'strategy3',
        });
        return _mapToWord(results.first);
      }

      // Strategy 4: Try with different quote styles (for words like 's, 're, 'm, &)
      // Handle words that might be stored with or without quotes
      String wordVariations = normalizedWord;
      
      // Try without leading/trailing quotes
      if (wordVariations.startsWith("'") || wordVariations.startsWith("'")) {
        final withoutLeadingQuote = wordVariations.substring(1);
        queryStopwatch = Stopwatch()..start();
        results = await db.rawQuery(
          'SELECT * FROM $_tableName WHERE LOWER(en) = ? OR LOWER(en) LIKE ? LIMIT 1',
          [withoutLeadingQuote, '$withoutLeadingQuote%'],
        );
        queryStopwatch.stop();
        PerformanceMonitor.trackDatabaseQuery(
          'SELECT * FROM $_tableName WHERE LOWER(en) = ? OR LOWER(en) LIKE ? LIMIT 1',
          queryStopwatch.elapsed,
          method: 'getWord.strategy4a',
        );
        if (results.isNotEmpty) {
          methodStopwatch.stop();
          PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
            'word': word,
            'found': true,
            'strategy': 'strategy4a',
          });
          return _mapToWord(results.first);
        }
      }
      
      // Try with quotes if original doesn't have them
      if (!wordVariations.startsWith("'") && !wordVariations.startsWith("'")) {
        queryStopwatch = Stopwatch()..start();
        results = await db.rawQuery(
          'SELECT * FROM $_tableName WHERE LOWER(en) = ? OR LOWER(en) = ? LIMIT 1',
          ["'$wordVariations", "'$wordVariations"],
        );
        queryStopwatch.stop();
        PerformanceMonitor.trackDatabaseQuery(
          'SELECT * FROM $_tableName WHERE LOWER(en) = ? OR LOWER(en) = ? LIMIT 1',
          queryStopwatch.elapsed,
          method: 'getWord.strategy4b',
        );
        if (results.isNotEmpty) {
          methodStopwatch.stop();
          PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
            'word': word,
            'found': true,
            'strategy': 'strategy4b',
          });
          return _mapToWord(results.first);
        }
      }

      // Strategy 5: Try LIKE match for special characters (handles &, etc.)
      // Escape SQL LIKE special characters
      String escapedWord = normalizedWord
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      
      queryStopwatch = Stopwatch()..start();
      results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) LIKE ? ESCAPE \'\\\' LIMIT 1',
        [escapedWord],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) LIKE ? ESCAPE \'\\\' LIMIT 1',
        queryStopwatch.elapsed,
        method: 'getWord.strategy5',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
          'word': word,
          'found': true,
          'strategy': 'strategy5',
        });
        return _mapToWord(results.first);
      }

      // Strategy 6: Try fuzzy match (last resort - might match similar words)
      queryStopwatch = Stopwatch()..start();
      results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) LIKE ? LIMIT 1',
        ['%$normalizedWord%'],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE LOWER(en) LIKE ? LIMIT 1',
        queryStopwatch.elapsed,
        method: 'getWord.strategy6',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWord', methodStopwatch.elapsed, metadata: {
          'word': word,
          'found': true,
          'strategy': 'strategy6',
        });
        return _mapToWord(results.first);
      }
    } catch (e) {
      print('⚠️ Error in getWord for "$word": $e');
    }

    // Debug: Log when word not found (only for special characters to avoid spam)
    final hasSpecialChars = normalizedWord.contains('&') || 
        normalizedWord.contains("'") || 
        normalizedWord.contains('"') ||
        normalizedWord.contains('`');
    final isShort = normalizedWord.length <= 2;
    final startsWithNonLetter = normalizedWord.isNotEmpty && 
        !RegExp(r'^[a-z]').hasMatch(normalizedWord);
    
    if (hasSpecialChars || isShort || startsWithNonLetter) {
      print('⚠️ Word not found: "$word" (normalized: "$normalizedWord")');
      // Try to find similar words for debugging
      try {
        final similar = await db.rawQuery(
          'SELECT en FROM $_tableName WHERE LOWER(en) LIKE ? OR LOWER(en) LIKE ? LIMIT 3',
          ['${normalizedWord}%', '%$normalizedWord'],
        );
        if (similar.isNotEmpty) {
          print('   Similar words found: ${similar.map((r) => r['en']).join(", ")}');
        }
      } catch (e) {
        // Ignore debug errors
      }
    }

    return null;
  }

  /// Search words with fuzzy matching
  Future<List<Word>> fuzzySearch(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final methodStopwatch = Stopwatch()..start();
    final db = await _initDatabase();
    final searchQuery = query.trim().toLowerCase();

    // Use LIKE for fuzzy search
    final queryStopwatch = Stopwatch()..start();
    final results = await db.query(
      _tableName,
      where: 'LOWER(en) LIKE ? OR LOWER(vi) LIKE ?',
      whereArgs: ['%$searchQuery%', '%$searchQuery%'],
      orderBy: 'en ASC',
      limit: 100,
    );
    queryStopwatch.stop();
    PerformanceMonitor.trackDatabaseQuery(
      'SELECT * FROM $_tableName WHERE LOWER(en) LIKE ? OR LOWER(vi) LIKE ? ORDER BY en ASC LIMIT 100',
      queryStopwatch.elapsed,
      method: 'fuzzySearch',
    );

    methodStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('fuzzySearch', methodStopwatch.elapsed, metadata: {
      'query': query,
      'count': results.length,
    });

    return results.map((map) => _mapToWord(map)).toList();
  }

  /// Get random words (for learning)
  Future<List<Word>> getRandomWords({int count = 10}) async {
    final methodStopwatch = Stopwatch()..start();
    final db = await _initDatabase();
    
    // SQLite random function
    final queryStopwatch = Stopwatch()..start();
    final results = await db.query(
      _tableName,
      orderBy: 'RANDOM()',
      limit: count,
    );
    queryStopwatch.stop();
    PerformanceMonitor.trackDatabaseQuery(
      'SELECT * FROM $_tableName ORDER BY RANDOM() LIMIT $count',
      queryStopwatch.elapsed,
      method: 'getRandomWords',
    );

    methodStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('getRandomWords', methodStopwatch.elapsed, metadata: {
      'count': count,
      'result_count': results.length,
    });

    return results.map((map) => _mapToWord(map)).toList();
  }

  /// Get word count
  Future<int> getWordCount() async {
    final methodStopwatch = Stopwatch()..start();
    final db = await _initDatabase();
    final queryStopwatch = Stopwatch()..start();
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    queryStopwatch.stop();
    PerformanceMonitor.trackDatabaseQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
      queryStopwatch.elapsed,
      method: 'getWordCount',
    );
    
    methodStopwatch.stop();
    final count = Sqflite.firstIntValue(result) ?? 0;
    PerformanceMonitor.trackAsyncOperation('getWordCount', methodStopwatch.elapsed, metadata: {
      'count': count,
    });
    return count;
  }

  /// Get learned words count (reviewCount >= 5) - optimized SQL COUNT
  Future<int> getLearnedWordsCount() async {
    final methodStopwatch = Stopwatch()..start();
    final db = await _initDatabase();
    final queryStopwatch = Stopwatch()..start();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE reviewCount >= 5'
    );
    queryStopwatch.stop();
    PerformanceMonitor.trackDatabaseQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE reviewCount >= 5',
      queryStopwatch.elapsed,
      method: 'getLearnedWordsCount',
    );
    
    methodStopwatch.stop();
    final count = Sqflite.firstIntValue(result) ?? 0;
    PerformanceMonitor.trackAsyncOperation('getLearnedWordsCount', methodStopwatch.elapsed, metadata: {
      'count': count,
    });
    return count;
  }

  /// Get words by topic/level with multiple search strategies
  /// Handles case-insensitive matching and special characters (e.g., "1.1", "1.2")
  Future<List<Word>> getWordsByTopic(String topic) async {
    if (topic.trim().isEmpty) {
      return [];
    }

    final methodStopwatch = Stopwatch()..start();
    try {
      final db = await _initDatabase();
      final trimmedTopic = topic.trim();
      final normalizedTopic = _normalizeTopic(trimmedTopic);
      
      // Strategy 1: Exact match (fastest)
      var queryStopwatch = Stopwatch()..start();
      var results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE topic = ? ORDER BY en ASC LIMIT 100',
        [trimmedTopic],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE topic = ? ORDER BY en ASC LIMIT 100',
        queryStopwatch.elapsed,
        method: 'getWordsByTopic.strategy1',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWordsByTopic', methodStopwatch.elapsed, metadata: {
          'topic': topic,
          'found': true,
          'count': results.length,
          'strategy': 'strategy1',
        });
        return results.map((map) => _mapToWord(map)).toList();
      }

      // Strategy 2: Case-insensitive match (fallback)
      queryStopwatch = Stopwatch()..start();
      results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE LOWER(topic) = ? ORDER BY en ASC LIMIT 100',
        [normalizedTopic],
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE LOWER(topic) = ? ORDER BY en ASC LIMIT 100',
        queryStopwatch.elapsed,
        method: 'getWordsByTopic.strategy2',
      );

      if (results.isNotEmpty) {
        methodStopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('getWordsByTopic', methodStopwatch.elapsed, metadata: {
          'topic': topic,
          'found': true,
          'count': results.length,
          'strategy': 'strategy2',
        });
        return results.map((map) => _mapToWord(map)).toList();
      }

      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getWordsByTopic', methodStopwatch.elapsed, metadata: {
        'topic': topic,
        'found': false,
        'count': 0,
        'strategy': 'none',
      });
      return [];
    } catch (e) {
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getWordsByTopic', methodStopwatch.elapsed, metadata: {
        'topic': topic,
        'error': e.toString(),
      });
      print('❌ Error getting words by topic "$topic": $e');
      return [];
    }
  }

  /// Get words for multiple topics in batch (optimized for loading all topics)
  Future<List<Word>> getWordsByTopicsBatch(List<String> topics) async {
    if (topics.isEmpty) return [];
    
    final methodStopwatch = Stopwatch()..start();
    try {
      final db = await _initDatabase();
      
      // Create placeholders for IN clause
      final placeholders = topics.map((_) => '?').join(',');
      
      // Query all topics at once
      final queryStopwatch = Stopwatch()..start();
      final results = await db.rawQuery(
        'SELECT * FROM $_tableName WHERE topic IN ($placeholders) ORDER BY topic ASC, en ASC',
        topics,
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName WHERE topic IN ($placeholders) ORDER BY topic ASC, en ASC',
        queryStopwatch.elapsed,
        method: 'getWordsByTopicsBatch',
      );
      
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getWordsByTopicsBatch', methodStopwatch.elapsed, metadata: {
        'topics': topics.join(','),
        'count': results.length,
      });
      
      return results.map((map) => _mapToWord(map)).toList();
    } catch (e) {
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getWordsByTopicsBatch', methodStopwatch.elapsed, metadata: {
        'topics': topics.join(','),
        'error': e.toString(),
      });
      print('❌ Error getting words by topics batch: $e');
      return [];
    }
  }

  /// Get multiple words by their English text in batch (optimized for file fallback)
  /// Handles case-insensitive matching and special characters
  Future<Map<String, Word>> getWordsBatch(List<String> words) async {
    if (words.isEmpty) return {};
    
    final methodStopwatch = Stopwatch()..start();
    try {
      final db = await _initDatabase();
      
      // Normalize all words for case-insensitive matching
      final normalizedWords = words.map((w) => _normalizeWord(w.trim())).toList();
      final trimmedWords = words.map((w) => w.trim()).toList();
      
      // Create a map to track original word -> normalized word for lookup
      final wordMap = <String, String>{};
      for (var i = 0; i < words.length; i++) {
        wordMap[normalizedWords[i]] = words[i];
        wordMap[trimmedWords[i]] = words[i];
      }
      
      // Strategy 1: Batch query with LOWER(TRIM(en)) IN (...)
      // SQLite has a limit on number of parameters (999), so we batch in chunks if needed
      const maxBatchSize = 500;
      final results = <Word>[];
      
      for (var i = 0; i < normalizedWords.length; i += maxBatchSize) {
        final batch = normalizedWords.sublist(
          i,
          i + maxBatchSize > normalizedWords.length ? normalizedWords.length : i + maxBatchSize,
        );
        
        final placeholders = batch.map((_) => '?').join(',');
        final queryStopwatch = Stopwatch()..start();
        final batchResults = await db.rawQuery(
          'SELECT * FROM $_tableName WHERE LOWER(TRIM(en)) IN ($placeholders)',
          batch,
        );
        queryStopwatch.stop();
        PerformanceMonitor.trackDatabaseQuery(
          'SELECT * FROM $_tableName WHERE LOWER(TRIM(en)) IN ($placeholders)',
          queryStopwatch.elapsed,
          method: 'getWordsBatch.strategy1',
        );
        
        results.addAll(batchResults.map((map) => _mapToWord(map)));
      }
      
      // Create a map: normalized word -> Word object for quick lookup
      final wordMapResult = <String, Word>{};
      for (final word in results) {
        final normalized = _normalizeWord(word.en);
        wordMapResult[normalized] = word;
        wordMapResult[word.en.toLowerCase()] = word;
      }
      
      // Map original words to Word objects
      final result = <String, Word>{};
      for (final originalWord in words) {
        final normalized = _normalizeWord(originalWord.trim());
        final trimmed = originalWord.trim();
        
        // Try normalized first, then trimmed, then original
        if (wordMapResult.containsKey(normalized)) {
          result[originalWord] = wordMapResult[normalized]!;
        } else if (wordMapResult.containsKey(trimmed.toLowerCase())) {
          result[originalWord] = wordMapResult[trimmed.toLowerCase()]!;
        } else if (wordMapResult.containsKey(originalWord.toLowerCase())) {
          result[originalWord] = wordMapResult[originalWord.toLowerCase()]!;
        }
      }
      
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getWordsBatch', methodStopwatch.elapsed, metadata: {
        'inputCount': words.length,
        'foundCount': result.length,
        'batches': (normalizedWords.length / maxBatchSize).ceil(),
      });
      
      return result;
    } catch (e) {
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getWordsBatch', methodStopwatch.elapsed, metadata: {
        'inputCount': words.length,
        'error': e.toString(),
      });
      print('❌ Error getting words batch: $e');
      return {};
    }
  }

  /// Get all words (for statistics)
  Future<List<Word>> getAllWords({int? limit}) async {
    final methodStopwatch = Stopwatch()..start();
    try {
      final db = await _initDatabase();
      
      final queryStopwatch = Stopwatch()..start();
      final results = await db.query(
        _tableName,
        orderBy: 'en ASC',
        limit: limit,
      );
      queryStopwatch.stop();
      PerformanceMonitor.trackDatabaseQuery(
        'SELECT * FROM $_tableName ORDER BY en ASC${limit != null ? ' LIMIT $limit' : ''}',
        queryStopwatch.elapsed,
        method: 'getAllWords',
      );
      
      methodStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('getAllWords', methodStopwatch.elapsed, metadata: {
        'limit': limit,
        'count': results.length,
      });
      
      return results.map((map) => _mapToWord(map)).toList();
    } catch (e) {
      print('❌ Error getting all words: $e');
      return [];
    }
  }

  /// Update word progress in database
  Future<bool> updateWordProgress({
    required String wordEn,
    int? reviewCount,
    int? correctAnswers,
    int? totalAttempts,
    double? masteryLevel,
    DateTime? nextReview,
    DateTime? lastReviewed,
    int? currentInterval,
    double? easeFactor,
  }) async {
    try {
      final db = await _initDatabase();
      
      // Build update map with only provided values
      final updateMap = <String, dynamic>{};
      if (reviewCount != null) updateMap['reviewCount'] = reviewCount;
      if (correctAnswers != null) updateMap['correctAnswers'] = correctAnswers;
      if (totalAttempts != null) updateMap['totalAttempts'] = totalAttempts;
      if (masteryLevel != null) updateMap['masteryLevel'] = masteryLevel;
      if (nextReview != null) updateMap['nextReview'] = nextReview.toIso8601String();
      if (lastReviewed != null) updateMap['lastReviewed'] = lastReviewed.toIso8601String();
      if (currentInterval != null) updateMap['currentInterval'] = currentInterval;
      if (easeFactor != null) updateMap['easeFactor'] = easeFactor;
      
      // Always update updated_at
      updateMap['updated_at'] = DateTime.now().toIso8601String();
      
      if (updateMap.isEmpty) {
        print('⚠️ No fields to update for word: $wordEn');
        return false;
      }
      
      final rowsAffected = await db.update(
        _tableName,
        updateMap,
        where: 'LOWER(en) = ?',
        whereArgs: [wordEn.toLowerCase()],
      );
      
      if (rowsAffected > 0) {
        print('✅ Updated progress for word "$wordEn": $updateMap');
        return true;
      } else {
        print('⚠️ Word "$wordEn" not found in database');
        return false;
      }
    } catch (e) {
      print('❌ Error updating word progress for "$wordEn": $e');
      return false;
    }
  }

  /// Get learning progress for multiple words (batch query)
  /// Returns a map of word (lowercase) -> progress data
  Future<Map<String, Map<String, dynamic>>> getWordsProgressBatch(List<String> wordEnList) async {
    if (wordEnList.isEmpty) return {};
    
    try {
      final db = await _initDatabase();
      final placeholders = wordEnList.map((_) => '?').join(',');
      
      final List<Map<String, dynamic>> rows = await db.query(
        _tableName,
        columns: [
          'en',
          'reviewCount',
          'correctAnswers',
          'totalAttempts',
          'masteryLevel',
          'nextReview',
          'lastReviewed',
          'currentInterval',
          'easeFactor',
        ],
        where: 'LOWER(en) IN ($placeholders)',
        whereArgs: wordEnList.map((w) => w.toLowerCase()).toList(),
      );
      
      final progressMap = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final en = (row['en'] as String? ?? '').toLowerCase();
        progressMap[en] = {
          'reviewCount': row['reviewCount'] as int? ?? 0,
          'correctAnswers': row['correctAnswers'] as int? ?? 0,
          'totalAttempts': row['totalAttempts'] as int? ?? 0,
          'masteryLevel': (row['masteryLevel'] as num?)?.toDouble() ?? 0.0,
          'nextReview': row['nextReview'] as String?,
          'lastReviewed': row['lastReviewed'] as String?,
          'currentInterval': row['currentInterval'] as int? ?? 1,
          'easeFactor': (row['easeFactor'] as num?)?.toDouble() ?? 2.5,
        };
      }
      
      return progressMap;
    } catch (e) {
      print('❌ Error getting words progress batch: $e');
      return {};
    }
  }

  /// Update word progress after answer (convenience method)
  Future<bool> updateWordProgressAfterAnswer({
    required String wordEn,
    required bool isCorrect,
  }) async {
    try {
      // Get current progress
      final word = await getWord(wordEn);
      if (word == null) {
        print('⚠️ Word "$wordEn" not found in database');
        return false;
      }
      
      // Calculate new values
      final newReviewCount = word.reviewCount + 1;
      final newTotalAttempts = word.totalAttempts + 1;
      final newCorrectAnswers = isCorrect ? word.correctAnswers + 1 : word.correctAnswers;
      final newMasteryLevel = newTotalAttempts > 0 
          ? (newCorrectAnswers / newTotalAttempts).clamp(0.0, 1.0)
          : 0.0;
      
      // Calculate next review date (spaced repetition)
      final accuracy = newCorrectAnswers / newTotalAttempts;
      int daysToAdd = 1;
      if (accuracy >= 0.8) {
        daysToAdd = [1, 3, 7, 14, 30][newReviewCount.clamp(0, 4)];
      } else if (accuracy >= 0.6) {
        daysToAdd = [1, 2, 4, 7, 14][newReviewCount.clamp(0, 4)];
      }
      
      // Calculate new interval and ease factor (simplified SM-2 algorithm)
      int newInterval = word.currentInterval;
      double newEaseFactor = word.easeFactor;
      
      if (isCorrect) {
        newEaseFactor = (word.easeFactor + (0.1 - (5 - 3) * (0.08 + (5 - 3) * 0.02))).clamp(1.3, 2.5);
        newInterval = (word.currentInterval * newEaseFactor).round();
      } else {
        newEaseFactor = (word.easeFactor - 0.2).clamp(1.3, 2.5);
        newInterval = 1; // Reset interval if wrong
      }
      
      return await updateWordProgress(
        wordEn: wordEn,
        reviewCount: newReviewCount,
        correctAnswers: newCorrectAnswers,
        totalAttempts: newTotalAttempts,
        masteryLevel: newMasteryLevel,
        nextReview: DateTime.now().add(Duration(days: daysToAdd)),
        lastReviewed: DateTime.now(),
        currentInterval: newInterval,
        easeFactor: newEaseFactor,
      );
    } catch (e) {
      print('❌ Error updating word progress after answer: $e');
      return false;
    }
  }

  /// Get words that need review (nextReview <= today)
  Future<List<Word>> getWordsForReview({int limit = 50}) async {
    try {
      final db = await _initDatabase();
      final today = DateTime.now().toIso8601String();
      
      final results = await db.query(
        _tableName,
        where: 'nextReview IS NOT NULL AND nextReview <= ?',
        whereArgs: [today],
        orderBy: 'nextReview ASC, reviewCount ASC',
        limit: limit,
      );
      
      return results.map((map) => _mapToWord(map)).toList();
    } catch (e) {
      print('❌ Error getting words for review: $e');
      return [];
    }
  }

  /// Get words by mastery level
  Future<List<Word>> getWordsByMasteryLevel({
    double minMastery = 0.0,
    double maxMastery = 1.0,
    int limit = 100,
  }) async {
    try {
      final db = await _initDatabase();
      
      final results = await db.query(
        _tableName,
        where: 'masteryLevel >= ? AND masteryLevel <= ?',
        whereArgs: [minMastery, maxMastery],
        orderBy: 'masteryLevel DESC, reviewCount DESC',
        limit: limit,
      );
      
      return results.map((map) => _mapToWord(map)).toList();
    } catch (e) {
      print('❌ Error getting words by mastery level: $e');
      return [];
    }
  }

  /// Get statistics from database
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await _initDatabase();
      
      final stats = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalWords,
          SUM(reviewCount) as totalReviews,
          SUM(correctAnswers) as totalCorrect,
          SUM(totalAttempts) as totalAttempts,
          AVG(masteryLevel) as avgMastery,
          COUNT(CASE WHEN reviewCount >= 5 THEN 1 END) as masteredWords,
          COUNT(CASE WHEN reviewCount > 0 AND reviewCount < 5 THEN 1 END) as learningWords,
          COUNT(CASE WHEN reviewCount = 0 THEN 1 END) as newWords
        FROM $_tableName
      ''');
      
      if (stats.isEmpty) {
        return {
          'totalWords': 0,
          'totalReviews': 0,
          'totalCorrect': 0,
          'totalAttempts': 0,
          'avgMastery': 0.0,
          'masteredWords': 0,
          'learningWords': 0,
          'newWords': 0,
        };
      }
      
      final row = stats.first;
      return {
        'totalWords': row['totalWords'] as int? ?? 0,
        'totalReviews': row['totalReviews'] as int? ?? 0,
        'totalCorrect': row['totalCorrect'] as int? ?? 0,
        'totalAttempts': row['totalAttempts'] as int? ?? 0,
        'avgMastery': (row['avgMastery'] as num?)?.toDouble() ?? 0.0,
        'masteredWords': row['masteredWords'] as int? ?? 0,
        'learningWords': row['learningWords'] as int? ?? 0,
        'newWords': row['newWords'] as int? ?? 0,
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      return {
        'totalWords': 0,
        'totalReviews': 0,
        'totalCorrect': 0,
        'totalAttempts': 0,
        'avgMastery': 0.0,
        'masteredWords': 0,
        'learningWords': 0,
        'newWords': 0,
      };
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

