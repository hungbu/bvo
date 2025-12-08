import '../model/topic.dart';
import '../repository/user_progress_repository.dart';

/// Optimized topic repository - hardcoded topics with batch progress loading
class TopicRepository {
  final UserProgressRepository _progressRepository = UserProgressRepository();
  
  List<TopicEssentials>? _cachedEssentials;

  /// Load essential topic data - hardcoded for performance
  /// Only 6 topics: 1.1, 1.2, 1.3, 1.4, 1.5, 2.0
  Future<List<TopicEssentials>> _loadTopicEssentials() async {
    if (_cachedEssentials != null) return _cachedEssentials!;

    // Hardcode 6 topics with fixed word counts for optimal performance
    _cachedEssentials = [
      TopicEssentials(
        id: '1.1',
        name: 'Level 1.1 - Từ cơ bản (Phần 1)',
        iconName: 'school',
        colorHex: '#4CAF50',
        difficulty: 1,
        description: '119 từ vựng',
        category: 'level',
        level: 'BASIC',
      ),
      TopicEssentials(
        id: '1.2',
        name: 'Level 1.2 - Từ cơ bản (Phần 2)',
        iconName: 'school',
        colorHex: '#2196F3',
        difficulty: 1,
        description: '120 từ vựng',
        category: 'level',
        level: 'BASIC',
      ),
      TopicEssentials(
        id: '1.3',
        name: 'Level 1.3 - Từ cơ bản (Phần 3)',
        iconName: 'school',
        colorHex: '#FF9800',
        difficulty: 1,
        description: '120 từ vựng',
        category: 'level',
        level: 'BASIC',
      ),
      TopicEssentials(
        id: '1.4',
        name: 'Level 1.4 - Từ cơ bản (Phần 4)',
        iconName: 'school',
        colorHex: '#9C27B0',
        difficulty: 1,
        description: '119 từ vựng',
        category: 'level',
        level: 'BASIC',
      ),
      TopicEssentials(
        id: '1.5',
        name: 'Level 1.5 - Từ cơ bản (Phần 5)',
        iconName: 'school',
        colorHex: '#F44336',
        difficulty: 2,
        description: '120 từ vựng',
        category: 'level',
        level: 'BASIC',
      ),
      TopicEssentials(
        id: '2.0',
        name: 'Level 2.0 - Từ trung cấp',
        iconName: 'school',
        colorHex: '#00BCD4',
        difficulty: 3,
        description: '160 từ vựng',
        category: 'level',
        level: 'INTERMEDIATE',
      ),
    ];
    
    return _cachedEssentials!;
  }
  

  /// Get all topics with calculated data - optimized with batch progress loading
  Future<List<Topic>> getAllTopics() async {
    final essentials = await _loadTopicEssentials();
    
    // Batch load progress for all topics at once
    final allProgress = await _progressRepository.getAllTopicsProgressBatch();
    
    // Create topics with progress data
    final topics = <Topic>[];
    for (final essential in essentials) {
      final progress = allProgress[essential.id] ?? {};
      final totalWords = _getWordCountForTopic(essential.id);
      final learnedWords = progress['learnedWords'] ?? 0;
      final lastStudied = progress['lastStudied'] != null 
          ? DateTime.tryParse(progress['lastStudied'])
          : null;
      
      final progressPercentage = totalWords > 0 ? (learnedWords / totalWords) : 0.0;
      final estimatedTime = '$totalWords min';
      
      topics.add(Topic(
        essentials: essential,
        totalWords: totalWords,
        learnedWords: learnedWords,
        progressPercentage: progressPercentage,
        estimatedTime: estimatedTime,
        lastStudied: lastStudied,
      ));
    }

    return topics;
  }
  
  /// Get word count for a topic (hardcoded)
  int _getWordCountForTopic(String topicId) {
    const wordCounts = {
      '1.1': 119,
      '1.2': 120,
      '1.3': 120,
      '1.4': 119,
      '1.5': 120,
      '2.0': 160,
    };
    return wordCounts[topicId] ?? 0;
  }

  /// Get topics (alias for getAllTopics)
  Future<List<Topic>> getTopics() async {
    return await getAllTopics();
  }

  /// Get topic by ID - optimized (uses batch progress)
  Future<Topic?> getTopicById(String id) async {
    final essentials = await _loadTopicEssentials();
    final essential = essentials.where((e) => e.id == id).firstOrNull;
    
    if (essential == null) return null;
    
    // Load progress for this single topic
    final progress = await _progressRepository.getTopicProgress(id);
    final totalWords = _getWordCountForTopic(id);
    final learnedWords = progress['learnedWords'] ?? 0;
    final lastStudied = progress['lastStudied'] != null 
        ? DateTime.tryParse(progress['lastStudied'])
        : null;
    
    final progressPercentage = totalWords > 0 ? (learnedWords / totalWords) : 0.0;
    final estimatedTime = '$totalWords min';
    
    return Topic(
      essentials: essential,
      totalWords: totalWords,
      learnedWords: learnedWords,
      progressPercentage: progressPercentage,
      estimatedTime: estimatedTime,
      lastStudied: lastStudied,
    );
  }

  /// Get topics by level - optimized (uses batch progress)
  Future<List<Topic>> getTopicsByLevel(String level) async {
    final allTopics = await getAllTopics();
    return allTopics.where((t) => t.level == level).toList();
  }

  /// Get topics by category - optimized (uses batch progress)
  Future<List<Topic>> getTopicsByCategory(String category) async {
    final allTopics = await getAllTopics();
    return allTopics.where((t) => t.category == category).toList();
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
