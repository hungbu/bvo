import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/word.dart';
import 'dictionary_words_repository.dart';
import '../service/word_progress_cache_service.dart';
import '../service/level_vocabulary_loader.dart';

/// Repository for managing user progress and learned words
/// Now syncs progress to database for single source of truth
class UserProgressRepository {
  static const String _progressPrefix = 'user_progress_';
  static const String _topicProgressPrefix = 'topic_progress_';
  static const String _wordProgressPrefix = 'word_progress_';
  
  final DictionaryWordsRepository _dbRepository = DictionaryWordsRepository();

  /// Get user progress for a specific topic (from JSON and SharedPreferences - NO DATABASE)
  /// First load: Only load from JSON files, no database queries
  Future<Map<String, dynamic>> getTopicProgress(String topic) async {
    try {
      // Load words from JSON (fast, no database)
      final levelLoader = LevelVocabularyLoader();
      final topicWords = await levelLoader.getWordsByLevel(topic);
      
      int totalWords = topicWords.length;
      
      // Get progress from SharedPreferences cache (fast)
      final cacheService = WordProgressCacheService();
      final topicProgressMap = await cacheService.getAllTopicProgress(topic);
      
      int learnedWords = 0;
      int totalCorrect = 0;
      int totalAttempts = 0;
      DateTime? lastStudied;
      double bestAccuracy = 0.0;
      
      // Calculate from cached progress in SharedPreferences
      for (final progressEntry in topicProgressMap.entries) {
        final progress = progressEntry.value;
        final reviewCount = (progress['reviewCount'] ?? 0) as int;
        final correctAnswers = (progress['correctAnswers'] ?? 0) as int;
        final attempts = (progress['totalAttempts'] ?? 0) as int;
        final masteryLevel = (progress['masteryLevel'] ?? 0.0).toDouble();
        final lastReviewedStr = progress['lastReviewed'];
        
        if (reviewCount >= 5) {
          learnedWords++;
        }
        totalCorrect += correctAnswers;
        totalAttempts += attempts;
        
        if (lastReviewedStr != null) {
          try {
            final lastReviewed = DateTime.parse(lastReviewedStr);
            if (lastStudied == null || lastReviewed.isAfter(lastStudied)) {
              lastStudied = lastReviewed;
            }
          } catch (_) {}
        }
        
        if (masteryLevel > bestAccuracy) {
          bestAccuracy = masteryLevel * 100;
        }
      }
      
      final avgAccuracy = totalAttempts > 0 ? (totalCorrect / totalAttempts) * 100 : 0.0;
      
      // Get sessions from SharedPreferences (if still needed)
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString('$_topicProgressPrefix$topic');
      int sessions = 0;
      if (progressJson != null) {
        try {
          final oldProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
          sessions = oldProgress['sessions'] ?? 0;
        } catch (_) {}
      }
      
      return {
        'topic': topic,
        'totalWords': totalWords,
        'learnedWords': learnedWords,
        'correctAnswers': totalCorrect,
        'totalAttempts': totalAttempts,
        'sessions': sessions,
        'lastStudied': lastStudied?.toIso8601String(),
        'bestAccuracy': bestAccuracy,
        'avgAccuracy': avgAccuracy,
        'totalStudyTime': 0,
      };
    } catch (e) {
      print('❌ Error calculating topic progress: $e');
      // Return default
      return {
        'topic': topic,
        'totalWords': 0,
        'learnedWords': 0,
        'correctAnswers': 0,
        'totalAttempts': 0,
        'sessions': 0,
        'lastStudied': null,
        'bestAccuracy': 0.0,
        'avgAccuracy': 0.0,
        'totalStudyTime': 0,
      };
    }
  }

  /// Save user progress for a specific topic (deprecated - now calculated from database)
  /// Kept for backward compatibility
  @Deprecated('Topic progress is now calculated from database')
  Future<void> saveTopicProgress(String topic, Map<String, dynamic> progress) async {
    // No-op: topic progress is now calculated from database
    // Keep for backward compatibility
  }

