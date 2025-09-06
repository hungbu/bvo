enum WordLevel {
  BASIC,
  BASIC1,
  BASIC2,
  BASIC3,
  ADVANCED,
  ADVANCED1,
  ADVANCED2,
  ADVANCED3,
}

enum WordType {
  noun,
  verb,
  adjective,
  adverb,
  preposition,
  conjunction,
  interjection,
  pronoun,
  determiner,
  phrase,
}

class dWord {
  final int? id; // Primary key for database
  final String en; // English word
  final String vi; // Vietnamese translation
  final String sentence; // Example sentence in English
  final String sentenceVi; // Vietnamese translation of sentence
  final String topic; // Topic/category
  final String pronunciation; // IPA pronunciation
  final String? audioUrl; // URL for pronunciation audio
  final WordLevel level; // BASIC or ADVANCED ( or BASIC1, BASIC2, BASIC3 ...)
  final WordType type; // noun, verb, adjective, etc.
  final List<String> synonyms; // Synonyms in English
  final List<String> antonyms; // Antonyms in English
  final String? imageUrl; // Visual aid for better memory
  final int difficulty; // 1-5 difficulty level
  final List<String> tags; // Additional tags for filtering
  
  // Learning progress tracking
  final int reviewCount;
  final DateTime nextReview;
  final double masteryLevel; // 0.0 - 1.0 (0% - 100%)
  final DateTime? lastReviewed;
  final int correctAnswers;
  final int totalAttempts;
  
  // Spaced repetition intervals (in days)
  final int currentInterval;
  final double easeFactor; // For spaced repetition algorithm
  
  // Age-appropriate features
  final bool isKidFriendly; // Safe for children
  final String? mnemonicTip; // Memory aid in Vietnamese
  final String? culturalNote; // Cultural context for Vietnamese learners

  const dWord({
    this.id,
    required this.en,
    required this.vi,
    required this.sentence,
    required this.sentenceVi,
    required this.topic,
    required this.pronunciation,
    this.audioUrl,
    required this.level,
    required this.type,
    this.synonyms = const [],
    this.antonyms = const [],
    this.imageUrl,
    required this.difficulty,
    this.tags = const [],
    this.reviewCount = 0,
    required this.nextReview,
    this.masteryLevel = 0.0,
    this.lastReviewed,
    this.correctAnswers = 0,
    this.totalAttempts = 0,
    this.currentInterval = 1,
    this.easeFactor = 2.5,
    this.isKidFriendly = true,
    this.mnemonicTip,
    this.culturalNote,
  });

  factory dWord.fromJson(Map<String, dynamic> json) {
    return dWord(
      id: json['id'],
      en: json['en'] ?? '',
      vi: json['vi'] ?? '',
      sentence: json['sentence'] ?? '',
      sentenceVi: json['sentenceVi'] ?? '',
      topic: json['topic'] ?? '',
      pronunciation: json['pronunciation'] ?? '',
      audioUrl: json['audioUrl'],
      level: WordLevel.values.firstWhere(
        (e) => e.toString() == 'WordLevel.${json['level']}',
        orElse: () => WordLevel.BASIC,
      ),
      type: WordType.values.firstWhere(
        (e) => e.toString() == 'WordType.${json['type']}',
        orElse: () => WordType.noun,
      ),
      synonyms: List<String>.from(json['synonyms'] ?? []),
      antonyms: List<String>.from(json['antonyms'] ?? []),
      imageUrl: json['imageUrl'],
      difficulty: json['difficulty'] ?? 1,
      tags: List<String>.from(json['tags'] ?? []),
      reviewCount: json['reviewCount'] ?? 0,
      nextReview: json['nextReview'] != null 
        ? DateTime.parse(json['nextReview'])
        : DateTime.now().add(const Duration(days: 1)),
      masteryLevel: (json['masteryLevel'] ?? 0.0).toDouble(),
      lastReviewed: json['lastReviewed'] != null 
        ? DateTime.parse(json['lastReviewed'])
        : null,
      correctAnswers: json['correctAnswers'] ?? 0,
      totalAttempts: json['totalAttempts'] ?? 0,
      currentInterval: json['currentInterval'] ?? 1,
      easeFactor: (json['easeFactor'] ?? 2.5).toDouble(),
      isKidFriendly: json['isKidFriendly'] ?? true,
      mnemonicTip: json['mnemonicTip'],
      culturalNote: json['culturalNote'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'en': en,
      'vi': vi,
      'sentence': sentence,
      'sentenceVi': sentenceVi,
      'topic': topic,
      'pronunciation': pronunciation,
      'audioUrl': audioUrl,
      'level': level.toString().split('.').last,
      'type': type.toString().split('.').last,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'imageUrl': imageUrl,
      'difficulty': difficulty,
      'tags': tags,
      'reviewCount': reviewCount,
      'nextReview': nextReview.toIso8601String(),
      'masteryLevel': masteryLevel,
      'lastReviewed': lastReviewed?.toIso8601String(),
      'correctAnswers': correctAnswers,
      'totalAttempts': totalAttempts,
      'currentInterval': currentInterval,
      'easeFactor': easeFactor,
      'isKidFriendly': isKidFriendly,
      'mnemonicTip': mnemonicTip,
      'culturalNote': culturalNote,
    };
  }

  dWord copyWith({
    int? id,
    String? en,
    String? vi,
    String? sentence,
    String? sentenceVi,
    String? topic,
    String? pronunciation,
    String? audioUrl,
    WordLevel? level,
    WordType? type,
    List<String>? synonyms,
    List<String>? antonyms,
    String? imageUrl,
    int? difficulty,
    List<String>? tags,
    int? reviewCount,
    DateTime? nextReview,
    double? masteryLevel,
    DateTime? lastReviewed,
    int? correctAnswers,
    int? totalAttempts,
    int? currentInterval,
    double? easeFactor,
    bool? isKidFriendly,
    String? mnemonicTip,
    String? culturalNote,
  }) {
    return dWord(
      id: id ?? this.id,
      en: en ?? this.en,
      vi: vi ?? this.vi,
      sentence: sentence ?? this.sentence,
      sentenceVi: sentenceVi ?? this.sentenceVi,
      topic: topic ?? this.topic,
      pronunciation: pronunciation ?? this.pronunciation,
      audioUrl: audioUrl ?? this.audioUrl,
      level: level ?? this.level,
      type: type ?? this.type,
      synonyms: synonyms ?? this.synonyms,
      antonyms: antonyms ?? this.antonyms,
      imageUrl: imageUrl ?? this.imageUrl,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      reviewCount: reviewCount ?? this.reviewCount,
      nextReview: nextReview ?? this.nextReview,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      currentInterval: currentInterval ?? this.currentInterval,
      easeFactor: easeFactor ?? this.easeFactor,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      mnemonicTip: mnemonicTip ?? this.mnemonicTip,
      culturalNote: culturalNote ?? this.culturalNote,
    );
  }

  @override
  String toString() {
    return 'dWord(en: $en, vi: $vi, topic: $topic, level: $level, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is dWord && other.en == en && other.topic == topic;
  }

  @override
  int get hashCode => en.hashCode ^ topic.hashCode;
}

// Backward compatibility - create a typedef for the old Word class
typedef Word = dWord;