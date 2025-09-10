import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/word.dart';

/// Repository for managing user progress and learned words
class UserProgressRepository {
  static const String _progressPrefix = 'user_progress_';
  static const String _topicProgressPrefix = 'topic_progress_';
  static const String _wordProgressPrefix = 'word_progress_';

  /// Get user progress for a specific topic
  Future<Map<String, dynamic>> getTopicProgress(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString('$_topicProgressPrefix$topic');
    
    if (progressJson != null) {
      return Map<String, dynamic>.from(jsonDecode(progressJson));
    }
    
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

  /// Save user progress for a specific topic
  Future<void> saveTopicProgress(String topic, Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_topicProgressPrefix$topic', jsonEncode(progress));
  }

  /// Get progress for a specific word
  Future<Map<String, dynamic>> getWordProgress(String topic, String wordEn) async {
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

  /// Save progress for a specific word
  Future<void> saveWordProgress(String topic, String wordEn, Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final wordKey = '${topic}_$wordEn';
    await prefs.setString('$_wordProgressPrefix$wordKey', jsonEncode(progress));
  }

  /// Update word progress after correct answer
  Future<void> updateWordProgress(String topic, dWord word, bool isCorrect) async {
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
    
    await saveWordProgress(topic, word.en, progress);
    
    // Also update topic progress
    await _updateTopicProgress(topic);
    
    // Update last_topic in SharedPreferences
    await _updateLastTopic(topic);
  }

  /// Update topic progress statistics
  Future<void> _updateTopicProgress(String topic) async {
    final topicProgress = await getTopicProgress(topic);
    final prefs = await SharedPreferences.getInstance();
    
    // Get all word progress for this topic
    final allKeys = prefs.getKeys();
    final topicWordKeys = allKeys.where((key) => 
      key.startsWith('$_wordProgressPrefix${topic}_')
    ).toList();
    
    int totalWords = topicWordKeys.length;
    int learnedWords = 0;
    int totalCorrect = 0;
    int totalAttempts = 0;
    int totalStudyTime = 0;
    
    for (final key in topicWordKeys) {
      final progressJson = prefs.getString(key);
      if (progressJson != null) {
        final wordProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
        
        if (wordProgress['isLearned'] == true) {
          learnedWords++;
        }
        
        totalCorrect += (wordProgress['correctAnswers'] ?? 0) as int;
        totalAttempts += (wordProgress['totalAttempts'] ?? 0) as int;
      }
    }
    
    // Update topic statistics
    topicProgress['totalWords'] = totalWords;
    topicProgress['learnedWords'] = learnedWords;
    topicProgress['correctAnswers'] = totalCorrect;
    topicProgress['totalAttempts'] = totalAttempts;
    topicProgress['sessions'] = (topicProgress['sessions'] ?? 0) + 1;
    topicProgress['lastStudied'] = DateTime.now().toIso8601String();
    
    if (totalAttempts > 0) {
      final currentAccuracy = (totalCorrect / totalAttempts) * 100;
      topicProgress['avgAccuracy'] = currentAccuracy;
      
      final bestAccuracy = topicProgress['bestAccuracy'] ?? 0.0;
      if (currentAccuracy > bestAccuracy) {
        topicProgress['bestAccuracy'] = currentAccuracy;
      }
    }
    
    await saveTopicProgress(topic, topicProgress);
  }

  /// Get all topics with their progress
  Future<Map<String, Map<String, dynamic>>> getAllTopicsProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final topicKeys = allKeys.where((key) => 
      key.startsWith(_topicProgressPrefix)
    ).toList();
    
    final topicsProgress = <String, Map<String, dynamic>>{};
    
    for (final key in topicKeys) {
      final topic = key.substring(_topicProgressPrefix.length);
      final progressJson = prefs.getString(key);
      
      if (progressJson != null) {
        topicsProgress[topic] = Map<String, dynamic>.from(jsonDecode(progressJson));
      }
    }
    
    return topicsProgress;
  }

  /// Get words that need review today
  Future<List<Map<String, dynamic>>> getWordsForReview() async {
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
}
