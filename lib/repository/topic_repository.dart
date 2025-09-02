import 'dart:convert';

import 'package:bvo/model/topic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bvo/repository/dictionary.dart';

class TopicRepository {
  static const String _cachedTopicsKey = 'cached_topics';

  Future<List<Topic>> getTopics() async {
    try {
      print("TopicRepository: Starting getTopics()");
      
      // Always generate from dictionary first (for fresh data)
      final topics = await _generateTopicsFromDictionary();
      
      if (topics.isNotEmpty) {
        // Cache the generated topics
        await _cacheTopics(topics);
        print("TopicRepository: Successfully generated and cached ${topics.length} topics");
        return topics;
      }

      // If generation fails, try to get from cache as fallback
      print("TopicRepository: Generation failed, trying cache...");
      final cachedTopics = await _getTopicsFromCache();
      return cachedTopics;
      
    } catch (e) {
      print("Error getting topics: $e");
      return <Topic>[];
    }
  }

  Future<List<Topic>> _generateTopicsFromDictionary() async {
    try {
      print("TopicRepository: Accessing dictionary with ${dictionary.length} words");
      
      // Get unique topics from dictionary with explicit type casting
      final Set<String> uniqueTopicNames = dictionary
          .map((word) => word['topic'] as String?)
          .where((topic) => topic != null && topic.isNotEmpty)
          .cast<String>()
          .toSet();

      print("TopicRepository: Found ${uniqueTopicNames.length} unique topic names");

      final List<Topic> uniqueTopics = uniqueTopicNames
          .map((topicName) => Topic(id: topicName, topic: topicName))
          .toList();

      print("Generated ${uniqueTopics.length} topics from dictionary");
      return uniqueTopics;
    } catch (e) {
      print("Error generating topics from dictionary: $e");
      return <Topic>[];
    }
  }

  Future<void> _cacheTopics(List<Topic> topics) async {
    final prefs = await SharedPreferences.getInstance();
    final topicsJson = topics.map((topic) => topic.toJson()).toList();
    await prefs.setStringList(_cachedTopicsKey,
        topicsJson.map((e) => jsonEncode(e)).toList());
  }

  Future<List<Topic>> _getTopicsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final topicsJson = prefs.getStringList(_cachedTopicsKey);

    if (topicsJson != null) {
      try {
        return topicsJson.map((e) => Topic.fromJson(jsonDecode(e))).toList();
      } catch (e) {
        print("Error parsing cached topics: $e");
        return [];
      }
    } else {
      return [];
    }
  }

  Future<void> clearLocalTopicCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedTopicsKey);
  }
}