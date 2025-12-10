import '../model/word.dart';
import 'level_vocabulary_loader.dart';

/// Service to load vocabulary data from level txt files and map with database
class VocabularyDataLoader {
  static final VocabularyDataLoader _instance = VocabularyDataLoader._internal();
  factory VocabularyDataLoader() => _instance;
  VocabularyDataLoader._internal();

  final LevelVocabularyLoader _levelLoader = LevelVocabularyLoader();

  // Cache for loaded data
  List<dWord>? _allWords;
  List<dWord>? _basicWords;
  List<dWord>? _intermediateWords;
  List<dWord>? _advancedWords;

  /// Get all vocabulary words
  Future<List<dWord>> getAllWords() async {
    if (_allWords != null) {
      print('getAllWords: returning cached list of \'${_allWords!.length}\' words');
      return _allWords!;
    }

    // Load from level txt files and map with database
    print('getAllWords: loading from level txt files (1.1-1.5, 2.0) and mapping with database');
    final words = await _levelLoader.getAllWords();

    print('getAllWords: loaded total \'${words.length}\' words (before caching)');
    _allWords = words;
    return _allWords!;
  }

  /// Get basic level words
  Future<List<dWord>> getBasicWords() async {
    if (_basicWords != null) {
      print('getBasicWords: returning cached list of \'${_basicWords!.length}\' words');
      return _basicWords!;
    }
    final words = await _levelLoader.getBasicWords();
    _basicWords = words;
    print('getBasicWords: loaded \'${_basicWords!.length}\' words from level 1.1-1.5');
    return _basicWords!;
  }

  /// Get intermediate level words
  Future<List<dWord>> getIntermediateWords() async {
    if (_intermediateWords != null) {
      print('getIntermediateWords: returning cached list of \'${_intermediateWords!.length}\' words');
      return _intermediateWords!;
    }
    final words = await _levelLoader.getIntermediateWords();
    _intermediateWords = words;
    print('getIntermediateWords: loaded \'${_intermediateWords!.length}\' words from level 2.0');
    return _intermediateWords!;
  }

  /// Get advanced level words
  Future<List<dWord>> getAdvancedWords() async {
    if (_advancedWords != null) {
      print('getAdvancedWords: returning cached list of \'${_advancedWords!.length}\' words');
      return _advancedWords!;
    }
    final words = await _levelLoader.getAdvancedWords();
    _advancedWords = words;
    print('getAdvancedWords: loaded \'${_advancedWords!.length}\' words');
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

  /// Get words by topic (topic is the level like "1.1", "1.2", etc.)
  Future<List<dWord>> getWordsByTopic(String topic) async {
    return await _levelLoader.getWordsByTopic(topic);
  }

  /// Get words by difficulty
  Future<List<dWord>> getWordsByDifficulty(int difficulty) async {
    final allWords = await getAllWords();
    return allWords.where((word) => word.difficulty == difficulty).toList();
  }

  /// Get all available topics (levels)
  Future<List<String>> getAllTopics() async {
    return await _levelLoader.getAllTopics();
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    return await _levelLoader.getStatistics();
  }


  /// Clear cache (useful for hot reload or data updates)
  void clearCache() {
    _allWords = null;
    _basicWords = null;
    _intermediateWords = null;
    _advancedWords = null;
    _levelLoader.clearCache();
    print('VocabularyDataLoader: caches cleared');
  }
}