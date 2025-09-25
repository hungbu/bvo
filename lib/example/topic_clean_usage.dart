// Example usage of the new clean topic system
import '../service/topic_service.dart';
import '../utils/topic_migration.dart';
import '../repository/topic_repository_clean.dart';

/// Example demonstrating how to use the new clean topic system
class TopicCleanUsageExample {
  final TopicService _topicService = TopicService();
  final TopicRepositoryClean _repository = TopicRepositoryClean();
  final TopicMigration _migration = TopicMigration();

  /// Example: Get topics for main screen display
  Future<void> exampleGetTopicsForDisplay() async {
    print('📚 Getting topics for display...');
    
    final topics = await _topicService.getTopicsForDisplay();
    
    for (final topic in topics) {
      print('Topic: ${topic.name}');
      print('  - ID: ${topic.id}');
      print('  - Difficulty: ${topic.difficulty}/5');
      print('  - Progress: ${(topic.progressPercentage * 100).toInt()}%');
      print('  - Words: ${topic.learnedWords}/${topic.totalWords}');
      print('  - Color: ${topic.colorHex}');
      print('  - Icon: ${topic.iconName}');
      print('');
    }
  }

  /// Example: Get recommended topics
  Future<void> exampleGetRecommendations() async {
    print('🎯 Getting recommended topics...');
    
    final recommendations = await _topicService.getRecommendedTopics(limit: 3);
    
    for (final topic in recommendations) {
      print('Recommended: ${topic.name} (${topic.difficulty}/5)');
    }
  }

  /// Example: Search topics
  Future<void> exampleSearchTopics() async {
    print('🔍 Searching topics...');
    
    final results = await _topicService.searchTopics('học');
    
    print('Found ${results.length} topics:');
    for (final topic in results) {
      print('- ${topic.name}: ${topic.description}');
    }
  }

  /// Example: Get topics by category
  Future<void> exampleGetTopicsByCategory() async {
    print('📂 Getting topics by category...');
    
    final categorizedTopics = await _topicService.getTopicsByCategory();
    
    for (final entry in categorizedTopics.entries) {
      print('Category: ${entry.key}');
      for (final topic in entry.value) {
        print('  - ${topic.name}');
      }
      print('');
    }
  }

  /// Example: Get progress summary
  Future<void> exampleGetProgressSummary() async {
    print('📊 Getting progress summary...');
    
    final summary = await _topicService.getProgressSummary();
    
    print('Total Topics: ${summary['totalTopics']}');
    print('Completed: ${summary['completedTopics']}');
    print('Started: ${summary['startedTopics']}');
    print('Total Words: ${summary['totalWords']}');
    print('Learned Words: ${summary['learnedWords']}');
    print('Average Progress: ${(summary['averageProgress'] * 100).toStringAsFixed(1)}%');
    print('Basic Progress: ${(summary['basicProgress'] * 100).toStringAsFixed(1)}%');
    print('Intermediate Progress: ${(summary['intermediateProgress'] * 100).toStringAsFixed(1)}%');
    print('Advanced Progress: ${(summary['advancedProgress'] * 100).toStringAsFixed(1)}%');
  }

  /// Example: Get topic detail
  Future<void> exampleGetTopicDetail(String topicId) async {
    print('📖 Getting topic detail for: $topicId');
    
    final topic = await _topicService.getTopicDetail(topicId);
    
    if (topic != null) {
      print('Topic: ${topic.name}');
      print('Description: ${topic.description}');
      print('Category: ${topic.category}');
      print('Level: ${topic.level}');
      print('Difficulty: ${topic.difficulty}/5');
      print('Total Words: ${topic.totalWords}');
      print('Learned Words: ${topic.learnedWords}');
      print('Progress: ${(topic.progressPercentage * 100).toInt()}%');
      print('Estimated Time: ${topic.estimatedTime}');
      print('Last Studied: ${topic.lastStudied}');
      print('Color: ${topic.colorHex}');
      print('Icon: ${topic.iconName}');
    } else {
      print('Topic not found!');
    }
  }

  /// Example: Migration validation
  Future<void> exampleMigrationValidation() async {
    print('🔄 Validating migration...');
    
    await _migration.printMigrationReport();
  }

  /// Example: Generate topics.json from old system
  Future<void> exampleGenerateTopicsJson() async {
    print('📝 Generating topics.json from old system...');
    
    final topicsJson = await _migration.generateTopicsJsonFromConfigs();
    
    print('Generated ${topicsJson.length} topic entries:');
    for (final topic in topicsJson.take(3)) {
      print('- ${topic['name']} (${topic['id']})');
    }
  }

  /// Run all examples
  Future<void> runAllExamples() async {
    await exampleGetTopicsForDisplay();
    await exampleGetRecommendations();
    await exampleSearchTopics();
    await exampleGetTopicsByCategory();
    await exampleGetProgressSummary();
    await exampleGetTopicDetail('schools');
    await exampleMigrationValidation();
    await exampleGenerateTopicsJson();
  }
}
