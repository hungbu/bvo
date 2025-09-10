// word repository class
import 'dart:convert';

import 'package:bvo/model/topic.dart';
import 'package:bvo/model/word.dart';
import 'package:bvo/repository/dictionary.dart';
import 'package:bvo/repository/topic_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordRepository {
  // get word
  Future<List<Word>> getWordsOfTopic(String topic) async {
    try {
      // First try to get from local cache
      final cachedWords = await loadWords(topic);
      if (cachedWords.isNotEmpty) {
        return cachedWords;
      }

      // If cache is empty, generate from dictionary data
      return await getDictionary(topic);
    } catch (e) {
      print("Error getting words for topic $topic: $e");
      return [];
    }
  }

  Future<List<Word>> getDictionary(String topic) async {
    try {
      List<dWord> dictionaryWords = await loadDictionary(topic);
      
      // Cache the words automatically
      await saveWords(topic, dictionaryWords);
      
      return dictionaryWords;
    } catch (e) {
      print("Error getting dictionary for topic $topic: $e");
      return [];
    }
  }

  Future<List<dWord>> loadDictionary(String topic) async {
    try {
      // filter dictionary by topic
      final result = dictionary.where((word) => word.topic == topic).toList();
      return result;
    } catch (e) {
      print("Error loading dictionary for topic $topic: $e");
      return [];
    }
  }

  Future<List<Word>> loadWords(String topic) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedWordsJson = prefs.getStringList('words_$topic');
    if (savedWordsJson != null) {
      List<Word> words = [];
      for (var wordJson in savedWordsJson) {
        words.add(Word.fromJson(jsonDecode(wordJson)));
      }
      return words;
    } else {
      // Return default words or an empty list
      return [];
    }
  }

  Future<void> saveWords(String topic, List<Word> words) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> wordsJson =
        words.map((word) => jsonEncode(word.toJson())).toList();
    await prefs.setStringList('words_$topic', wordsJson);
  }

  Future<Map<String, List<Word>>> getReviewedWordsGroupedByTopic() async {
    List<Topic> topics = await TopicRepository().getTopics();
    Map<String, List<Word>> reviewedWordsByTopic = {};

    SharedPreferences prefs = await SharedPreferences.getInstance();

    for (Topic topic in topics) {
      List<String>? savedWordsJson =
          prefs.getStringList('words_${topic.topic}');
      if (savedWordsJson != null) {
        List<Word> words = savedWordsJson
            .map((wordJson) => Word.fromJson(jsonDecode(wordJson)))
            .toList();

        List<Word> reviewedWords =
            words.where((word) => word.reviewCount > 0).toList();

        if (reviewedWords.isNotEmpty) {
          reviewedWordsByTopic[topic.topic] = reviewedWords;
        }
      }
    }
    return reviewedWordsByTopic;
  }
}