  /// Get progress for a specific word (from SharedPreferences only - fast)
  /// If word object is provided, use it and cache to SharedPreferences
  Future<Map<String, dynamic>> getWordProgress(String topic, String wordEn, {Word? word}) async {
    final cacheService = WordProgressCacheService();
    
    // Load from SharedPreferences only (fast)
    final cachedProgress = await cacheService.getWordProgress(topic, wordEn);
    if (cachedProgress != null) {
      return cachedProgress;
    }
    
    // If word object provided, use it and cache
    if (word != null) {
      final progress = {
        'word': wordEn,
        'topic': topic,
        'reviewCount': word.reviewCount,
        'correctAnswers': word.correctAnswers,
        'totalAttempts': word.totalAttempts,
        'lastReviewed': word.lastReviewed?.toIso8601String(),
        'nextReview': word.nextReview.toIso8601String(),
        'isLearned': word.reviewCount >= 5,
        'difficulty': word.difficulty,
        'masteryLevel': word.masteryLevel,
      };
      
      // Cache to SharedPreferences
      await cacheService.saveWordProgress(topic, wordEn, progress);
      return progress;
    }
    
    // Default empty progress
    return {
      'word': wordEn,
      'topic': topic,
      'reviewCount': 0,
      'correctAnswers': 0,
      'totalAttempts': 0,
      'lastReviewed': null,
      'nextReview': null,
      'isLearned': false,
      'difficulty': 1,
      'masteryLevel': 0.0,
    };
  }

  /// Save progress for a specific word
  /// Dual write: Save to SharedPreferences (sync) and database (async)
  Future<void> saveWordProgress(String topic, String wordEn, Map<String, dynamic> progress) async {
    try {
      final cacheService = WordProgressCacheService();
      
      // 1. Save to SharedPreferences immediately (cache)
      await cacheService.saveWordProgress(topic, wordEn, progress);
      
      // 2. Save to database asynchronously
      _dbRepository.updateWordProgress(
        wordEn: wordEn,
        reviewCount: progress['reviewCount'] as int?,
        correctAnswers: progress['correctAnswers'] as int?,
        totalAttempts: progress['totalAttempts'] as int?,
        masteryLevel: (progress['masteryLevel'] as num?)?.toDouble(),
        nextReview: progress['nextReview'] != null ? DateTime.parse(progress['nextReview'] as String) : null,
        lastReviewed: progress['lastReviewed'] != null ? DateTime.parse(progress['lastReviewed'] as String) : null,
        currentInterval: progress['currentInterval'] as int?,
        easeFactor: (progress['easeFactor'] as num?)?.toDouble(),
      ).catchError((e) {
        print('❌ Error updating word progress in database within saveWordProgress: $e');
        return false;
      });
      
      print('💾 Persisted progress for "$wordEn" to both cache and database');
    } catch (e) {
      print('❌ Error in saveWordProgress for "$wordEn": $e');
    }
  }

