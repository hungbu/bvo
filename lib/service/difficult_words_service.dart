import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DifficultWordsService {
  static const String _reminderSettingsKey = 'reminder_settings';
  
  /// Lấy danh sách từ khó theo topic
  Future<List<DifficultWordData>> getDifficultWordsByTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    List<DifficultWordData> difficultWords = [];
    
    // Lấy tất cả keys liên quan đến topic
    final allKeys = prefs.getKeys();
    final topicKeys = allKeys.where((key) => 
      key.startsWith('${topic}_') && key.endsWith('_incorrect_answers')
    ).toList();
    
    for (String key in topicKeys) {
      final incorrectCount = prefs.getInt(key) ?? 0;
      final correctKey = key.replaceAll('_incorrect_answers', '_correct_answers');
      final correctCount = prefs.getInt(correctKey) ?? 0;
      final totalAttempts = incorrectCount + correctCount;
      
      if (totalAttempts > 0 && incorrectCount > 0) {
        final errorRate = incorrectCount / totalAttempts;
        final wordEn = key.replaceAll('${topic}_', '').replaceAll('_incorrect_answers', '');
        
        difficultWords.add(DifficultWordData(
          word: wordEn,
          topic: topic,
          incorrectCount: incorrectCount,
          correctCount: correctCount,
          totalAttempts: totalAttempts,
          errorRate: errorRate,
          lastAttempt: DateTime.now(), // Sẽ cập nhật từ dữ liệu thực tế
        ));
      }
    }
    
    // Sắp xếp theo tỷ lệ sai giảm dần
    difficultWords.sort((a, b) => b.errorRate.compareTo(a.errorRate));
    
    return difficultWords;
  }
  
  /// Lấy tất cả từ khó (tất cả topics)
  Future<List<DifficultWordData>> getAllDifficultWords() async {
    final prefs = await SharedPreferences.getInstance();
    List<DifficultWordData> allDifficultWords = [];
    
    // Lấy tất cả topics
    final allKeys = prefs.getKeys();
    Set<String> topics = {};
    
    for (String key in allKeys) {
      if (key.endsWith('_incorrect_answers')) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final topic = parts[0];
          topics.add(topic);
        }
      }
    }
    
    // Lấy từ khó từ tất cả topics
    for (String topic in topics) {
      final topicDifficultWords = await getDifficultWordsByTopic(topic);
      allDifficultWords.addAll(topicDifficultWords);
    }
    
    // Sắp xếp theo tỷ lệ sai giảm dần
    allDifficultWords.sort((a, b) => b.errorRate.compareTo(a.errorRate));
    
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
  
  /// Lấy thống kê từ khó theo topic
  Future<Map<String, TopicDifficultStats>> getDifficultStatsByTopic() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, TopicDifficultStats> stats = {};
    
    // Lấy tất cả topics
    final allKeys = prefs.getKeys();
    Set<String> topics = {};
    
    for (String key in allKeys) {
      if (key.endsWith('_incorrect_answers')) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final topic = parts[0];
          topics.add(topic);
        }
      }
    }
    
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
