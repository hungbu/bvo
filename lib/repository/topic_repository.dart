import 'dart:convert';
import 'package:flutter/services.dart';
import '../model/topic.dart';
import '../service/vocabulary_data_loader.dart';
import '../repository/user_progress_repository.dart';

/// Clean topic repository that loads essential data from topics.json
/// and calculates dynamic data from words
class TopicRepository {
  final VocabularyDataLoader _dataLoader = VocabularyDataLoader();
  final UserProgressRepository _progressRepository = UserProgressRepository();
  
  List<TopicEssentials>? _cachedEssentials;

  /// Load essential topic data from topics.json
  Future<List<TopicEssentials>> _loadTopicEssentials() async {
    if (_cachedEssentials != null) return _cachedEssentials!;

    try {
      final String jsonString = await rootBundle.loadString('assets/data/topics.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _cachedEssentials = jsonList
          .map((json) => TopicEssentials.fromJson(json))
          .toList();
      
      return _cachedEssentials!;
    } catch (e) {
      print('❌ Error loading topics.json: $e');
      return [];
    }
  }

  /// Get all topics with calculated data
  Future<List<Topic>> getAllTopics() async {
    final essentials = await _loadTopicEssentials();
    final topics = <Topic>[];

    for (final essential in essentials) {
      final topic = await _createTopicWithCalculatedData(essential);
      topics.add(topic);
    }

    return topics;
  }

  /// Get topics (alias for getAllTopics)
  Future<List<Topic>> getTopics() async {
    return await getAllTopics();
  }

  /// Get topic by ID
  Future<Topic?> getTopicById(String id) async {
    final essentials = await _loadTopicEssentials();
    final essential = essentials.where((e) => e.id == id).firstOrNull;
    
    if (essential == null) return null;
    
    return await _createTopicWithCalculatedData(essential);
  }

  /// Get topics by level
  Future<List<Topic>> getTopicsByLevel(String level) async {
    final essentials = await _loadTopicEssentials();
    final filteredEssentials = essentials.where((e) => e.level == level).toList();
    
    final topics = <Topic>[];
    for (final essential in filteredEssentials) {
      final topic = await _createTopicWithCalculatedData(essential);
      topics.add(topic);
    }

    return topics;
  }

  /// Get topics by category
  Future<List<Topic>> getTopicsByCategory(String category) async {
    final essentials = await _loadTopicEssentials();
    final filteredEssentials = essentials.where((e) => e.category == category).toList();
    
    final topics = <Topic>[];
    for (final essential in filteredEssentials) {
      final topic = await _createTopicWithCalculatedData(essential);
      topics.add(topic);
    }

    return topics;
  }

  /// Create topic with calculated data from words and progress
  Future<Topic> _createTopicWithCalculatedData(TopicEssentials essential) async {
    try {
      // Get words for this topic
      final words = await _dataLoader.getWordsByTopic(essential.id);
      final totalWords = words.length;
      
      // Get progress data
      final topicProgress = await _progressRepository.getTopicProgress(essential.id);
      final learnedWords = topicProgress['learnedWords'] ?? 0;
      final lastStudied = topicProgress['lastStudied'] != null 
          ? DateTime.parse(topicProgress['lastStudied'])
          : null;
      
      // Calculate progress percentage
      final progressPercentage = totalWords > 0 ? learnedWords / totalWords : 0.0;
      
      // Calculate estimated time (rough estimate: 1 minute per word)
      final estimatedTime = '${totalWords} min';

      return Topic(
        essentials: essential,
        totalWords: totalWords,
        learnedWords: learnedWords,
        progressPercentage: progressPercentage,
        estimatedTime: estimatedTime,
        lastStudied: lastStudied,
      );
    } catch (e) {
      print('❌ Error creating topic ${essential.id}: $e');
      // Return topic with essential data only
      return Topic(essentials: essential);
    }
  }

  /// Refresh topic data (clear cache)
  void clearCache() {
    _cachedEssentials = null;
  }

  /// Get topic statistics
  Future<Map<String, dynamic>> getTopicStatistics() async {
    final topics = await getAllTopics();
    
    return {
      'totalTopics': topics.length,
      'completedTopics': topics.where((t) => t.isCompleted).length,
      'startedTopics': topics.where((t) => t.isStarted).length,
      'totalWords': topics.fold(0, (sum, t) => sum + t.totalWords),
      'learnedWords': topics.fold(0, (sum, t) => sum + t.learnedWords),
      'averageProgress': topics.isNotEmpty 
          ? topics.fold(0.0, (sum, t) => sum + t.progressPercentage) / topics.length
          : 0.0,
    };
  }

  /// Get available categories
  Future<List<String>> getCategories() async {
    final essentials = await _loadTopicEssentials();
    return essentials.map((e) => e.category).toSet().toList()..sort();
  }

  /// Get available levels
  Future<List<String>> getLevels() async {
    final essentials = await _loadTopicEssentials();
    return essentials.map((e) => e.level).toSet().toList()..sort();
  }
}

/// Extension to add firstOrNull method
extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