  /// Update word progress after correct answer
  /// Dual write: Save to SharedPreferences (sync) and database (async)
  Future<void> updateWordProgress(String topic, dWord word, bool isCorrect) async {
    final cacheService = WordProgressCacheService();
    
    // Get current progress
    final currentProgress = await getWordProgress(topic, word.en, word: word);
    final newReviewCount = (currentProgress['reviewCount'] as int) + 1;
    final newTotalAttempts = (currentProgress['totalAttempts'] as int) + 1;
    final newCorrectAnswers = isCorrect 
      ? (currentProgress['correctAnswers'] as int) + 1
      : (currentProgress['correctAnswers'] as int);
    
    final accuracy = newTotalAttempts > 0 ? (newCorrectAnswers / newTotalAttempts) : 0.0;
    
    // Calculate next review date
    int daysToAdd = 1;
    if (accuracy >= 0.8) {
      daysToAdd = [1, 3, 7, 14, 30][newReviewCount.clamp(0, 4)];
    } else if (accuracy >= 0.6) {
      daysToAdd = [1, 2, 4, 7, 14][newReviewCount.clamp(0, 4)];
    }
    
    final newProgress = {
      'word': word.en,
      'topic': topic,
      'reviewCount': newReviewCount,
      'correctAnswers': newCorrectAnswers,
      'totalAttempts': newTotalAttempts,
      'lastReviewed': DateTime.now().toIso8601String(),
      'nextReview': DateTime.now().add(Duration(days: daysToAdd)).toIso8601String(),
      'isLearned': newReviewCount >= 5,
      'difficulty': accuracy >= 0.8 ? 1 : accuracy >= 0.6 ? 2 : 3,
      'masteryLevel': accuracy,
    };
    
    // PHASE 1: Save to SharedPreferences immediately (sync - fast)
    await cacheService.saveWordProgress(topic, word.en, newProgress);
    
    // PHASE 2: Save to database asynchronously (async - non-blocking)
    _dbRepository.updateWordProgress(
      wordEn: word.en,
      reviewCount: newReviewCount,
      correctAnswers: newCorrectAnswers,
      totalAttempts: newTotalAttempts,
      lastReviewed: DateTime.now(),
      nextReview: DateTime.now().add(Duration(days: daysToAdd)),
      masteryLevel: accuracy,
    ).catchError((e) {
      print('❌ Error updating word progress in database: $e');
      // SharedPreferences already saved, so app can continue
      return false;
    });
    
    // Update last_topic in SharedPreferences
    await _updateLastTopic(topic);
    
    // Update daily streak (but NOT word count to avoid double counting)
    await _updateStreak();
  }


  /// Get all topics with their progress (from database) - BATCH VERSION
  /// Optimized: Load progress for all 6 topics in 1-2 queries instead of 6 separate queries
  Future<Map<String, Map<String, dynamic>>> getAllTopicsProgress() async {
    return await getAllTopicsProgressBatch();
  }

  /// Batch load progress for all topics from JSON and SharedPreferences (NO DATABASE)
  /// First load: Only load from JSON files, no database queries
  Future<Map<String, Map<String, dynamic>>> getAllTopicsProgressBatch() async {
    try {
      const targetTopics = ['1.1', '1.2', '1.3', '1.4', '1.5', '2.0'];
      final topicsProgress = <String, Map<String, dynamic>>{};
      final cacheService = WordProgressCacheService();
      final levelLoader = LevelVocabularyLoader();
      
      // Load words from JSON files (fast, no database)
      final wordsByTopic = <String, List<Word>>{};
      for (final topic in targetTopics) {
        final words = await levelLoader.getWordsByLevel(topic);
        wordsByTopic[topic] = words;
      }
      
      // Calculate progress for each topic from JSON + SharedPreferences
      for (final topic in targetTopics) {
        final topicWords = wordsByTopic[topic] ?? [];
        int totalWords = topicWords.length;
        
        // Get progress from SharedPreferences cache (fast)
        final topicProgressMap = await cacheService.getAllTopicProgress(topic);
        
        int learnedWords = 0;
        int totalCorrect = 0;
        int totalAttempts = 0;
        DateTime? lastStudied;
        double bestAccuracy = 0.0;
        
        // Calculate from cached progress in SharedPreferences
        for (final progressEntry in topicProgressMap.entries) {
          final progress = progressEntry.value;
          final reviewCount = (progress['reviewCount'] ?? 0) as int;
          final correctAnswers = (progress['correctAnswers'] ?? 0) as int;
          final attempts = (progress['totalAttempts'] ?? 0) as int;
          final masteryLevel = (progress['masteryLevel'] ?? 0.0).toDouble();
          final lastReviewedStr = progress['lastReviewed'];
          
          if (reviewCount >= 5) {
            learnedWords++;
          }
          totalCorrect += correctAnswers;
          totalAttempts += attempts;
          
          if (lastReviewedStr != null) {
            try {
              final lastReviewed = DateTime.parse(lastReviewedStr);
              if (lastStudied == null || lastReviewed.isAfter(lastStudied)) {
                lastStudied = lastReviewed;
              }
            } catch (_) {}
          }
          
          if (masteryLevel > bestAccuracy) {
            bestAccuracy = masteryLevel * 100;
          }
        }
        
        final avgAccuracy = totalAttempts > 0 ? (totalCorrect / totalAttempts) * 100 : 0.0;
        
        // Get sessions from SharedPreferences (if still needed)
        final prefs = await SharedPreferences.getInstance();
        final progressJson = prefs.getString('$_topicProgressPrefix$topic');
        int sessions = 0;
        if (progressJson != null) {
          try {
            final oldProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
            sessions = oldProgress['sessions'] ?? 0;
          } catch (_) {}
        }
        
        topicsProgress[topic] = {
          'topic': topic,
          'totalWords': totalWords,
          'learnedWords': learnedWords,
          'correctAnswers': totalCorrect,
          'totalAttempts': totalAttempts,
          'sessions': sessions,
          'lastStudied': lastStudied?.toIso8601String(),
          'bestAccuracy': bestAccuracy,
          'avgAccuracy': avgAccuracy,
          'totalStudyTime': 0,
        };
      }
      
      return topicsProgress;
    } catch (e) {
      print('❌ Error getting all topics progress batch: $e');
      return {};
    }
  }

