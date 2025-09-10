import '../model/word.dart';
import '../service/vocabulary_data_loader.dart';

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
  Future<List<dWord>> searchWords(String query) async {
    final allWords = await getAllWords();
    final lowercaseQuery = query.toLowerCase();
    
    return allWords.where((word) {
      return word.en.toLowerCase().contains(lowercaseQuery) ||
             word.vi.toLowerCase().contains(lowercaseQuery);
    }).toList();
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
      word.nextReview != null && word.nextReview!.isBefore(DateTime.now())
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

  /// Get words of a specific topic (alias for getWordsByTopic)
  Future<List<dWord>> getWordsOfTopic(String topic) async {
    return await getWordsByTopic(topic);
  }

  /// Load words for a topic (alias for getWordsByTopic)
  Future<List<dWord>> loadWords(String topic) async {
    return await getWordsByTopic(topic);
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