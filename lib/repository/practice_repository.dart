import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/practice_question.dart';

class PracticeRepository {
  static const String _questionsKey = 'practice_questions';
  static const String _answersKey = 'practice_answers_';
  
  /// Save questions list
  Future<void> saveQuestions(List<PracticeQuestion> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final questionsJson = questions.map((q) => q.toJson()).toList();
    await prefs.setString(_questionsKey, jsonEncode(questionsJson));
  }
  
  /// Load questions list
  Future<List<PracticeQuestion>> loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final questionsJson = prefs.getString(_questionsKey);
    
    if (questionsJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(questionsJson);
      return decoded.map((json) => PracticeQuestion.fromJson(json)).toList();
    } catch (e) {
      print('Error loading questions: $e');
      return [];
    }
  }
  
  /// Save user answers for a question
  Future<void> saveAnswer(String questionId, List<String> userAnswers) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_answersKey$questionId';
    await prefs.setString(key, jsonEncode(userAnswers));
  }
  
  /// Load user answers for a question
  Future<List<String>> loadAnswer(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_answersKey$questionId';
    final answersJson = prefs.getString(key);
    
    if (answersJson == null) {
      return [];
    }
    
    try {
      return List<String>.from(jsonDecode(answersJson));
    } catch (e) {
      print('Error loading answer: $e');
      return [];
    }
  }
  
  /// Load all answers
  Future<Map<String, List<String>>> loadAllAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final answerKeys = allKeys.where((key) => key.startsWith(_answersKey)).toList();
    
    final Map<String, List<String>> answers = {};
    
    for (final key in answerKeys) {
      final questionId = key.substring(_answersKey.length);
      final answersJson = prefs.getString(key);
      
      if (answersJson != null) {
        try {
          answers[questionId] = List<String>.from(jsonDecode(answersJson));
        } catch (e) {
          print('Error loading answer for $questionId: $e');
        }
      }
    }
    
    return answers;
  }
  
  /// Clear answer for a question (for re-do)
  Future<void> clearAnswer(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_answersKey$questionId';
    await prefs.remove(key);
  }
  
  /// Clear all answers
  Future<void> clearAllAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final answerKeys = allKeys.where((key) => key.startsWith(_answersKey)).toList();
    
    for (final key in answerKeys) {
      await prefs.remove(key);
    }
  }
  
  /// Clear all questions
  Future<void> clearAllQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_questionsKey);
  }
  
  /// Clear answers for specific question IDs (for a reading)
  Future<void> clearAnswersForQuestions(List<String> questionIds) async {
    final prefs = await SharedPreferences.getInstance();
    for (final questionId in questionIds) {
      final key = '$_answersKey$questionId';
      await prefs.remove(key);
    }
  }
}

