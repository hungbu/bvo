import '../repository/topic_repository.dart';

/// Migration utility to help transition from old topic system to new clean system
class TopicMigration {
  final TopicRepository _repository = TopicRepository();

  /// Compare old vs new topic data to ensure migration is correct
  Future<Map<String, dynamic>> validateMigration() async {
    final results = <String, dynamic>{};
    
    try {
      // Get topics from both systems
      final oldTopics = await _oldRepository.getAllTopics();
      final newTopics = await _newRepository.getAllTopics();
      
      results['oldSystemTopicCount'] = oldTopics.length;
      results['newSystemTopicCount'] = newTopics.length;
      
      // Find missing topics
      final oldTopicIds = oldTopics.map((t) => t.topic).toSet();
      final newTopicIds = newTopics.map((t) => t.id).toSet();
      
      results['missingInNewSystem'] = oldTopicIds.difference(newTopicIds).toList();
      results['extraInNewSystem'] = newTopicIds.difference(oldTopicIds).toList();
      
      // Compare data for matching topics
      final comparisons = <String, Map<String, dynamic>>{};
      for (final oldTopic in oldTopics) {
        final matchingTopics = newTopics.where((t) => t.id == oldTopic.topic);
        final newTopic = matchingTopics.isNotEmpty ? matchingTopics.first : null;
        if (newTopic != null) {
          comparisons[oldTopic.topic] = {
            'oldTotalWords': oldTopic.totalWords,
            'newTotalWords': newTopic.totalWords,
            'oldLearnedWords': oldTopic.learnedWords,
            'newLearnedWords': newTopic.learnedWords,
            'wordCountMatch': oldTopic.totalWords == newTopic.totalWords,
            'progressMatch': oldTopic.learnedWords == newTopic.learnedWords,
          };
        }
      }
      
      results['topicComparisons'] = comparisons;
      results['migrationValid'] = results['missingInNewSystem'].isEmpty;
      
    } catch (e) {
      results['error'] = e.toString();
      results['migrationValid'] = false;
    }
    
    return results;
  }

  /// Generate topics.json from existing topic configs
  Future<List<Map<String, dynamic>>> generateTopicsJsonFromConfigs() async {
    // This would extract essential data from TopicConfigsRepository
    // and create the topics.json structure
    
    final topicsJson = <Map<String, dynamic>>[];
    
    // Get current topics from old system
    final oldTopics = await _oldRepository.getAllTopics();
    
    for (final topic in oldTopics) {
      topicsJson.add({
        'id': topic.topic,
        'name': topic.displayName,
        'iconName': _getIconName(topic.topic),
        'colorHex': _getColorHex(topic.topic),
        'difficulty': topic.difficulty,
        'description': topic.description,
        'category': topic.category.toString().split('.').last,
        'level': topic.level.toString().split('.').last,
      });
    }
    
    return topicsJson;
  }

  /// Helper methods to extract icon and color from topic name
  String _getIconName(String topicName) {
    const iconMap = {
      'schools': 'school',
      'family': 'family',
      'animals': 'pets',
      'food': 'fastfood',
      'drinks': 'drink',
      'clothing': 'checkroom',
      'weather': 'sunny',
      'colors': 'palette',
      'numbers': 'numbers',
      'time': 'time',
      'examination': 'quiz',
      'classroom': 'class',
    };
    return iconMap[topicName] ?? 'book';
  }

  String _getColorHex(String topicName) {
    const colorMap = {
      'schools': '#2196F3',
      'family': '#E91E63',
      'animals': '#8BC34A',
      'food': '#FF5722',
      'drinks': '#00BCD4',
      'clothing': '#9C27B0',
      'weather': '#FFC107',
      'colors': '#673AB7',
      'numbers': '#607D8B',
      'time': '#3F51B5',
      'examination': '#FF6F00',
      'classroom': '#1976D2',
    };
    return colorMap[topicName] ?? '#2196F3';
  }

  /// Print migration report
  Future<void> printMigrationReport() async {
    print('🔄 Topic Migration Report');
    print('=' * 50);
    
    final validation = await validateMigration();
    
    print('📊 Topic Counts:');
    print('  Old System: ${validation['oldSystemTopicCount']}');
    print('  New System: ${validation['newSystemTopicCount']}');
    
    if (validation['missingInNewSystem'].isNotEmpty) {
      print('❌ Missing in New System:');
      for (final topic in validation['missingInNewSystem']) {
        print('  - $topic');
      }
    }
    
    if (validation['extraInNewSystem'].isNotEmpty) {
      print('➕ Extra in New System:');
      for (final topic in validation['extraInNewSystem']) {
        print('  - $topic');
      }
    }
    
    print('✅ Migration Valid: ${validation['migrationValid']}');
    
    if (validation['error'] != null) {
      print('❌ Error: ${validation['error']}');
    }
  }
}

