import 'dart:convert';
import 'package:flutter/services.dart';
import '../model/word.dart';
import '../repository/dictionary_words_repository.dart';
import '../service/performance_monitor.dart';
import '../service/word_progress_cache_service.dart';

/// Service to load vocabulary data from level txt files and map with database
/// Levels: 1.1, 1.2, 1.3, 1.4, 1.5, 2.0
class LevelVocabularyLoader {
  static final LevelVocabularyLoader _instance = LevelVocabularyLoader._internal();
  factory LevelVocabularyLoader() => _instance;
  LevelVocabularyLoader._internal();

  final DictionaryWordsRepository _dbRepository = DictionaryWordsRepository();

  // Cache for loaded data
  Map<String, List<Word>>? _levelWordsCache;
  List<Word>? _allWordsCache;

  /// Level file mapping
  static const Map<String, String> _levelFiles = {
    '1.1': 'assets/data/1000/1.1.txt',
    '1.2': 'assets/data/1000/1.2.txt',
    '1.3': 'assets/data/1000/1.3.txt',
    '1.4': 'assets/data/1000/1.4.txt',
    '1.5': 'assets/data/1000/1.5.txt',
    '2.0': 'assets/data/1000/2.0.txt',
  };

  /// JSON file mapping for topics
  static const Map<String, String> _levelJsonFiles = {
    '1.1': 'assets/data/1000/1.1.json',
    '1.2': 'assets/data/1000/1.2.json',
    '1.3': 'assets/data/1000/1.3.json',
    '1.4': 'assets/data/1000/1.4.json',
    '1.5': 'assets/data/1000/1.5.json',
    '2.0': 'assets/data/1000/2.0.json',
  };

