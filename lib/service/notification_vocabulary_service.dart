import 'dart:math';
import '../model/word.dart';
import '../repository/word_repository.dart';
import '../repository/user_progress_repository.dart';

/// Service để lấy từ vựng cho thông báo
class NotificationVocabularyService {
  final WordRepository _wordRepository = WordRepository();
  final UserProgressRepository _progressRepository = UserProgressRepository();
  
  /// Lấy một từ vựng random để hiển thị trong thông báo
  /// Ưu tiên: từ chưa học -> từ dễ -> từ khó
  Future<dWord?> getRandomWordForNotification() async {
    try {
      // Lấy tất cả từ vựng
      final allWords = await _wordRepository.getAllWords();
      if (allWords.isEmpty) return null;
      
      // Phân loại từ theo trạng thái học tập
      final unlearnedWords = <dWord>[];
      final learnedWords = <dWord>[];
      
      for (final word in allWords) {
        final progress = await _progressRepository.getWordProgress(word.topic, word.en);
        final isLearned = progress['isLearned'] ?? false;
        
        if (isLearned) {
          learnedWords.add(word);
        } else {
          unlearnedWords.add(word);
        }
      }
      
      // Chọn từ theo thứ tự ưu tiên
      List<dWord> candidateWords;
      
      if (unlearnedWords.isNotEmpty) {
        // Ưu tiên từ chưa học, sắp xếp theo độ khó (dễ -> khó)
        candidateWords = unlearnedWords;
        candidateWords.sort((a, b) => a.difficulty.compareTo(b.difficulty));
        
        // Lấy 30% từ dễ nhất để tăng cơ hội chọn từ dễ
        final easyWordsCount = (candidateWords.length * 0.3).ceil();
        candidateWords = candidateWords.take(easyWordsCount).toList();
      } else if (learnedWords.isNotEmpty) {
        // Nếu không có từ chưa học, chọn từ đã học để ôn tập
        candidateWords = learnedWords;
        candidateWords.sort((a, b) => a.difficulty.compareTo(b.difficulty));
      } else {
        // Fallback: chọn từ bất kỳ
        candidateWords = allWords;
      }
      
      // Random chọn một từ từ danh sách ứng viên
      if (candidateWords.isNotEmpty) {
        final random = Random();
        return candidateWords[random.nextInt(candidateWords.length)];
      }
      
      return null;
    } catch (e) {
      print('Error getting random word for notification: $e');
      return null;
    }
  }
  
  /// Lấy từ vựng theo level cụ thể
  Future<dWord?> getRandomWordByLevel(WordLevel level) async {
    try {
      final words = await _wordRepository.getWordsByLevel(level);
      if (words.isEmpty) return null;
      
      // Sắp xếp theo độ khó
      words.sort((a, b) => a.difficulty.compareTo(b.difficulty));
      
      final random = Random();
      return words[random.nextInt(words.length)];
    } catch (e) {
      print('Error getting random word by level: $e');
      return null;
    }
  }
  
  /// Lấy từ vựng từ topic đang học gần nhất
  Future<dWord?> getRandomWordFromRecentTopic() async {
    try {
      // Lấy topic học gần nhất
      final lastTopic = await _progressRepository.getLastTopic();
      
      if (lastTopic != null) {
        final topicWords = await _wordRepository.getWordsByTopic(lastTopic);
        if (topicWords.isNotEmpty) {
          // Ưu tiên từ chưa học trong topic này
          final unlearnedWords = <dWord>[];
          
          for (final word in topicWords) {
            final progress = await _progressRepository.getWordProgress(word.topic, word.en);
            final isLearned = progress['isLearned'] ?? false;
            
            if (!isLearned) {
              unlearnedWords.add(word);
            }
          }
          
          List<dWord> candidateWords = unlearnedWords.isNotEmpty ? unlearnedWords : topicWords;
          candidateWords.sort((a, b) => a.difficulty.compareTo(b.difficulty));
          
          final random = Random();
          return candidateWords[random.nextInt(candidateWords.length)];
        }
      }
      
      // Fallback: lấy từ bất kỳ
      return await getRandomWordForNotification();
    } catch (e) {
      print('Error getting random word from recent topic: $e');
      return await getRandomWordForNotification();
    }
  }
  
