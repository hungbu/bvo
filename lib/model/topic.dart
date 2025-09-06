import 'word.dart';

enum TopicLevel {
  BASIC1,
  BASIC2, 
  BASIC3,
  ADVANCED1,
  ADVANCED2,
  ADVANCED3,
}

enum TopicCategory {
  education,     // schools, classroom, examination
  family,        // family, relationships
  visual,        // colors, shapes, appearance
  math,          // numbers, ordinal numbers
  physical,      // body, health
  food,          // food, drinks
  animals,       // animals, pets
  social,        // people, characteristics
  academic,      // universities, subjects
  general,       // mixed topics
}

class Topic {
  final String id;
  final String topic;
  final String displayName;        // User-friendly name
  final String description;        // Topic description
  final TopicLevel level;          // BASIC1, BASIC2, etc.
  final TopicCategory category;    // education, family, etc.
  final int difficulty;            // 1-5 difficulty level
  final int estimatedWords;        // Expected number of words
  final String? iconName;          // Icon identifier
  final String? imageUrl;          // Topic illustration
  final List<String> tags;         // Additional tags for filtering
  final bool isKidFriendly;        // Safe for children
  final String? culturalNote;      // Cultural context for Vietnamese learners
  
  // Learning progress (will be calculated dynamically)
  final int learnedWords;          // Number of words learned
  final int totalWords;            // Total words in topic
  final double progressPercentage; // 0.0 - 1.0
  final DateTime? lastStudied;     // Last time user studied this topic
  final int studyStreak;           // Consecutive days studied
  
  // Topic group information
  final String? groupId;           // e.g., 'basic_1', 'advanced_1'
  final String? groupName;         // e.g., 'Basic 1', 'Advanced 1'
  final int? orderInGroup;         // Order within the group

  const Topic({
    required this.id,
    required this.topic,
    required this.displayName,
    this.description = '',
    required this.level,
    required this.category,
    this.difficulty = 1,
    this.estimatedWords = 20,
    this.iconName,
    this.imageUrl,
    this.tags = const [],
    this.isKidFriendly = true,
    this.culturalNote,
    this.learnedWords = 0,
    this.totalWords = 0,
    this.progressPercentage = 0.0,
    this.lastStudied,
    this.studyStreak = 0,
    this.groupId,
    this.groupName,
    this.orderInGroup,
  });

