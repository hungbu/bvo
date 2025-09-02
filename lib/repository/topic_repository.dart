import 'dart:convert';

import 'package:bvo/model/topic.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopicRepository {
  final CollectionReference _topicsCollection =
      FirebaseFirestore.instance.collection('topics');
  static const String _cachedTopicsKey = 'cached_topics';

  Future<List<Topic>> getTopics() async {
    try {
      // Try fetching from Firestore
      final snapshot = await _topicsCollection.get();
      final topics = snapshot.docs
          .map((doc) => Topic.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Cache the fetched data locally
      await _cacheTopics(topics);

      return topics;
    } catch (e) {
      // If Firestore fetch fails, try fetching from local cache
      print("Error fetching from Firestore: $e");
      return await _getTopicsFromCache();
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