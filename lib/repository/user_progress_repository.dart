import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/word.dart';
import 'dictionary_words_repository.dart';

/// Repository for managing user progress and learned words
/// Now syncs progress to database for single source of truth
class UserProgressRepository {
  static const String _progressPrefix = 'user_progress_';
  static const String _topicProgressPrefix = 'topic_progress_';
  static const String _wordProgressPrefix = 'word_progress_';
  
  final DictionaryWordsRepository _dbRepository = DictionaryWordsRepository();

  /// Get user progress for a specific topic (calculated from database)
  Future<Map<String, dynamic>> getTopicProgress(String topic) async {
    try {
      // Calculate from database (single source of truth)
      final topicWords = await _dbRepository.getWordsByTopic(topic);
      
      int totalWords = topicWords.length;
      int learnedWords = 0; // reviewCount >= 5
      int totalCorrect = 0;
      int totalAttempts = 0;
      DateTime? lastStudied;
      double bestAccuracy = 0.0;
      
      for (final word in topicWords) {
        if (word.reviewCount >= 5) {
          learnedWords++;
        }
        totalCorrect += word.correctAnswers;
        totalAttempts += word.totalAttempts;
        
        // Track last studied date
        if (word.lastReviewed != null) {
          if (lastStudied == null || word.lastReviewed!.isAfter(lastStudied)) {
            lastStudied = word.lastReviewed;
          }
        }
        
        // Calculate best accuracy from word mastery
        if (word.masteryLevel > bestAccuracy) {
          bestAccuracy = word.masteryLevel * 100;
        }
      }
      
      final avgAccuracy = totalAttempts > 0 ? (totalCorrect / totalAttempts) * 100 : 0.0;
      
      return {
        'topic': topic,
        'totalWords': totalWords,
        'learnedWords': learnedWords,
        'correctAnswers': totalCorrect,
        'totalAttempts': totalAttempts,
        'sessions': 0, // Can be calculated separately if needed
        'lastStudied': lastStudied?.toIso8601String(),
        'bestAccuracy': bestAccuracy,
        'avgAccuracy': avgAccuracy,
        'totalStudyTime': 0, // Can be tracked separately if needed
      };
    } catch (e) {
      print('❌ Error calculating topic progress from database: $e');
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

  /// Get progress for a specific word (from database or Word object)
  /// If word object is provided, use it directly to avoid database query
  Future<Map<String, dynamic>> getWordProgress(String topic, String wordEn, {Word? word}) async {
    // OPTIMIZED: If word object provided, use it directly (no database query needed)
    if (word != null) {
      return {
        'word': wordEn,
        'topic': topic,
        'reviewCount': word.reviewCount,
        'correctAnswers': word.correctAnswers,
        'totalAttempts': word.totalAttempts,
        'lastReviewed': word.lastReviewed?.toIso8601String(),
        'nextReview': word.nextReview.toIso8601String(),
        'isLearned': word.reviewCount >= 5, // Consider learned if reviewed 5+ times
        'difficulty': word.difficulty,
        'masteryLevel': word.masteryLevel,
      };
    }
    
    // Try to get from database first (single source of truth)
    try {
      final dbWord = await _dbRepository.getWord(wordEn);
      if (dbWord != null) {
        return {
          'word': wordEn,
          'topic': topic,
          'reviewCount': dbWord.reviewCount,
          'correctAnswers': dbWord.correctAnswers,
          'totalAttempts': dbWord.totalAttempts,
          'lastReviewed': dbWord.lastReviewed?.toIso8601String(),
          'nextReview': dbWord.nextReview.toIso8601String(),
          'isLearned': dbWord.reviewCount >= 5, // Consider learned if reviewed 5+ times
          'difficulty': dbWord.difficulty,
          'masteryLevel': dbWord.masteryLevel,
        };
      }
    } catch (e) {
      print('⚠️ Error getting word progress from database: $e');
    }
    
    // Fallback to SharedPreferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    final wordKey = '${topic}_$wordEn';
    final progressJson = prefs.getString('$_wordProgressPrefix$wordKey');
    
    if (progressJson != null) {
      return Map<String, dynamic>.from(jsonDecode(progressJson));
    }
    
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
    };
  }

  /// Save progress for a specific word (deprecated - now in database)
  /// Kept for backward compatibility
  @Deprecated('Word progress is now stored in database')
  Future<void> saveWordProgress(String topic, String wordEn, Map<String, dynamic> progress) async {
    // No-op: word progress is now stored in database
    // Keep for backward compatibility
  }

  /// Update word progress after correct answer (syncs to database)
  Future<void> updateWordProgress(String topic, dWord word, bool isCorrect) async {
    // Update in database (primary source of truth)
    try {
      final success = await _dbRepository.updateWordProgressAfterAnswer(
        wordEn: word.en,
        isCorrect: isCorrect,
      );
      
      if (success) {
        print('✅ Updated word progress in database: ${word.en}');
      } else {
        print('⚠️ Failed to update word progress in database: ${word.en}');
      }
    } catch (e) {
      print('❌ Error updating word progress in database: $e');
    }
    
    // Also keep SharedPreferences for backward compatibility and quick access
    final progress = await getWordProgress(topic, word.en);
    
    progress['reviewCount'] = (progress['reviewCount'] ?? 0) + 1;
    progress['totalAttempts'] = (progress['totalAttempts'] ?? 0) + 1;
    
    if (isCorrect) {
      progress['correctAnswers'] = (progress['correctAnswers'] ?? 0) + 1;
    }
    
    progress['lastReviewed'] = DateTime.now().toIso8601String();
    
    // Calculate next review date based on performance
    final reviewCount = progress['reviewCount'] as int;
    final correctAnswers = progress['correctAnswers'] as int;
    final accuracy = correctAnswers / (progress['totalAttempts'] as int);
    
    // Spaced repetition: more correct answers = longer intervals
    int daysToAdd = 1;
    if (accuracy >= 0.8) {
      daysToAdd = [1, 3, 7, 14, 30][reviewCount.clamp(0, 4)];
    } else if (accuracy >= 0.6) {
      daysToAdd = [1, 2, 4, 7, 14][reviewCount.clamp(0, 4)];
    } else {
      daysToAdd = 1; // Review again tomorrow
    }
    
    progress['nextReview'] = DateTime.now().add(Duration(days: daysToAdd)).toIso8601String();
    progress['isLearned'] = accuracy >= 0.7 && reviewCount >= 3;
    progress['difficulty'] = accuracy >= 0.8 ? 1 : accuracy >= 0.6 ? 2 : 3;
    
    // Word progress is already saved in database by updateWordProgressAfterAnswer
    // No need to save to SharedPreferences anymore
    
    // Topic progress is now calculated from database, no need to update separately
    // Note: getTopicProgress() will calculate from database when needed
    
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

  /// Batch load progress for all topics in optimized queries
  Future<Map<String, Map<String, dynamic>>> getAllTopicsProgressBatch() async {
    try {
      const targetTopics = ['1.1', '1.2', '1.3', '1.4', '1.5', '2.0'];
      final topicsProgress = <String, Map<String, dynamic>>{};
      
      // Initialize default progress for all topics
      for (final topic in targetTopics) {
        topicsProgress[topic] = {
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
      
      // Batch query: Get all words for all topics in one query
      final allTopicWords = await _dbRepository.getWordsByTopicsBatch(targetTopics);
      
      // Group words by topic and calculate progress
      final wordsByTopic = <String, List<Word>>{};
      for (final word in allTopicWords) {
        if (word.topic.isNotEmpty && targetTopics.contains(word.topic)) {
          wordsByTopic.putIfAbsent(word.topic, () => []).add(word);
        }
      }
      
      // Calculate progress for each topic
      for (final topic in targetTopics) {
        final topicWords = wordsByTopic[topic] ?? [];
        int totalWords = topicWords.length;
        int learnedWords = 0;
        int totalCorrect = 0;
        int totalAttempts = 0;
        DateTime? lastStudied;
        double bestAccuracy = 0.0;
        
        for (final word in topicWords) {
          if (word.reviewCount >= 5) {
            learnedWords++;
          }
          totalCorrect += word.correctAnswers;
          totalAttempts += word.totalAttempts;
          
          if (word.lastReviewed != null) {
            if (lastStudied == null || word.lastReviewed!.isAfter(lastStudied)) {
              lastStudied = word.lastReviewed;
            }
          }
          
          if (word.masteryLevel > bestAccuracy) {
            bestAccuracy = word.masteryLevel * 100;
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

  /// Get words that need review today (from database)
  Future<List<Map<String, dynamic>>> getWordsForReview() async {
    try {
      // Get from database first
      final words = await _dbRepository.getWordsForReview(limit: 100);
      return words.map((word) => {
        'word': word.en,
        'topic': word.topic,
        'reviewCount': word.reviewCount,
        'correctAnswers': word.correctAnswers,
        'totalAttempts': word.totalAttempts,
        'lastReviewed': word.lastReviewed?.toIso8601String(),
        'nextReview': word.nextReview.toIso8601String(),
        'isLearned': word.reviewCount >= 5,
        'difficulty': word.difficulty,
        'masteryLevel': word.masteryLevel,
      }).toList();
    } catch (e) {
      print('⚠️ Error getting words for review from database: $e');
      // Fallback to SharedPreferences
      return await _getWordsForReviewFromSharedPrefs();
    }
  }
  
  /// Fallback: Get words for review from SharedPreferences
  Future<List<Map<String, dynamic>>> _getWordsForReviewFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final wordKeys = allKeys.where((key) => 
      key.startsWith(_wordProgressPrefix)
    ).toList();
    
    final wordsForReview = <Map<String, dynamic>>[];
    final today = DateTime.now();
    
    for (final key in wordKeys) {
      final progressJson = prefs.getString(key);
      if (progressJson != null) {
        final wordProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
        final nextReviewStr = wordProgress['nextReview'];
        
        if (nextReviewStr != null) {
          final nextReview = DateTime.parse(nextReviewStr);
          if (nextReview.isBefore(today) || nextReview.isAtSameMomentAs(today)) {
            wordsForReview.add(wordProgress);
          }
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