  // Convert a Topic to a Map (for storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'displayName': displayName,
      'description': description,
      'level': level.toString().split('.').last,
      'category': category.toString().split('.').last,
      'difficulty': difficulty,
      'estimatedWords': estimatedWords,
      'iconName': iconName,
      'imageUrl': imageUrl,
      'tags': tags,
      'isKidFriendly': isKidFriendly,
      'culturalNote': culturalNote,
      'learnedWords': learnedWords,
      'totalWords': totalWords,
      'progressPercentage': progressPercentage,
      'lastStudied': lastStudied?.toIso8601String(),
      'studyStreak': studyStreak,
      'groupId': groupId,
      'groupName': groupName,
      'orderInGroup': orderInGroup,
    };
  }

  // Create a Topic from a Map (from storage)
  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] ?? '',
      topic: json['topic'] ?? '',
      displayName: json['displayName'] ?? json['topic'] ?? '',
      description: json['description'] ?? '',
      level: TopicLevel.values.firstWhere(
        (e) => e.toString() == 'TopicLevel.${json['level']}',
        orElse: () => TopicLevel.BASIC1,
      ),
      category: TopicCategory.values.firstWhere(
        (e) => e.toString() == 'TopicCategory.${json['category']}',
        orElse: () => TopicCategory.general,
      ),
      difficulty: json['difficulty'] ?? 1,
      estimatedWords: json['estimatedWords'] ?? 20,
      iconName: json['iconName'],
      imageUrl: json['imageUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      isKidFriendly: json['isKidFriendly'] ?? true,
      culturalNote: json['culturalNote'],
      learnedWords: json['learnedWords'] ?? 0,
      totalWords: json['totalWords'] ?? 0,
      progressPercentage: (json['progressPercentage'] ?? 0.0).toDouble(),
      lastStudied: json['lastStudied'] != null 
        ? DateTime.parse(json['lastStudied'])
        : null,
      studyStreak: json['studyStreak'] ?? 0,
      groupId: json['groupId'],
      groupName: json['groupName'],
      orderInGroup: json['orderInGroup'],
    );
  }

  // Create a copy with updated values
  Topic copyWith({
    String? id,
    String? topic,
    String? displayName,
    String? description,
    TopicLevel? level,
    TopicCategory? category,
    int? difficulty,
    int? estimatedWords,
    String? iconName,
    String? imageUrl,
    List<String>? tags,
    bool? isKidFriendly,
    String? culturalNote,
    int? learnedWords,
    int? totalWords,
    double? progressPercentage,
    DateTime? lastStudied,
    int? studyStreak,
    String? groupId,
    String? groupName,
    int? orderInGroup,
  }) {
    return Topic(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      level: level ?? this.level,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      estimatedWords: estimatedWords ?? this.estimatedWords,
      iconName: iconName ?? this.iconName,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      culturalNote: culturalNote ?? this.culturalNote,
      learnedWords: learnedWords ?? this.learnedWords,
      totalWords: totalWords ?? this.totalWords,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      lastStudied: lastStudied ?? this.lastStudied,
      studyStreak: studyStreak ?? this.studyStreak,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      orderInGroup: orderInGroup ?? this.orderInGroup,
    );
  }

  // Helper methods
  bool get isCompleted => progressPercentage >= 1.0;
  bool get isStarted => learnedWords > 0;
  bool get isBasicLevel => level.toString().contains('BASIC');
  bool get isAdvancedLevel => level.toString().contains('ADVANCED');
  
  String get levelDisplayName {
    switch (level) {
      case TopicLevel.BASIC1:
        return 'Cơ bản 1';
      case TopicLevel.BASIC2:
        return 'Cơ bản 2';
      case TopicLevel.BASIC3:
        return 'Cơ bản 3';
      case TopicLevel.ADVANCED1:
        return 'Nâng cao 1';
      case TopicLevel.ADVANCED2:
        return 'Nâng cao 2';
      case TopicLevel.ADVANCED3:
        return 'Nâng cao 3';
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case TopicCategory.education:
        return 'Giáo dục';
      case TopicCategory.family:
        return 'Gia đình';
      case TopicCategory.visual:
        return 'Hình ảnh';
      case TopicCategory.math:
        return 'Toán học';
      case TopicCategory.physical:
        return 'Cơ thể';
      case TopicCategory.food:
        return 'Thức ăn';
      case TopicCategory.animals:
        return 'Động vật';
      case TopicCategory.social:
        return 'Xã hội';
      case TopicCategory.academic:
        return 'Học thuật';
      case TopicCategory.general:
        return 'Tổng hợp';
    }
  }

  // Factory method to create topic from dictionary words
  factory Topic.fromWords(String topicName, List<dWord> words) {
    if (words.isEmpty) {
      return Topic(
        id: topicName,
        topic: topicName,
        displayName: _getDisplayName(topicName),
        level: _determineLevel(topicName),
        category: _determineCategory(topicName),
      );
    }

    final firstWord = words.first;
    final learnedCount = words.where((w) => w.reviewCount > 0).length;
    
    return Topic(
      id: topicName,
      topic: topicName,
      displayName: _getDisplayName(topicName),
      description: _getDescription(topicName),
      level: firstWord.level.toTopicLevel(),
      category: _determineCategory(topicName),
      difficulty: _calculateDifficulty(words),
      estimatedWords: words.length,
      tags: _generateTags(topicName),
      isKidFriendly: words.every((w) => w.isKidFriendly),
      learnedWords: learnedCount,
      totalWords: words.length,
      progressPercentage: words.isNotEmpty ? learnedCount / words.length : 0.0,
      lastStudied: _getLastStudied(words),
    );
  }

  // Helper methods for factory
  static String _getDisplayName(String topicName) {
    const displayNames = {
      'schools': 'Trường học',
      'family': 'Gia đình',
      'colors': 'Màu sắc',
      'numbers': 'Số đếm',
      'body': 'Cơ thể',
      'food': 'Thức ăn',
      'animals': 'Động vật',
      'examination': 'Kiểm tra',
      'classroom': 'Lớp học',
      'universities': 'Đại học',
      'school subjects': 'Môn học',
      'extracurricular': 'Ngoại khóa',
      'relationships': 'Mối quan hệ',
      'characteristics': 'Tính cách',
      'appearance': 'Ngoại hình',
      'age': 'Tuổi tác',
      'feelings': 'Cảm xúc',
      'weather': 'Thời tiết',
      'transportation': 'Giao thông',
      'shapes': 'Hình dạng',
      'ordinal numbers': 'Số thứ tự',
      'days of the week': 'Thứ trong tuần',
      'school stationery': 'Dụng cụ học tập',
    };
    return displayNames[topicName] ?? topicName.toUpperCase();
  }

  static String _getDescription(String topicName) {
    const descriptions = {
      'schools': 'Từ vựng về trường học và giáo dục',
      'family': 'Từ vựng về gia đình và người thân',
      'colors': 'Các màu sắc cơ bản',
      'numbers': 'Số đếm từ 1 đến 10',
      'body': 'Các bộ phận cơ thể',
      'food': 'Thức ăn và đồ uống',
      'animals': 'Động vật quen thuộc',
    };
    return descriptions[topicName] ?? 'Từ vựng chủ đề $topicName';
  }

  static TopicLevel _determineLevel(String topicName) {
    const basicTopics1 = ['schools', 'family', 'colors'];
    const basicTopics2 = ['numbers', 'body', 'examination'];
    const basicTopics3 = ['classroom', 'food', 'animals'];
    
    if (basicTopics1.contains(topicName)) return TopicLevel.BASIC1;
    if (basicTopics2.contains(topicName)) return TopicLevel.BASIC2;
    if (basicTopics3.contains(topicName)) return TopicLevel.BASIC3;
    
    return TopicLevel.ADVANCED1;
  }

  static TopicCategory _determineCategory(String topicName) {
    const categories = {
      'schools': TopicCategory.education,
      'classroom': TopicCategory.education,
      'examination': TopicCategory.education,
      'family': TopicCategory.family,
      'relationships': TopicCategory.family,
      'colors': TopicCategory.visual,
      'shapes': TopicCategory.visual,
      'numbers': TopicCategory.math,
      'body': TopicCategory.physical,
      'food': TopicCategory.food,
      'animals': TopicCategory.animals,
    };
    return categories[topicName] ?? TopicCategory.general;
  }

  static int _calculateDifficulty(List<dWord> words) {
    if (words.isEmpty) return 1;
    final avgDifficulty = words.map((w) => w.difficulty).reduce((a, b) => a + b) / words.length;
    return avgDifficulty.round().clamp(1, 5);
  }

  static List<String> _generateTags(String topicName) {
    return [topicName, 'vocabulary', 'learning'];
  }

  static DateTime? _getLastStudied(List<dWord> words) {
    final studiedWords = words.where((w) => w.lastReviewed != null);
    if (studiedWords.isEmpty) return null;
    
    return studiedWords
        .map((w) => w.lastReviewed!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  @override
  String toString() {
    return 'Topic(id: $id, topic: $topic, level: $level, progress: ${(progressPercentage * 100).toInt()}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Topic && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Extension to convert WordLevel to TopicLevel
extension WordLevelExtension on WordLevel {
  TopicLevel toTopicLevel() {
    switch (this) {
      case WordLevel.BASIC:
      case WordLevel.BASIC1:
        return TopicLevel.BASIC1;
      case WordLevel.BASIC2:
        return TopicLevel.BASIC2;
      case WordLevel.BASIC3:
        return TopicLevel.BASIC3;
      case WordLevel.ADVANCED:
      case WordLevel.ADVANCED1:
        return TopicLevel.ADVANCED1;
      case WordLevel.ADVANCED2:
        return TopicLevel.ADVANCED2;
      case WordLevel.ADVANCED3:
        return TopicLevel.ADVANCED3;
    }
  }
}