  /// Get words that need review today
  /// Load from JSON and SharedPreferences ONLY (NO DATABASE on first load)
  /// Database is only used for additional words not in JSON (after user has progress)
  Future<List<Map<String, dynamic>>> getWordsForReview() async {
    final levelLoader = LevelVocabularyLoader();
    
    // Get all words from JSON (all topics)
    final allTopics = ['1.1', '1.2', '1.3', '1.4', '1.5', '2.0'];
    final jsonWords = <String, Word>{}; // Map of word.en -> Word from JSON
    
    for (final topic in allTopics) {
      final words = await levelLoader.getWordsByLevel(topic);
      for (final word in words) {
        jsonWords[word.en.toLowerCase()] = word;
      }
    }
    
    // Get words for review from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final prefix = 'word_progress_';
    final wordKeys = allKeys.where((key) => 
      key.startsWith(prefix)
    ).toList();
    
    // If no progress keys found (first load), return empty list (no database query)
    if (wordKeys.isEmpty) {
      return [];
    }
    
    final wordsForReview = <Map<String, dynamic>>[];
    final today = DateTime.now();
    
    for (final key in wordKeys) {
      final progressJson = prefs.getString(key);
      if (progressJson != null) {
        try {
          final wordProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
          final nextReviewStr = wordProgress['nextReview'];
          
          if (nextReviewStr != null) {
            final nextReview = DateTime.parse(nextReviewStr);
            if (nextReview.isBefore(today) || nextReview.isAtSameMomentAs(today)) {
              final wordEn = wordProgress['word'] as String? ?? '';
              final wordEnLower = wordEn.toLowerCase();
              
              // If word is in JSON, use JSON data (no database query)
              if (jsonWords.containsKey(wordEnLower)) {
                final jsonWord = jsonWords[wordEnLower]!;
                wordProgress.addAll({
                  'pronunciation': jsonWord.pronunciation,
                  'sentence': jsonWord.sentence,
                  'sentenceVi': jsonWord.sentenceVi,
                  'level': jsonWord.level.toString().split('.').last,
                  'type': jsonWord.type.toString().split('.').last,
                  'difficulty': jsonWord.difficulty,
                  'tags': jsonWord.tags,
                  'synonyms': jsonWord.synonyms,
                  'antonyms': jsonWord.antonyms,
                });
                wordsForReview.add(wordProgress);
              }
              // Skip words not in JSON (don't query database on first load)
              // Database queries should only happen for search functionality
              else {
                print('⚠️ Skipping word $wordEn - not found in JSON (no database query on first load)');
              }
            }
          }
        } catch (e) {
          print('⚠️ Error parsing word progress for key $key: $e');
        }
      }
    }
    
    return wordsForReview;
  }

  /// Get overall user statistics
  Future<Map<String, dynamic>> getUserStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final allTopicsProgress = await getAllTopicsProgress();
    
    int totalWords = 0;
    int totalLearnedWords = 0;
    int totalCorrectAnswers = 0;
    int totalAttempts = 0;
    int totalSessions = 0;
    double totalAccuracy = 0.0;
    int activeTopics = 0;
    
