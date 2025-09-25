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
      // Exact iconName matches (from topics.json)
      'waving_hand': Icons.waving_hand,
      'family_restroom': Icons.family_restroom,
      'numbers': Icons.numbers,
      'palette': Icons.palette,
      'calendar_today': Icons.calendar_today,
      'wb_sunny': Icons.wb_sunny,
      'accessibility': Icons.accessibility,
      'checkroom': Icons.checkroom,
      'fastfood': Icons.fastfood,
      'pets': Icons.pets,
      'home': Icons.home,
      'school': Icons.school,
      'class': Icons.class_,
      'directions_run': Icons.directions_run,
      'mood': Icons.mood,
      'directions_car': Icons.directions_car,
      'location_city': Icons.location_city,
      'access_time': Icons.access_time,
      'sports_esports': Icons.sports_esports,
      'format_size': Icons.format_size,
      'place': Icons.place,
      'schedule': Icons.schedule,
      'health_and_safety': Icons.health_and_safety,
      'shopping_cart': Icons.shopping_cart,
      'nature': Icons.nature,
      'book': Icons.book,
      'quiz': Icons.quiz,
      'time': Icons.access_time,
      'map': Icons.map,
      'devices': Icons.devices,
      'wifi': Icons.wifi,
      'flight': Icons.flight,
      'restaurant': Icons.restaurant,
      'kitchen': Icons.kitchen,
      'fitness_center': Icons.fitness_center,
      'music_note': Icons.music_note,
      'movie': Icons.movie,
      'menu_book': Icons.menu_book,
      'psychology': Icons.psychology,
      'favorite': Icons.favorite,
      'group': Icons.group,
      'eco': Icons.eco,
      'local_hospital': Icons.local_hospital,
      'shopping_bag': Icons.shopping_bag,
      'account_balance': Icons.account_balance,
      'apartment': Icons.apartment,
      'local_post_office': Icons.local_post_office,
      'emergency': Icons.emergency,
      'compare_arrows': Icons.compare_arrows,
      'rule': Icons.rule,
      'extension': Icons.extension,
      'lightbulb': Icons.lightbulb,
      'chat': Icons.chat,
      'celebration': Icons.celebration,
      'festival': Icons.festival,
      'forum': Icons.forum,
      'contact_support': Icons.contact_support,
      'thumbs_up_down': Icons.thumbs_up_down,
      'auto_stories': Icons.auto_stories,
      'event': Icons.event,
      'alt_route': Icons.alt_route,
      'swap_horiz': Icons.swap_horiz,
      'record_voice_over': Icons.record_voice_over,
      'article': Icons.article,
      'medical_services': Icons.medical_services,
      'science': Icons.science,
      'hearing': Icons.hearing,
      'error': Icons.error,
      'analytics': Icons.analytics,
      'translate': Icons.translate,
      'language': Icons.language,
      'newspaper': Icons.newspaper,
      'campaign': Icons.campaign,
      'supervisor_account': Icons.supervisor_account,
      'handshake': Icons.handshake,
      'gavel': Icons.gavel,
      'psychology_alt': Icons.psychology_alt,
    };

    const categoryIconMap = {
      'communication': Icons.forum,
      'family': Icons.family_restroom,
      'math': Icons.numbers,
      'visual': Icons.palette,
      'time': Icons.access_time,
      'nature': Icons.nature,
      'physical': Icons.accessibility,
      'food': Icons.fastfood,
      'animals': Icons.pets,
      'home': Icons.home,
      'education': Icons.school,
      'grammar': Icons.rule,
      'emotions': Icons.mood,
      'transport': Icons.directions_car,
      'places': Icons.location_city,
      'daily_life': Icons.schedule,
      'health': Icons.health_and_safety,
      'economics': Icons.shopping_cart,
      'culture': Icons.public,
      'personal': Icons.badge,
      'navigation': Icons.map,
      'technology': Icons.devices,
      'travel': Icons.flight,
      'sports': Icons.fitness_center,
      'entertainment': Icons.movie,
      'personality': Icons.psychology,
      'social': Icons.group,
      'environment': Icons.eco,
      'medicine': Icons.medical_services,
      'psychology': Icons.psychology,
      'philosophy': Icons.psychology_alt,
      'arts': Icons.palette,
      'law': Icons.gavel,
      'business': Icons.business,
      'academic': Icons.article,
      'media': Icons.newspaper,
      'marketing': Icons.campaign,
      'management': Icons.supervisor_account,
      'diplomacy': Icons.handshake,
      'expressions': Icons.lightbulb,
      'language': Icons.translate,
      'global': Icons.public,
      'futurism': Icons.trending_up,
      'literature': Icons.auto_stories,
      'music': Icons.music_note,
      'culinary': Icons.restaurant,
      'fashion': Icons.checkroom,
      'society': Icons.location_city,
      'tradition': Icons.agriculture,
      'linguistics': Icons.language,
      'pronunciation': Icons.record_voice_over,
      'assessment': Icons.quiz,
    };

    // Prefer explicit iconName mapping
    final direct = iconMap[iconName];
    if (direct != null) return direct;

    // Fallback to category-based icon
    final byCategory = categoryIconMap[category.toLowerCase()];
    if (byCategory != null) return byCategory;

    // Level-based fallback
    switch (level.toUpperCase()) {
      case 'BASIC':
        return Icons.star;
      case 'INTERMEDIATE':
        return Icons.trending_up;
      case 'ADVANCED':
        return Icons.emoji_events;
      default:
        return Icons.book;
    }
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
