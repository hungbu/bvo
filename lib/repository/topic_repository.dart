import '../model/word.dart';
import '../model/topic.dart';
import '../service/vocabulary_data_loader.dart';

/// Repository for topic-related operations
class TopicRepository {
  final VocabularyDataLoader _dataLoader = VocabularyDataLoader();

  /// Get topics (alias for getAllTopics)
  Future<List<Topic>> getTopics() async {
    return await getAllTopics();
  }

  /// Get all available topics
  Future<List<Topic>> getAllTopics() async {
    final topicNames = await _dataLoader.getAllTopics();
    final topics = <Topic>[];
    
    for (final topicName in topicNames) {
      final words = await _dataLoader.getWordsByTopic(topicName);
      final topic = Topic.fromWords(topicName, words);
      topics.add(topic);
    }
    
    return topics;
  }

  /// Get topics by level
  Future<List<Topic>> getTopicsByLevel(WordLevel level) async {
    final words = await _dataLoader.getWordsByLevel(level);
    final topicGroups = <String, List<dWord>>{};
    
    // Group words by topic
    for (final word in words) {
      if (!topicGroups.containsKey(word.topic)) {
        topicGroups[word.topic] = [];
      }
      topicGroups[word.topic]!.add(word);
    }
    
    // Create topics from grouped words
    final topics = <Topic>[];
    for (final entry in topicGroups.entries) {
      final topic = Topic.fromWords(entry.key, entry.value);
      topics.add(topic);
    }
    
    return topics;
  }

  /// Get topic by name
  Future<Topic?> getTopicByName(String topicName) async {
    final words = await _dataLoader.getWordsByTopic(topicName);
    if (words.isEmpty) return null;
    
    return Topic.fromWords(topicName, words);
  }

  /// Get topic statistics
  Future<Map<String, dynamic>> getTopicStatistics() async {
    final topics = await getAllTopics();
    final stats = <String, dynamic>{};
    
    for (final topic in topics) {
      stats[topic.topic] = {
        'wordCount': topic.totalWords,
        'difficulty': topic.difficulty,
        'level': topic.level.toString().split('.').last,
        'category': topic.category.toString().split('.').last,
      };
    }
    
    return stats;
  }
}