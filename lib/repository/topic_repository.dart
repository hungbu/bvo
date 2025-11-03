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

  /// Load essential topic data from topics.json or generate from words
  Future<List<TopicEssentials>> _loadTopicEssentials() async {
    if (_cachedEssentials != null) return _cachedEssentials!;

    // Check if we're using the new data folder (1000)
    // If so, always generate topics from words
    final useNewData = await _isUsingNewDataFolder();
    
    if (useNewData) {
      print('📝 Using new data folder (1000), generating topics from words...');
      _cachedEssentials = await _generateTopicsFromWords();
      return _cachedEssentials!;
    }

    // Try to load from topics.json (for legacy data)
    try {
      final String jsonString = await rootBundle.loadString('assets/data/topic/topics.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _cachedEssentials = jsonList
          .map((json) => TopicEssentials.fromJson(json))
          .toList();
      
      print('✅ Loaded ${_cachedEssentials!.length} topics from topics.json');
      return _cachedEssentials!;
    } catch (e) {
      print('⚠️ Could not load topics.json: $e');
      print('📝 Generating topics from words...');
      
      // Generate topics dynamically from words as fallback
      _cachedEssentials = await _generateTopicsFromWords();
      return _cachedEssentials!;
    }
  }
  
  /// Check if we're using the new data folder (1000)
  Future<bool> _isUsingNewDataFolder() async {
    try {
      final String manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent) as Map<String, dynamic>;
      
      Iterable<String> candidateKeys;
      if (manifestMap.containsKey('files') && manifestMap['files'] is Map<String, dynamic>) {
        final Map<String, dynamic> filesMap = manifestMap['files'] as Map<String, dynamic>;
        candidateKeys = filesMap.keys;
      } else {
        candidateKeys = manifestMap.keys;
      }

      // Check if there are files in assets/data/1000/
      final hasNewData = candidateKeys.any((key) => 
        key.startsWith('assets/data/1000/') && key.endsWith('.json')
      );
      
      // Count files in new data folder
      final newDataCount = candidateKeys.where((key) => 
        key.startsWith('assets/data/1000/') && key.endsWith('.json')
      ).length;
      
      // Use new data if it exists and has files
      return hasNewData && newDataCount > 0;
    } catch (e) {
      print('Error checking data folder: $e');
      return false;
    }
  }
  
  /// Generate topics dynamically from words in the new data folder
  Future<List<TopicEssentials>> _generateTopicsFromWords() async {
    try {
      // Get all words from the new data source
      final allWords = await _dataLoader.getAllWords();
      
      // Extract unique topics from words
      final topicSet = <String>{};
      final topicWordCount = <String, int>{};
      final topicLevels = <String, String>{};
      
      for (final word in allWords) {
        final topicId = word.topic.toLowerCase();
        topicSet.add(topicId);
        topicWordCount[topicId] = (topicWordCount[topicId] ?? 0) + 1;
        // Store level for each topic (should all be BASIC for new data)
        topicLevels[topicId] = word.level.toString().split('.').last;
      }
      
      // Generate TopicEssentials for each unique topic
      final topics = <TopicEssentials>[];
      final topicNames = _getTopicDisplayNames();
      final topicCategories = _getTopicCategories();
      final topicColors = _getTopicColors();
      
      for (final topicId in topicSet.toList()..sort()) {
        final wordCount = topicWordCount[topicId] ?? 0;
        final level = topicLevels[topicId] ?? 'BASIC';
        final displayName = topicNames[topicId] ?? _capitalizeTopicName(topicId);
        final category = topicCategories[topicId] ?? 'general';
        final colorHex = topicColors[topicId] ?? '#2196F3';
        
        // Determine icon name based on topic
        final iconName = _getIconNameForTopic(topicId, category);
        
        // Difficulty based on word count (more words = higher difficulty for learning)
        final difficulty = wordCount > 50 ? 3 : wordCount > 20 ? 2 : 1;
        
        topics.add(TopicEssentials(
          id: topicId,
          name: displayName,
          iconName: iconName,
          colorHex: colorHex,
          difficulty: difficulty,
          description: '$wordCount từ vựng',
          category: category,
          level: level,
        ));
      }
      
      print('✅ Generated ${topics.length} topics from words: ${topics.map((t) => t.name).join(', ')}');
      return topics;
    } catch (e) {
      print('❌ Error generating topics from words: $e');
      return [];
    }
  }
  
  /// Get display names for topics
  Map<String, String> _getTopicDisplayNames() {
    return {
      'grammar': 'Ngữ pháp',
      'daily life': 'Cuộc sống hàng ngày',
      'travel': 'Du lịch',
      'food': 'Đồ ăn',
      'family': 'Gia đình',
      'school': 'Trường học',
      'work': 'Công việc',
      'health': 'Sức khỏe',
      'shopping': 'Mua sắm',
      'nature': 'Thiên nhiên',
      'animals': 'Động vật',
      'colors': 'Màu sắc',
      'numbers': 'Số đếm',
      'time': 'Thời gian',
      'weather': 'Thời tiết',
      'emotions': 'Cảm xúc',
      'body': 'Cơ thể',
      'transport': 'Giao thông',
      'places': 'Địa điểm',
      'activities': 'Hoạt động',
      'communication': 'Giao tiếp',
    };
  }
  
  /// Get categories for topics
  Map<String, String> _getTopicCategories() {
    return {
      'grammar': 'grammar',
      'daily life': 'daily_life',
      'travel': 'travel',
      'food': 'food',
      'family': 'family',
      'school': 'education',
      'work': 'business',
      'health': 'health',
      'shopping': 'economics',
      'nature': 'nature',
      'animals': 'animals',
      'colors': 'visual',
      'numbers': 'math',
      'time': 'time',
      'weather': 'nature',
      'emotions': 'emotions',
      'body': 'physical',
      'transport': 'transport',
      'places': 'places',
      'activities': 'sports',
      'communication': 'communication',
    };
  }
  
  /// Get colors for topics
  Map<String, String> _getTopicColors() {
    return {
      'grammar': '#9C27B0',      // Purple
      'daily life': '#2196F3',   // Blue
      'travel': '#00BCD4',       // Cyan
      'food': '#FF9800',         // Orange
      'family': '#E91E63',       // Pink
      'school': '#4CAF50',       // Green
      'work': '#607D8B',         // Blue Grey
      'health': '#F44336',       // Red
      'shopping': '#9C27B0',     // Purple
      'nature': '#4CAF50',       // Green
      'animals': '#795548',      // Brown
      'colors': '#FF5722',       // Deep Orange
      'numbers': '#3F51B5',      // Indigo
      'time': '#009688',         // Teal
      'weather': '#00BCD4',      // Cyan
      'emotions': '#E91E63',     // Pink
      'body': '#FF5722',         // Deep Orange
      'transport': '#607D8B',    // Blue Grey
      'places': '#9E9E9E',       // Grey
      'activities': '#4CAF50',   // Green
      'communication': '#2196F3', // Blue
    };
  }
  
  /// Get icon name for topic
  String _getIconNameForTopic(String topicId, String category) {
    // Map topic IDs to icon names
    final iconMap = {
      'grammar': 'rule',
      'daily life': 'schedule',
      'travel': 'flight',
      'food': 'fastfood',
      'family': 'family_restroom',
      'school': 'school',
      'work': 'work',
      'health': 'health_and_safety',
      'shopping': 'shopping_cart',
      'nature': 'nature',
      'animals': 'pets',
      'colors': 'palette',
      'numbers': 'numbers',
      'time': 'access_time',
      'weather': 'wb_sunny',
      'emotions': 'mood',
      'body': 'accessibility',
      'transport': 'directions_car',
      'places': 'location_city',
      'activities': 'directions_run',
      'communication': 'forum',
    };
    
    return iconMap[topicId] ?? 'book';
  }
  
  /// Capitalize topic name (convert "daily life" to "Daily Life")
  String _capitalizeTopicName(String topicId) {
    return topicId.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
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
