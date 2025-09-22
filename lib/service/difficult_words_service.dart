import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repository/user_progress_repository.dart';

class DifficultWordsService {
  static const String _reminderSettingsKey = 'reminder_settings';
  
  /// Lấy danh sách từ khó theo topic từ UserProgressRepository
  Future<List<DifficultWordData>> getDifficultWordsByTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    List<DifficultWordData> difficultWords = [];
    
    // Lấy tất cả word progress keys cho topic này
    final allKeys = prefs.getKeys();
    final topicKeys = allKeys.where((key) => 
      key.startsWith('word_progress_${topic}_')
    ).toList();
    
    print('🔍 Checking topic "$topic": found ${topicKeys.length} word progress keys');
    
    for (String key in topicKeys) {
      final progressJson = prefs.getString(key);
      if (progressJson != null) {
        try {
          final progress = Map<String, dynamic>.from(jsonDecode(progressJson));
          
          final totalAttempts = progress['totalAttempts'] ?? 0;
          final correctAnswers = progress['correctAnswers'] ?? 0;
          
          if (totalAttempts > 0) {
            final incorrectCount = totalAttempts - correctAnswers;
            final errorRate = incorrectCount / totalAttempts;
            
            // Chỉ lấy từ có error rate > 0 (có ít nhất 1 lần sai)
            if (incorrectCount > 0) {
              // Extract word từ key: word_progress_topic_word
              final keyParts = key.split('_');
              final wordEn = keyParts.sublist(3).join('_'); // Lấy phần sau topic
              
              final lastReviewed = progress['lastReviewed'] ?? '';
              final lastAttempt = DateTime.tryParse(lastReviewed) ?? DateTime.now();
              
              difficultWords.add(DifficultWordData(
                word: wordEn,
                topic: topic,
                incorrectCount: incorrectCount,
                correctCount: correctAnswers,
                totalAttempts: totalAttempts,
                errorRate: errorRate,
                lastAttempt: lastAttempt,
              ));
              
              print('  - Word "$wordEn": $incorrectCount/$totalAttempts errors (${(errorRate * 100).toStringAsFixed(1)}%)');
            }
          }
        } catch (e) {
          print('❌ Error parsing progress for key $key: $e');
        }
      }
    }
    
    // Sắp xếp theo tỷ lệ sai giảm dần
    difficultWords.sort((a, b) => b.errorRate.compareTo(a.errorRate));
    
    print('📊 Topic "$topic": ${difficultWords.length} difficult words found');
    return difficultWords;
  }
  
  /// Lấy tất cả từ khó (tất cả topics) từ UserProgressRepository
  Future<List<DifficultWordData>> getAllDifficultWords() async {
    final prefs = await SharedPreferences.getInstance();
    List<DifficultWordData> allDifficultWords = [];
    
    // Lấy tất cả topics từ word progress keys
    final allKeys = prefs.getKeys();
    Set<String> topics = {};
    
    for (String key in allKeys) {
      if (key.startsWith('word_progress_')) {
        final keyParts = key.split('_');
        if (keyParts.length >= 3) {
          final topic = keyParts[2]; // word_progress_TOPIC_word
          topics.add(topic);
        }
      }
    }
    
    print('🔍 Found topics with word progress: $topics');
    
    // Lấy từ khó từ tất cả topics
    for (String topic in topics) {
      final topicDifficultWords = await getDifficultWordsByTopic(topic);
      allDifficultWords.addAll(topicDifficultWords);
    }
    
    // Sắp xếp theo tỷ lệ sai giảm dần
    allDifficultWords.sort((a, b) => b.errorRate.compareTo(a.errorRate));
    
    print('📊 Total difficult words found: ${allDifficultWords.length}');
    return allDifficultWords;
  }
  
  /// Lấy top N từ khó nhất
  Future<List<DifficultWordData>> getTopDifficultWords(int limit) async {
    final allDifficultWords = await getAllDifficultWords();
    return allDifficultWords.take(limit).toList();
  }
  
  /// Lấy từ khó cần ôn tập (tỷ lệ sai > threshold)
  Future<List<DifficultWordData>> getWordsNeedingReview({double threshold = 0.3}) async {
    final allDifficultWords = await getAllDifficultWords();
    return allDifficultWords.where((word) => word.errorRate > threshold).toList();
  }
  
  /// Lấy thống kê từ khó theo topic từ UserProgressRepository
  Future<Map<String, TopicDifficultStats>> getDifficultStatsByTopic() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, TopicDifficultStats> stats = {};
    
    // Lấy tất cả topics từ word progress keys
    final allKeys = prefs.getKeys();
    Set<String> topics = {};
    
    for (String key in allKeys) {
      if (key.startsWith('word_progress_')) {
        final keyParts = key.split('_');
        if (keyParts.length >= 3) {
          final topic = keyParts[2]; // word_progress_TOPIC_word
          topics.add(topic);
        }
      }
    }
    
    print('🔍 Calculating difficult stats for topics: $topics');
    
    for (String topic in topics) {
      final difficultWords = await getDifficultWordsByTopic(topic);
      final totalWords = difficultWords.length;
      final highErrorWords = difficultWords.where((w) => w.errorRate > 0.5).length;
      final mediumErrorWords = difficultWords.where((w) => w.errorRate > 0.3 && w.errorRate <= 0.5).length;
      
      double avgErrorRate = 0.0;
      if (difficultWords.isNotEmpty) {
        avgErrorRate = difficultWords.map((w) => w.errorRate).reduce((a, b) => a + b) / difficultWords.length;
      }
      
      stats[topic] = TopicDifficultStats(
        topic: topic,
        totalDifficultWords: totalWords,
        highErrorWords: highErrorWords,
        mediumErrorWords: mediumErrorWords,
        averageErrorRate: avgErrorRate,
        topDifficultWords: difficultWords.take(5).toList(),
      );
      
      print('📊 Topic "$topic" stats: ${totalWords} difficult, avg error: ${(avgErrorRate * 100).toStringAsFixed(1)}%');
    }
    
    return stats;
  }
  
  /// Cập nhật cài đặt nhắc nhở
  Future<void> updateReminderSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderSettingsKey, jsonEncode(settings.toJson()));
  }
  
  /// Lấy cài đặt nhắc nhở
  Future<ReminderSettings> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_reminderSettingsKey);
    
    if (settingsJson != null) {
      return ReminderSettings.fromJson(jsonDecode(settingsJson));
    }
    
    // Cài đặt mặc định
    return ReminderSettings(
      isEnabled: true,
      morningTime: '08:00',
      afternoonTime: '14:00',
      eveningTime: '20:00',
      wordsPerReminder: 5,
      onlyDifficultWords: true,
      minimumErrorRate: 0.3,
    );
  }
}