    for (final topicProgress in allTopicsProgress.values) {
      totalWords += (topicProgress['totalWords'] ?? 0) as int;
      totalLearnedWords += (topicProgress['learnedWords'] ?? 0) as int;
      totalCorrectAnswers += (topicProgress['correctAnswers'] ?? 0) as int;
      totalAttempts += (topicProgress['totalAttempts'] ?? 0) as int;
      totalSessions += (topicProgress['sessions'] ?? 0) as int;
      
      if ((topicProgress['sessions'] ?? 0) > 0) {
        activeTopics++;
        totalAccuracy += (topicProgress['avgAccuracy'] ?? 0.0) as double;
      }
    }
    
    final avgAccuracy = activeTopics > 0 ? totalAccuracy / activeTopics : 0.0;
    
    // Get additional stats from SharedPreferences
    final streakDays = prefs.getInt('streak_days') ?? 0;
    final longestStreak = prefs.getInt('longest_streak') ?? 0;
    final totalStudyTime = prefs.getInt('total_study_time_seconds') ?? 0;
    
    return {
      'totalWords': totalWords,
      'totalLearnedWords': totalLearnedWords,
      'totalCorrectAnswers': totalCorrectAnswers,
      'totalAttempts': totalAttempts,
      'totalSessions': totalSessions,
      'avgAccuracy': avgAccuracy,
      'activeTopics': activeTopics,
      'streakDays': streakDays,
      'longestStreak': longestStreak,
      'totalStudyTimeSeconds': totalStudyTime,
    };
  }

  /// Clear all progress data (for reset functionality)
  Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    final keysToRemove = allKeys.where((key) => 
      key.startsWith(_progressPrefix) ||
      key.startsWith(_topicProgressPrefix) ||
      key.startsWith(_wordProgressPrefix)
    ).toList();
    
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// Get words with progress for a specific topic
  Future<List<Map<String, dynamic>>> getTopicWordsWithProgress(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final topicWordKeys = allKeys.where((key) => 
      key.startsWith('$_wordProgressPrefix${topic}_')
    ).toList();
    
    final wordsWithProgress = <Map<String, dynamic>>[];
    
    for (final key in topicWordKeys) {
      final progressJson = prefs.getString(key);
      if (progressJson != null) {
        final wordProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
        wordsWithProgress.add(wordProgress);
      }
    }
    
    return wordsWithProgress;
  }

  /// Update last studied topic
  Future<void> _updateLastTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_topic', topic);
    print('📍 Updated last_topic to: $topic');
  }

  /// Get last studied topic
  Future<String?> getLastTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_topic');
  }

  /// Set last studied topic (public method)
  Future<void> setLastTopic(String topic) async {
    await _updateLastTopic(topic);
  }


  /// Centralized method to update today's words learned count
  Future<void> updateTodayWordsLearned(int wordsCount) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    // Update today's words learned count
    final currentTodayWords = prefs.getInt('words_learned_$todayKey') ?? 0;
    await prefs.setInt('words_learned_$todayKey', currentTodayWords + wordsCount);
    
    print('📊 Updated today words: $currentTodayWords + $wordsCount = ${currentTodayWords + wordsCount}');
  }

  /// Update streak based on learning activity
  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final yesterdayKey = '${today.subtract(const Duration(days: 1)).year}-${today.subtract(const Duration(days: 1)).month}-${today.subtract(const Duration(days: 1)).day}';
    
    // Get current streak data
    int currentStreak = prefs.getInt('streak_days') ?? 0;
    int longestStreak = prefs.getInt('longest_streak') ?? 0;
    String? lastStreakDate = prefs.getString('last_streak_date');
    
    // Check if user studied today
    final todayWords = prefs.getInt('words_learned_$todayKey') ?? 0;
    
    if (todayWords > 0) {
      // User studied today
      if (lastStreakDate == null || lastStreakDate != todayKey) {
        // First time studying today
        if (lastStreakDate == yesterdayKey) {
          // Continuing streak from yesterday
          currentStreak += 1;
        } else {
          // Starting new streak
          currentStreak = 1;
        }
        
        // Update longest streak if needed
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
        
        // Save updated values
        await prefs.setInt('streak_days', currentStreak);
        await prefs.setInt('longest_streak', longestStreak);
        await prefs.setString('last_streak_date', todayKey);
      }
    }
  }

  /// Get today's words learned count
  Future<int> getTodayWordsLearned() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final count = prefs.getInt('words_learned_$todayKey') ?? 0;
    print('📊 Today words learned ($todayKey): $count');
    return count;
  }

  /// Debug method to check word counting sources
  Future<Map<String, dynamic>> debugTodayWordCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    final debug = <String, dynamic>{
      'todayKey': todayKey,
      'words_learned_direct': prefs.getInt('words_learned_$todayKey') ?? 0,
      'learned_today_flag': prefs.getBool('learned_$todayKey') ?? false,
      'total_words_learned': prefs.getInt('total_words_learned') ?? 0,
      'streak_days': prefs.getInt('streak_days') ?? 0,
      'last_streak_date': prefs.getString('last_streak_date') ?? 'none',
    };
    
    print('🔍 Debug today word count: $debug');
    return debug;
  }

  /// Update topic progress for batch learning (e.g., flashcard sessions)
  Future<void> updateTopicProgressBatch(String topic, int wordsLearned) async {
    // Topic progress is now calculated from database
    // No need to update separately - getTopicProgress() will calculate from database
    
    // Update last topic
    await _updateLastTopic(topic);
    
    print('📚 Topic $topic: batch session completed (progress calculated from database)');
  }

  /// Migrate progress data from SharedPreferences to database (one-time migration)
  /// This ensures all progress data is in the database as single source of truth
  Future<void> migrateProgressToDatabase() async {
    try {
      print('🔄 Starting migration of progress data from SharedPreferences to database...');
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final wordKeys = allKeys.where((key) => 
        key.startsWith(_wordProgressPrefix)
      ).toList();
      
      int migratedCount = 0;
      int skippedCount = 0;
      
      for (final key in wordKeys) {
        try {
          final progressJson = prefs.getString(key);
          if (progressJson != null) {
            final progress = Map<String, dynamic>.from(jsonDecode(progressJson));
            final wordEn = key.replaceFirst(_wordProgressPrefix, '').split('_').skip(1).join('_');
            
            // Extract progress data
            final reviewCount = (progress['reviewCount'] ?? 0) as int;
            final correctAnswers = (progress['correctAnswers'] ?? 0) as int;
            final totalAttempts = (progress['totalAttempts'] ?? 0) as int;
            final masteryLevel = totalAttempts > 0 
                ? (correctAnswers / totalAttempts).clamp(0.0, 1.0)
                : 0.0;
            
            DateTime? nextReview;
            DateTime? lastReviewed;
            try {
              if (progress['nextReview'] != null) {
                nextReview = DateTime.parse(progress['nextReview'] as String);
              }
              if (progress['lastReviewed'] != null) {
                lastReviewed = DateTime.parse(progress['lastReviewed'] as String);
              }
            } catch (e) {
              print('⚠️ Error parsing dates for $wordEn: $e');
            }
            
            // Update database
            final success = await _dbRepository.updateWordProgress(
              wordEn: wordEn,
              reviewCount: reviewCount > 0 ? reviewCount : null,
              correctAnswers: correctAnswers > 0 ? correctAnswers : null,
              totalAttempts: totalAttempts > 0 ? totalAttempts : null,
              masteryLevel: masteryLevel > 0 ? masteryLevel : null,
              nextReview: nextReview,
              lastReviewed: lastReviewed,
            );
            
            if (success) {
              migratedCount++;
            } else {
              skippedCount++;
            }
          }
        } catch (e) {
          print('⚠️ Error migrating progress for key $key: $e');
          skippedCount++;
        }
      }
      
      print('✅ Migration completed: $migratedCount migrated, $skippedCount skipped');
    } catch (e) {
      print('❌ Error during migration: $e');
    }
  }
}
