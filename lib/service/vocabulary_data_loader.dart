import 'dart:convert';
import 'package:flutter/services.dart';
import '../model/word.dart';

/// Service to load vocabulary data directly from data files
class VocabularyDataLoader {
  static final VocabularyDataLoader _instance = VocabularyDataLoader._internal();
  factory VocabularyDataLoader() => _instance;
  VocabularyDataLoader._internal();

  // Cache for loaded data
  List<dWord>? _allWords;
  List<dWord>? _basicWords;
  List<dWord>? _intermediateWords;
  List<dWord>? _advancedWords;

  /// Get all vocabulary words
  Future<List<dWord>> getAllWords() async {
    if (_allWords != null) return _allWords!;
    
    final basic = await getBasicWords();
    final intermediate = await getIntermediateWords();
    final advanced = await getAdvancedWords();
    
    _allWords = [...basic, ...intermediate, ...advanced];
    return _allWords!;
  }

  /// Get basic level words
  Future<List<dWord>> getBasicWords() async {
    if (_basicWords != null) return _basicWords!;
    _basicWords = await _loadWordsFromAsset('assets/data/basic_words.json');
    return _basicWords!;
  }

  /// Get intermediate level words
  Future<List<dWord>> getIntermediateWords() async {
    if (_intermediateWords != null) return _intermediateWords!;
    _intermediateWords = await _loadWordsFromAsset('assets/data/intermediate_words.json');
    return _intermediateWords!;
  }

  /// Get advanced level words
  Future<List<dWord>> getAdvancedWords() async {
    if (_advancedWords != null) return _advancedWords!;
    _advancedWords = await _loadWordsFromAsset('assets/data/advanced_words.json');
    return _advancedWords!;
  }

  /// Get words by level
  Future<List<dWord>> getWordsByLevel(WordLevel level) async {
    switch (level) {
      case WordLevel.BASIC:
        return await getBasicWords();
      case WordLevel.INTERMEDIATE:
        return await getIntermediateWords();
      case WordLevel.ADVANCED:
        return await getAdvancedWords();
    }
  }

  /// Get words by topic
  Future<List<dWord>> getWordsByTopic(String topic) async {
    final allWords = await getAllWords();
    return allWords.where((word) => word.topic == topic).toList();
  }

  /// Get words by difficulty
  Future<List<dWord>> getWordsByDifficulty(int difficulty) async {
    final allWords = await getAllWords();
    return allWords.where((word) => word.difficulty == difficulty).toList();
  }

  /// Get all available topics
  Future<List<String>> getAllTopics() async {
    final allWords = await getAllWords();
    return allWords.map((word) => word.topic).toSet().toList()..sort();
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final basic = await getBasicWords();
    final intermediate = await getIntermediateWords();
    final advanced = await getAdvancedWords();
    
    return {
      'total': basic.length + intermediate.length + advanced.length,
      'basic': basic.length,
      'intermediate': intermediate.length,
      'advanced': advanced.length,
      'topics': (await getAllTopics()).length,
    };
  }

  /// Clear cache (useful for hot reload or data updates)
  void clearCache() {
    _allWords = null;
    _basicWords = null;
    _intermediateWords = null;
    _advancedWords = null;
  }

  /// Load words from JSON asset file
  Future<List<dWord>> _loadWordsFromAsset(String assetPath) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => dWord.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading words from $assetPath: $e');
      return [];
    }
  }
}