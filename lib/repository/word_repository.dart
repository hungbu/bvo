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
    return await getDictionary(topic);
  }

  Future<List<Word>> getDictionary(String topic) async {
    List<dynamic> dictionary = await loadDictionary(topic);
    List<Word> words = dictionary.map((e) => Word.fromJson(e)).toList();
    return words;
  }

  Future<List<dynamic>> loadDictionary(String topic) async {
    // filter dictionary by topic
    final result = dictionary.where((e) => e['topic'] == topic).toList();
    return result;
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