  /// Get all words from all levels
  Future<List<Word>> getAllWords() async {
    final stopwatch = Stopwatch()..start();
    PerformanceMonitor.trackMemoryUsage('LevelVocabularyLoader.getAllWords.start');
    
    if (_allWordsCache != null) {
      print('LevelVocabularyLoader.getAllWords: returning cached list of ${_allWordsCache!.length} words');
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getAllWords', stopwatch.elapsed, metadata: {
        'cached': true,
        'wordCount': _allWordsCache!.length,
      });
      return _allWordsCache!;
    }

    print('LevelVocabularyLoader.getAllWords: loading from level txt files...');
    final allWords = <Word>[];

    final levelLoadStopwatch = Stopwatch()..start();
    for (final entry in _levelFiles.entries) {
      final level = entry.key;
      final words = await getWordsByLevel(level);
      allWords.addAll(words);
    }
    levelLoadStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getAllWords.levelLoop', levelLoadStopwatch.elapsed, metadata: {
      'levelCount': _levelFiles.length,
      'totalWords': allWords.length,
    });

    // Sort by level order, then by word order in file
    allWords.sort((a, b) {
      final levelA = _getLevelOrder(a.topic);
      final levelB = _getLevelOrder(b.topic);
      if (levelA != levelB) {
        return levelA.compareTo(levelB);
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });

    print('LevelVocabularyLoader.getAllWords: loaded total ${allWords.length} words');
    _allWordsCache = allWords;
    
    stopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getAllWords', stopwatch.elapsed, metadata: {
      'cached': false,
      'wordCount': allWords.length,
      'levelCount': _levelFiles.length,
    });
    PerformanceMonitor.trackMemoryUsage('LevelVocabularyLoader.getAllWords.end');
    
    return _allWordsCache!;
  }

  /// Get words by level (1.1, 1.2, 1.3, 1.4, 1.5, 2.0)
  /// Now loads from JSON files first (fast), then syncs learning progress from database
  Future<List<Word>> getWordsByLevel(String level) async {
    final stopwatch = Stopwatch()..start();
    
    if (_levelWordsCache != null && _levelWordsCache!.containsKey(level)) {
      print('LevelVocabularyLoader.getWordsByLevel($level): returning cached list of ${_levelWordsCache![level]!.length} words');
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getWordsByLevel', stopwatch.elapsed, metadata: {
        'level': level,
        'cached': true,
        'wordCount': _levelWordsCache![level]!.length,
      });
      return _levelWordsCache![level]!;
    }

    print('LevelVocabularyLoader.getWordsByLevel($level): loading from JSON file');
    
    try {
      // Try loading from JSON file first (fast)
      final jsonStopwatch = Stopwatch()..start();
      final words = await _loadWordsFromJson(level);
      jsonStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getWordsByLevel.jsonLoad', jsonStopwatch.elapsed, metadata: {
        'level': level,
        'wordCount': words.length,
        'source': 'json',
      });
      
      // If no words found in JSON, fallback to database
      if (words.isEmpty) {
        print('⚠️ No words found in JSON for level $level, trying database fallback...');
        final dbResult = await _loadWordsFromDatabase(level);
        stopwatch.stop();
        PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getWordsByLevel', stopwatch.elapsed, metadata: {
          'level': level,
          'cached': false,
          'source': 'database_fallback',
          'wordCount': dbResult.length,
        });
        return dbResult;
      }

      // Initialize cache if needed
      _levelWordsCache ??= {};
      _levelWordsCache![level] = words;

      print('LevelVocabularyLoader.getWordsByLevel($level): loaded ${words.length} words from JSON');
      
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getWordsByLevel', stopwatch.elapsed, metadata: {
        'level': level,
        'cached': false,
        'source': 'json',
        'wordCount': words.length,
      });
      
      // Learning progress is injected from SharedPreferences in _loadWordsFromJson()
      return words;
    } catch (e) {
      print('LevelVocabularyLoader.getWordsByLevel($level): error loading from JSON: $e');
      // Fallback to database loading
      final dbResult = await _loadWordsFromDatabase(level);
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getWordsByLevel', stopwatch.elapsed, metadata: {
        'level': level,
        'error': e.toString(),
        'source': 'database_fallback_error',
        'wordCount': dbResult.length,
      });
      return dbResult;
    }
  }

  /// Load words from JSON file
  Future<List<Word>> _loadWordsFromJson(String level) async {
    final jsonPath = _levelJsonFiles[level];
    if (jsonPath == null) {
      print('LevelVocabularyLoader._loadWordsFromJson($level): JSON file path not found');
      return [];
    }

    try {
      // Load words from JSON
      final String jsonString = await rootBundle.loadString(jsonPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      
      final words = jsonList.map((json) {
        try {
          return Word.fromJson(json as Map<String, dynamic>);
        } catch (e) {
          print('⚠️ Error parsing word from JSON: $e');
          return null;
        }
      }).whereType<Word>().toList();
      
      // Inject cached progress from SharedPreferences
      final cacheService = WordProgressCacheService();
      final wordEnList = words.map((w) => w.en).toList();
      final progressMap = await cacheService.getBatchWordProgress(level, wordEnList);
      
      // Update words with cached progress
      final updatedWords = words.map((word) {
        final progress = progressMap[word.en];
        if (progress != null) {
          return word.copyWith(
            reviewCount: progress['reviewCount'] ?? word.reviewCount,
            correctAnswers: progress['correctAnswers'] ?? word.correctAnswers,
            totalAttempts: progress['totalAttempts'] ?? word.totalAttempts,
            lastReviewed: progress['lastReviewed'] != null 
              ? DateTime.parse(progress['lastReviewed']) 
              : word.lastReviewed,
            nextReview: progress['nextReview'] != null
              ? DateTime.parse(progress['nextReview'])
              : word.nextReview,
            masteryLevel: (progress['masteryLevel'] ?? word.masteryLevel).toDouble(),
          );
        }
        return word;
      }).toList();
      
      print('LevelVocabularyLoader._loadWordsFromJson($level): loaded ${updatedWords.length} words from JSON with cached progress');
      return updatedWords;
    } catch (e) {
      print('LevelVocabularyLoader._loadWordsFromJson($level): error loading JSON: $e');
      return [];
    }
  }

  /// Load words from database (fallback)
  Future<List<Word>> _loadWordsFromDatabase(String level) async {
    try {
      final words = await _dbRepository.getWordsByTopic(level);
      print('LevelVocabularyLoader._loadWordsFromDatabase($level): loaded ${words.length} words from database');
      return words;
    } catch (e) {
      print('LevelVocabularyLoader._loadWordsFromDatabase($level): error: $e');
      return [];
    }
  }

  /// Fallback: Load words from file (for backward compatibility)
  Future<List<Word>> _loadWordsFromFile(String level) async {
    final stopwatch = Stopwatch()..start();
    final filePath = _levelFiles[level];
    if (filePath == null) {
      print('LevelVocabularyLoader.getWordsByLevel($level): level not found');
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader._loadWordsFromFile', stopwatch.elapsed, metadata: {
        'level': level,
        'error': 'level_not_found',
      });
      return [];
    }

    print('LevelVocabularyLoader: loading from file $filePath (fallback)');
    
    try {
      // Load word list from txt file
      final fileLoadStopwatch = Stopwatch()..start();
      final String content = await rootBundle.loadString(filePath);
      final wordStrings = content.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      fileLoadStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader._loadWordsFromFile.fileLoad', fileLoadStopwatch.elapsed, metadata: {
        'level': level,
        'filePath': filePath,
        'wordStringCount': wordStrings.length,
      });
      
      print('LevelVocabularyLoader: found ${wordStrings.length} words in file');

      // OPTIMIZED: Batch query all words at once instead of individual queries
      final wordMappingStopwatch = Stopwatch()..start();
      final wordsMap = await _dbRepository.getWordsBatch(wordStrings);
      wordMappingStopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader._loadWordsFromFile.batchQuery', wordMappingStopwatch.elapsed, metadata: {
        'level': level,
        'wordStringCount': wordStrings.length,
        'foundCount': wordsMap.length,
      });
      
      print('✅ Batch query found ${wordsMap.length}/${wordStrings.length} words from database');

      // Map words to Word objects with level/topic
      final words = <Word>[];
      for (final wordString in wordStrings) {
        final word = wordsMap[wordString];
        if (word != null) {
          // Update level/topic to match the level file
          final wordWithLevel = word.copyWith(
            topic: level, // Use level as topic for organization
          );
          words.add(wordWithLevel);
        } else {
          print('LevelVocabularyLoader: Word "$wordString" not found in database');
          // Create a basic word object if not found in database
          words.add(Word(
            en: wordString,
            vi: '',
            sentence: '',
            sentenceVi: '',
            topic: level,
            pronunciation: '',
            level: _mapLevelToWordLevel(level),
            type: WordType.noun,
            difficulty: _getDifficultyFromLevel(level),
            nextReview: DateTime.now().add(const Duration(days: 1)),
          ));
        }
      }

      // Initialize cache if needed
      _levelWordsCache ??= {};
      _levelWordsCache![level] = words;

      print('LevelVocabularyLoader.getWordsByLevel($level): loaded ${words.length} words from file');
      
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader._loadWordsFromFile', stopwatch.elapsed, metadata: {
        'level': level,
        'filePath': filePath,
        'wordStringCount': wordStrings.length,
        'foundCount': wordsMap.length,
        'wordCount': words.length,
      });
      
      return words;
    } catch (e) {
      stopwatch.stop();
      PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader._loadWordsFromFile', stopwatch.elapsed, metadata: {
        'level': level,
        'error': e.toString(),
      });
      print('LevelVocabularyLoader.getWordsByLevel($level): error loading file: $e');
      return [];
    }
  }

  /// Get basic level words (levels 1.1-1.5)
  Future<List<Word>> getBasicWords() async {
    final stopwatch = Stopwatch()..start();
    final allBasic = <Word>[];
    final levels = ['1.1', '1.2', '1.3', '1.4', '1.5'];
    for (final level in levels) {
      final words = await getWordsByLevel(level);
      allBasic.addAll(words);
    }
    stopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getBasicWords', stopwatch.elapsed, metadata: {
      'levelCount': levels.length,
      'wordCount': allBasic.length,
    });
    return allBasic;
  }

  /// Get intermediate level words (level 2.0)
  Future<List<Word>> getIntermediateWords() async {
    final stopwatch = Stopwatch()..start();
    final words = await getWordsByLevel('2.0');
    stopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getIntermediateWords', stopwatch.elapsed, metadata: {
      'wordCount': words.length,
    });
    return words;
  }

  /// Get advanced level words (empty for now, can be extended)
  Future<List<Word>> getAdvancedWords() async {
    final stopwatch = Stopwatch()..start();
    stopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('LevelVocabularyLoader.getAdvancedWords', stopwatch.elapsed, metadata: {
      'wordCount': 0,
    });
    return [];
  }

  /// Get words by WordLevel enum
  Future<List<Word>> getWordsByWordLevel(WordLevel level) async {
    switch (level) {
      case WordLevel.BASIC:
        return await getBasicWords();
      case WordLevel.INTERMEDIATE:
        return await getIntermediateWords();
      case WordLevel.ADVANCED:
        return await getAdvancedWords();
    }
  }

  /// Get words by topic (topic is the level string like "1.1", "1.2", etc.)
  Future<List<Word>> getWordsByTopic(String topic) async {
    if (_levelFiles.containsKey(topic)) {
      return await getWordsByLevel(topic);
    }
    return [];
  }

  /// Get all available topics (levels)
  Future<List<String>> getAllTopics() async {
    return _levelFiles.keys.toList()..sort();
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final basic = await getBasicWords();
    final intermediate = await getIntermediateWords();
    final advanced = await getAdvancedWords();
    
    return {
      'total': basic.length + intermediate.length + advanced.length,
      'basic': basic.length,
      'intermediate': intermediate.length,
      'advanced': advanced.length,
      'topics': (await getAllTopics()).length,
    };
  }


  /// Clear cache
  void clearCache() {
    _levelWordsCache = null;
    _allWordsCache = null;
    print('LevelVocabularyLoader: caches cleared');
  }

  /// Map level string to WordLevel enum
  WordLevel _mapLevelToWordLevel(String level) {
    if (level.startsWith('1.')) {
      return WordLevel.BASIC;
    } else if (level.startsWith('2.')) {
      return WordLevel.INTERMEDIATE;
    }
    return WordLevel.BASIC;
  }

  /// Get difficulty from level
  int _getDifficultyFromLevel(String level) {
    if (level == '1.1') return 1;
    if (level == '1.2') return 1;
    if (level == '1.3') return 2;
    if (level == '1.4') return 2;
    if (level == '1.5') return 3;
    if (level == '2.0') return 3;
    return 2;
  }

  /// Get level order for sorting
  int _getLevelOrder(String level) {
    final order = ['1.1', '1.2', '1.3', '1.4', '1.5', '2.0'];
    return order.indexOf(level);
  }

  /// Get level display name
  static String getLevelDisplayName(String level) {
    return 'Level $level';
  }
}

