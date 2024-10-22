// word repository class
import 'package:bvo/model/word.dart';
import 'package:bvo/repository/dictionary.dart';

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
}