  /// Format từ vựng thành chuỗi cho thông báo
  String formatWordForNotification(dWord word, {bool showMeaning = true, bool showPronunciation = false}) {
    final parts = <String>[];
    
    // Thêm từ tiếng Anh
    parts.add(word.en);
    
    // Thêm phát âm nếu yêu cầu
    if (showPronunciation && word.pronunciation.isNotEmpty) {
      parts.add('/${word.pronunciation}/');
    }
    
    // Thêm nghĩa tiếng Việt nếu yêu cầu
    if (showMeaning) {
      parts.add('- ${word.vi}');
    }
    
    return parts.join(' ');
  }
  
  /// Tạo thông báo với từ vựng và câu ví dụ
  Map<String, String> createVocabularyNotification(dWord word, String baseTitle) {
    final wordText = formatWordForNotification(word, showMeaning: true, showPronunciation: false);
    
    // Tạo body với từ vựng và câu ví dụ ngắn
    String body = wordText;
    
    // Thêm câu ví dụ nếu không quá dài
    if (word.sentence.isNotEmpty && word.sentence.length <= 50) {
      body += '\nVD: ${word.sentence}';
    }
    
    return {
      'title': baseTitle,
      'body': body,
    };
  }
  
  /// Lấy từ vựng cho thông báo buổi sáng (từ dễ, motivational)
  Future<dWord?> getMorningWord() async {
    try {
      // Ưu tiên từ BASIC level cho buổi sáng
      final basicWords = await _wordRepository.getWordsByLevel(WordLevel.BASIC);
      if (basicWords.isNotEmpty) {
        // Lấy từ dễ nhất (difficulty thấp)
        basicWords.sort((a, b) => a.difficulty.compareTo(b.difficulty));
        final easyWords = basicWords.where((w) => w.difficulty <= 2).toList();
        
        if (easyWords.isNotEmpty) {
          final random = Random();
          return easyWords[random.nextInt(easyWords.length)];
        }
      }
      
      return await getRandomWordForNotification();
    } catch (e) {
      print('Error getting morning word: $e');
      return await getRandomWordForNotification();
    }
  }
  
  /// Lấy từ vựng cho thông báo buổi trưa (từ trung bình)
  Future<dWord?> getNoonWord() async {
    try {
      // Ưu tiên từ INTERMEDIATE level cho buổi trưa
      final intermediateWords = await _wordRepository.getWordsByLevel(WordLevel.INTERMEDIATE);
      if (intermediateWords.isNotEmpty) {
        final random = Random();
        return intermediateWords[random.nextInt(intermediateWords.length)];
      }
      
      return await getRandomWordForNotification();
    } catch (e) {
      print('Error getting noon word: $e');
      return await getRandomWordForNotification();
    }
  }
  
  /// Lấy từ vựng cho thông báo buổi tối (ôn tập từ đã học)
  Future<dWord?> getEveningWord() async {
    try {
      // Ưu tiên từ đã học để ôn tập
      final allWords = await _wordRepository.getAllWords();
      final learnedWords = <dWord>[];
      
      for (final word in allWords) {
        final progress = await _progressRepository.getWordProgress(word.topic, word.en);
        final isLearned = progress['isLearned'] ?? false;
        
        if (isLearned) {
          learnedWords.add(word);
        }
      }
      
      if (learnedWords.isNotEmpty) {
        final random = Random();
        return learnedWords[random.nextInt(learnedWords.length)];
      }
      
      // Nếu chưa có từ nào đã học, lấy từ dễ
      return await getMorningWord();
    } catch (e) {
      print('Error getting evening word: $e');
      return await getRandomWordForNotification();
    }
  }
}
