import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage word progress caching in SharedPreferences
/// Provides fast access to word learning state (reviewCount, correctAnswers, totalAttempts)
class WordProgressCacheService {
  static const String _prefix = 'word_progress_';
  
  /// Get word progress from SharedPreferences (fast)
  Future<Map<String, dynamic>?> getWordProgress(String topic, String wordEn) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${topic}_$wordEn';
    final json = prefs.getString(key);
    if (json != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(json));
      } catch (e) {
        print('⚠️ Error parsing word progress for $wordEn: $e');
        return null;
      }
    }
    return null;
  }
  
  /// Save word progress to SharedPreferences (sync)
  Future<void> saveWordProgress(String topic, String wordEn, Map<String, dynamic> progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix${topic}_$wordEn';
      await prefs.setString(key, jsonEncode(progress));
    } catch (e) {
      print('❌ Error saving word progress for $wordEn: $e');
    }
  }
  
  /// Batch get word progress for multiple words
  Future<Map<String, Map<String, dynamic>>> getBatchWordProgress(
    String topic, 
    List<String> wordEnList
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, Map<String, dynamic>>{};
    
    for (final wordEn in wordEnList) {
      final key = '$_prefix${topic}_$wordEn';
      final json = prefs.getString(key);
      if (json != null) {
        try {
          result[wordEn] = Map<String, dynamic>.from(jsonDecode(json));
        } catch (e) {
          print('⚠️ Error parsing word progress for $wordEn: $e');
        }
      }
    }
    
    return result;
  }
  
  /// Get all word progress for a topic
  Future<Map<String, Map<String, dynamic>>> getAllTopicProgress(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final prefix = '$_prefix${topic}_';
    
    final result = <String, Map<String, dynamic>>{};
    for (final key in allKeys) {
      if (key.startsWith(prefix)) {
        final json = prefs.getString(key);
        if (json != null) {
          try {
            final wordEn = key.substring(prefix.length);
            result[wordEn] = Map<String, dynamic>.from(jsonDecode(json));
          } catch (e) {
            print('⚠️ Error parsing word progress for key $key: $e');
          }
        }
      }
    }
    
    return result;
  }
}