/// Model cho dữ liệu từ khó
class DifficultWordData {
  final String word;
  final String topic;
  final int incorrectCount;
  final int correctCount;
  final int totalAttempts;
  final double errorRate;
  final DateTime lastAttempt;
  
  DifficultWordData({
    required this.word,
    required this.topic,
    required this.incorrectCount,
    required this.correctCount,
    required this.totalAttempts,
    required this.errorRate,
    required this.lastAttempt,
  });
  
  String get difficultyLevel {
    if (errorRate > 0.7) return 'Rất khó';
    if (errorRate > 0.5) return 'Khó';
    if (errorRate > 0.3) return 'Trung bình';
    return 'Dễ';
  }
  
  Color get difficultyColor {
    if (errorRate > 0.7) return Colors.red;
    if (errorRate > 0.5) return Colors.orange;
    if (errorRate > 0.3) return Colors.yellow;
    return Colors.green;
  }
}

/// Model cho thống kê từ khó theo topic
class TopicDifficultStats {
  final String topic;
  final int totalDifficultWords;
  final int highErrorWords;
  final int mediumErrorWords;
  final double averageErrorRate;
  final List<DifficultWordData> topDifficultWords;
  
  TopicDifficultStats({
    required this.topic,
    required this.totalDifficultWords,
    required this.highErrorWords,
    required this.mediumErrorWords,
    required this.averageErrorRate,
    required this.topDifficultWords,
  });
}

/// Model cho cài đặt nhắc nhở
class ReminderSettings {
  final bool isEnabled;
  final String morningTime;
  final String afternoonTime;
  final String eveningTime;
  final int wordsPerReminder;
  final bool onlyDifficultWords;
  final double minimumErrorRate;
  
  ReminderSettings({
    required this.isEnabled,
    required this.morningTime,
    required this.afternoonTime,
    required this.eveningTime,
    required this.wordsPerReminder,
    required this.onlyDifficultWords,
    required this.minimumErrorRate,
  });
  
  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'morningTime': morningTime,
    'afternoonTime': afternoonTime,
    'eveningTime': eveningTime,
    'wordsPerReminder': wordsPerReminder,
    'onlyDifficultWords': onlyDifficultWords,
    'minimumErrorRate': minimumErrorRate,
  };
  
  factory ReminderSettings.fromJson(Map<String, dynamic> json) => ReminderSettings(
    isEnabled: json['isEnabled'] ?? true,
    morningTime: json['morningTime'] ?? '08:00',
    afternoonTime: json['afternoonTime'] ?? '14:00',
    eveningTime: json['eveningTime'] ?? '20:00',
    wordsPerReminder: json['wordsPerReminder'] ?? 5,
    onlyDifficultWords: json['onlyDifficultWords'] ?? true,
    minimumErrorRate: json['minimumErrorRate'] ?? 0.3,
  );
}
