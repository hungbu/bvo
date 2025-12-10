import '../model/word.dart';
import '../service/vocabulary_data_loader.dart';
import 'dictionary_words_repository.dart';

/// Repository for word-related operations using direct data loading
class WordRepository {
  final VocabularyDataLoader _dataLoader = VocabularyDataLoader();

  /// Get all words
  Future<List<dWord>> getAllWords() async {
    return await _dataLoader.getAllWords();
  }

  /// Get words by level
  Future<List<dWord>> getWordsByLevel(WordLevel level) async {
    return await _dataLoader.getWordsByLevel(level);
  }

  /// Get basic level words
  Future<List<dWord>> getBasicWords() async {
    return await _dataLoader.getBasicWords();
  }

  /// Get intermediate level words
  Future<List<dWord>> getIntermediateWords() async {
    return await _dataLoader.getIntermediateWords();
  }

  /// Get advanced level words
  Future<List<dWord>> getAdvancedWords() async {
    return await _dataLoader.getAdvancedWords();
  }

  /// Get words by topic
  Future<List<dWord>> getWordsByTopic(String topic) async {
    return await _dataLoader.getWordsByTopic(topic);
  }

  /// Get words by difficulty
  Future<List<dWord>> getWordsByDifficulty(int difficulty) async {
    return await _dataLoader.getWordsByDifficulty(difficulty);
  }

  /// Get all available topics
  Future<List<String>> getAllTopics() async {
    return await _dataLoader.getAllTopics();
  }

  /// Get word statistics
  Future<Map<String, dynamic>> getStatistics() async {
    return await _dataLoader.getStatistics();
  }

  /// Search words by English or Vietnamese text
  /// Query database directly (not from JSON) for search functionality
  Future<List<dWord>> searchWords(String query) async {
    // Query database directly for search (not from JSON)
    final dbRepo = DictionaryWordsRepository();
    final words = await dbRepo.searchWord(query);
    // Convert Word to dWord (they are the same type, just return as-is)
    return words;
  }

  /// Get words sorted by difficulty (ascending)
  Future<List<dWord>> getWordsSortedByDifficulty({WordLevel? level}) async {
    List<dWord> words;
    if (level != null) {
      words = await getWordsByLevel(level);
    } else {
      words = await getAllWords();
    }
    
    // Words are already sorted by difficulty in VocabularyDataLoader
    // But we'll sort again to ensure consistency
    words.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
    
    return words;
  }

  /// Get words by topic sorted by difficulty
  Future<List<dWord>> getWordsByTopicSortedByDifficulty(String topic) async {
    final words = await getWordsByTopic(topic);
    
    words.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
    
    return words;
  }

  /// Get random words for practice
  Future<List<dWord>> getRandomWords(int count, {WordLevel? level}) async {
    List<dWord> words;
    
    if (level != null) {
      words = await getWordsByLevel(level);
    } else {
      words = await getAllWords();
    }
    
    if (words.length <= count) return words;
    
    words.shuffle();
    return words.take(count).toList();
  }

  /// Get reviewed words grouped by topic (for compatibility)
  Future<Map<String, List<dWord>>> getReviewedWordsGroupedByTopic() async {
    final allWords = await getAllWords();
    final reviewedWords = allWords.where((word) => 
      word.nextReview.isBefore(DateTime.now())
    ).toList();
    
    final grouped = <String, List<dWord>>{};
    for (final word in reviewedWords) {
      if (!grouped.containsKey(word.topic)) {
        grouped[word.topic] = [];
      }
      grouped[word.topic]!.add(word);
    }
    
    return grouped;
  }

  /// Get words of a specific topic (alias for getWordsByTopicSortedByDifficulty)
  Future<List<dWord>> getWordsOfTopic(String topic) async {
    return await getWordsByTopicSortedByDifficulty(topic);
  }

  /// Load words for a topic (alias for getWordsByTopicSortedByDifficulty)
  Future<List<dWord>> loadWords(String topic) async {
    return await getWordsByTopicSortedByDifficulty(topic);
  }

  /// Save words (placeholder - in JSON system, this would need special handling)
  Future<void> saveWords(String topic, List<dWord> words) async {
    // In the JSON-based system, saving would require writing back to assets
    // For now, this is a placeholder that does nothing
    // In a real implementation, you might want to save to local storage
    print('Note: saveWords called for topic $topic with ${words.length} words');
    print('In JSON-based system, consider implementing local storage for user modifications');
  }


  /// Clear cache (useful for data updates)
  void clearCache() {
    _dataLoader.clearCache();
  }
}