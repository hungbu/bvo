import '../model/topic.dart';
import '../repository/topic_repository.dart';

/// Service class to handle topic business logic
class TopicService {
  final TopicRepository _repository = TopicRepository();
  
  // Cache for topics to avoid reloading
  List<Topic>? _cachedTopics;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// Get all topics sorted by difficulty and progress (cached)
  Future<List<Topic>> getTopicsForDisplay() async {
    // Return cached topics if still valid
    if (_cachedTopics != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidity) {
      return _cachedTopics!;
    }
    
    // Load fresh topics
    final topics = await _repository.getAllTopics();
    _cachedTopics = topics;
    _cacheTimestamp = DateTime.now();
    
    return topics;
  }
  
  /// Clear topics cache (call after learning/updating progress)
  void clearCache() {
    _cachedTopics = null;
    _cacheTimestamp = null;
    _repository.clearCache();
  }

  /// Get recommended topics for user
  Future<List<Topic>> getRecommendedTopics({int limit = 5}) async {
    final topics = await _repository.getAllTopics();
    
    // Filter and sort recommendations
    final recommendations = topics.where((topic) {
      // Recommend started but not completed topics
      if (topic.isStarted && !topic.isCompleted) return true;
      
      // Recommend beginner topics if no progress
      if (!topic.isStarted && topic.level == 'BASIC' && topic.difficulty <= 2) return true;
      
      return false;
    }).toList();
    
    // Sort by progress and difficulty
    recommendations.sort((a, b) {
      if (a.isStarted && !b.isStarted) return -1;
      if (!a.isStarted && b.isStarted) return 1;
      return a.difficulty.compareTo(b.difficulty);
    });
    
    return recommendations.take(limit).toList();
  }

  /// Get topics by category for organized display
  Future<Map<String, List<Topic>>> getTopicsByCategory() async {
    final topics = await _repository.getAllTopics();
    final categories = <String, List<Topic>>{};
    
    for (final topic in topics) {
      if (!categories.containsKey(topic.category)) {
        categories[topic.category] = [];
      }
      categories[topic.category]!.add(topic);
    }
    
    // Sort topics within each category
    for (final categoryTopics in categories.values) {
      categoryTopics.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    }
    
    return categories;
  }

  /// Get topic progress summary
  Future<Map<String, dynamic>> getProgressSummary() async {
    final stats = await _repository.getTopicStatistics();
    final topics = await _repository.getAllTopics();
    
    final basicTopics = topics.where((t) => t.level == 'BASIC').toList();
    final intermediateTopics = topics.where((t) => t.level == 'INTERMEDIATE').toList();
    final advancedTopics = topics.where((t) => t.level == 'ADVANCED').toList();
    
    return {
      ...stats,
      'basicProgress': _calculateLevelProgress(basicTopics),
      'intermediateProgress': _calculateLevelProgress(intermediateTopics),
      'advancedProgress': _calculateLevelProgress(advancedTopics),
      'recentTopics': await _getRecentTopics(),
    };
  }

  /// Get topic by ID with full data
  Future<Topic?> getTopicDetail(String topicId) async {
    return await _repository.getTopicById(topicId);
  }

  /// Search topics by name or description
  Future<List<Topic>> searchTopics(String query) async {
    if (query.trim().isEmpty) return [];
    
    final topics = await _repository.getAllTopics();
    final lowerQuery = query.toLowerCase();
    
    return topics.where((topic) {
      return topic.name.toLowerCase().contains(lowerQuery) ||
             (topic.description?.toLowerCase().contains(lowerQuery) ?? false) ||
             topic.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Helper methods

  double _calculateLevelProgress(List<Topic> topics) {
    if (topics.isEmpty) return 0.0;
    return topics.fold(0.0, (sum, t) => sum + t.progressPercentage) / topics.length;
  }

  Future<List<Topic>> _getRecentTopics() async {
    final topics = await _repository.getAllTopics();
    final recentTopics = topics
        .where((t) => t.lastStudied != null)
        .toList()
      ..sort((a, b) => b.lastStudied!.compareTo(a.lastStudied!));
    
    return recentTopics.take(5).toList();
  }
}