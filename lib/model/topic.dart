import 'package:flutter/material.dart';

/// Essential topic data that should be stored in topics.json
class TopicEssentials {
  final String id;              // unique identifier
  final String name;            // display name (e.g., "Trường học")
  final String iconName;        // icon identifier (e.g., "school")
  final String colorHex;        // color hex (e.g., "#2196F3")
  final int difficulty;         // 1-5 difficulty level
  final String? description;    // optional description
  final String category;        // category (e.g., "education")
  final String level;           // level (e.g., "BASIC")

  const TopicEssentials({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.difficulty,
    this.description,
    required this.category,
    required this.level,
  });

  factory TopicEssentials.fromJson(Map<String, dynamic> json) {
    return TopicEssentials(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      iconName: json['iconName'] ?? 'book',
      colorHex: json['colorHex'] ?? '#2196F3',
      difficulty: json['difficulty'] ?? 1,
      description: json['description'],
      category: json['category'] ?? 'general',
      level: json['level'] ?? 'BASIC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
      'difficulty': difficulty,
      'description': description,
      'category': category,
      'level': level,
    };
  }
}

/// Complete topic with calculated data
class Topic {
  // Essential data (from topics.json)
  final TopicEssentials essentials;
  
  // Calculated data (computed from words)
  final int totalWords;
  final int learnedWords;
  final double progressPercentage;
  final String estimatedTime;
  final DateTime? lastStudied;

  const Topic({
    required this.essentials,
    this.totalWords = 0,
    this.learnedWords = 0,
    this.progressPercentage = 0.0,
    this.estimatedTime = '0 min',
    this.lastStudied,
  });

  // Convenience getters
  String get id => essentials.id;
  String get name => essentials.name;
  String get iconName => essentials.iconName;
  String get colorHex => essentials.colorHex;
  int get difficulty => essentials.difficulty;
  String? get description => essentials.description;
  String get category => essentials.category;
  String get level => essentials.level;

  // Helper methods
  bool get isCompleted => progressPercentage >= 1.0;
  bool get isStarted => learnedWords > 0;
  
  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue; // fallback
    }
  }

  IconData get icon {
    const iconMap = {
      'school': Icons.school,
      'family': Icons.family_restroom,
      'pets': Icons.pets,
      'fastfood': Icons.fastfood,
      'drink': Icons.local_drink,
      'checkroom': Icons.checkroom,
      'sunny': Icons.wb_sunny,
      'palette': Icons.palette,
      'numbers': Icons.numbers,
      'time': Icons.access_time,
      'quiz': Icons.quiz,
      'book': Icons.book,
      'map': Icons.map,
    };
    return iconMap[iconName] ?? Icons.book;
  }

  Topic copyWith({
    TopicEssentials? essentials,
    int? totalWords,
    int? learnedWords,
    double? progressPercentage,
    String? estimatedTime,
    DateTime? lastStudied,
  }) {
    return Topic(
      essentials: essentials ?? this.essentials,
      totalWords: totalWords ?? this.totalWords,
      learnedWords: learnedWords ?? this.learnedWords,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      lastStudied: lastStudied ?? this.lastStudied,
    );
  }

  @override
  String toString() {
    return 'Topic(id: $id, name: $name, progress: ${(progressPercentage * 100).toInt()}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Topic && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
