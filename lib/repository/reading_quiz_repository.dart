import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/word.dart';
import '../model/practice_question.dart';
import 'reading_repository.dart';
import 'dictionary_words_repository.dart';

class ReadingQuizRepository {
  static String _getKey(String readingId) => 'reading_quiz_$readingId';
  
  /// Lấy tất cả từ vựng trong danh sách ôn tập của một reading - sorted by difficulty
  Future<List<Word>> getReadingQuizWords(String readingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedWordsJson = prefs.getStringList(_getKey(readingId));
      
      if (savedWordsJson != null) {
        final words = savedWordsJson
            .map((wordJson) => Word.fromJson(jsonDecode(wordJson)))
            .toList();
        
        // Sort by difficulty (ascending), then by English word (alphabetical)
        words.sort((a, b) {
          int difficultyComparison = a.difficulty.compareTo(b.difficulty);
          if (difficultyComparison != 0) {
            return difficultyComparison;
          }
          return a.en.toLowerCase().compareTo(b.en.toLowerCase());
        });
        
        return words;
      }
      return [];
    } catch (e) {
      print('Error getting reading quiz words: $e');
      return [];
    }
  }
  
  /// Thêm từ vào danh sách ôn tập của reading
  Future<bool> addWordToReadingQuiz(String readingId, Word word) async {
    try {
      final currentWords = await getReadingQuizWords(readingId);
      
      // Kiểm tra từ đã tồn tại chưa (dựa trên en và topic)
      final exists = currentWords.any((w) => w.en == word.en && w.topic == word.topic);
      if (exists) {
        return false; // Từ đã tồn tại
      }
      
      // Thêm từ mới với thông tin ôn tập
      final quizWord = word.copyWith(
        reviewCount: 0,
        nextReview: DateTime.now(),
        lastReviewed: null,
        correctAnswers: 0,
        totalAttempts: 0,
      );
      
      currentWords.add(quizWord);
      await _saveReadingQuizWords(readingId, currentWords);
      return true;
    } catch (e) {
      print('Error adding word to reading quiz: $e');
      return false;
    }
  }
  
  /// Thêm nhiều từ vào danh sách ôn tập của reading
  Future<int> addWordsToReadingQuiz(String readingId, List<Word> words) async {
    int addedCount = 0;
    for (final word in words) {
      final success = await addWordToReadingQuiz(readingId, word);
      if (success) addedCount++;
    }
    return addedCount;
  }
  
  /// Xóa từ khỏi danh sách ôn tập của reading
  Future<bool> removeWordFromReadingQuiz(String readingId, Word word) async {
    try {
      final currentWords = await getReadingQuizWords(readingId);
      final initialLength = currentWords.length;
      
      currentWords.removeWhere((w) => w.en == word.en && w.topic == word.topic);
      
      if (currentWords.length < initialLength) {
        await _saveReadingQuizWords(readingId, currentWords);
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing word from reading quiz: $e');
      return false;
    }
  }
  
  /// Cập nhật tiến độ học của từ trong quiz của reading
  Future<bool> updateReadingWordProgress(String readingId, Word word, bool isCorrect) async {
    try {
      final currentWords = await getReadingQuizWords(readingId);
      final index = currentWords.indexWhere((w) => w.en == word.en && w.topic == word.topic);
      
      if (index != -1) {
        final updatedWord = currentWords[index].copyWith(
          reviewCount: isCorrect ? currentWords[index].reviewCount + 1 : 0,
          correctAnswers: isCorrect ? currentWords[index].correctAnswers + 1 : currentWords[index].correctAnswers,
          totalAttempts: currentWords[index].totalAttempts + 1,
          lastReviewed: DateTime.now(),
          nextReview: isCorrect 
              ? DateTime.now().add(Duration(days: _calculateNextInterval(currentWords[index].reviewCount + 1)))
              : DateTime.now().add(const Duration(hours: 1)), // Ôn lại sau 1 giờ nếu sai
          masteryLevel: _calculateMasteryLevel(
            isCorrect ? currentWords[index].correctAnswers + 1 : currentWords[index].correctAnswers,
            currentWords[index].totalAttempts + 1,
          ),
        );
        
        currentWords[index] = updatedWord;
        await _saveReadingQuizWords(readingId, currentWords);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating reading word progress: $e');
      return false;
    }
  }
  
  /// Lấy từ cần ôn tập (đến hạn review) của reading - sorted by difficulty
  Future<List<Word>> getReadingDueWords(String readingId) async {
    final allWords = await getReadingQuizWords(readingId);
    final now = DateTime.now();
    
    final dueWords = allWords.where((word) => 
      word.nextReview.isBefore(now) || 
      word.nextReview.isAtSameMomentAs(now)
    ).toList();
    
    // Sort by difficulty (ascending), then by English word (alphabetical)
    dueWords.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
    
    return dueWords;
  }
  
  /// Lấy từ theo mức độ thành thạo của reading
  Future<Map<String, List<Word>>> getReadingWordsByMastery(String readingId) async {
    final allWords = await getReadingQuizWords(readingId);
    
    final Map<String, List<Word>> wordsByMastery = {
      'new': [],
      'learning': [],
      'familiar': [],
      'mastered': [],
    };
    
    for (final word in allWords) {
      if (word.reviewCount == 0) {
        wordsByMastery['new']!.add(word);
      } else if (word.reviewCount < 3) {
        wordsByMastery['learning']!.add(word);
      } else if (word.reviewCount < 7) {
        wordsByMastery['familiar']!.add(word);
      } else {
        wordsByMastery['mastered']!.add(word);
      }
    }
    
    return wordsByMastery;
  }
  
  /// Lấy thống kê quiz của reading
  Future<Map<String, dynamic>> getReadingQuizStats(String readingId) async {
    final allWords = await getReadingQuizWords(readingId);
    final dueWords = await getReadingDueWords(readingId);
    
    int totalCorrect = 0;
    int totalAttempts = 0;
    
    for (final word in allWords) {
      totalCorrect += word.correctAnswers;
      totalAttempts += word.totalAttempts;
    }
    
    return {
      'totalWords': allWords.length,
      'dueWords': dueWords.length,
      'accuracy': totalAttempts > 0 ? (totalCorrect / totalAttempts * 100) : 0.0,
      'averageMastery': allWords.isNotEmpty 
          ? allWords.map((w) => w.masteryLevel).reduce((a, b) => a + b) / allWords.length * 100
          : 0.0,
    };
  }
  
  /// Xóa tất cả từ khỏi danh sách ôn tập của reading
  Future<bool> clearAllReadingQuizWords(String readingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey(readingId));
      return true;
    } catch (e) {
      print('Error clearing reading quiz words: $e');
      return false;
    }
  }
  
  /// Lưu danh sách từ ôn tập của reading
  Future<void> _saveReadingQuizWords(String readingId, List<Word> words) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> wordsJson = words.map((word) => jsonEncode(word.toJson())).toList();
    await prefs.setStringList(_getKey(readingId), wordsJson);
  }
  
  /// Tính toán khoảng thời gian ôn tập tiếp theo (spaced repetition)
  int _calculateNextInterval(int reviewCount) {
    switch (reviewCount) {
      case 1: return 1;    // 1 ngày
      case 2: return 3;    // 3 ngày
      case 3: return 7;    // 1 tuần
      case 4: return 14;   // 2 tuần
      case 5: return 30;   // 1 tháng
      default: return 60;  // 2 tháng
    }
  }
  
  /// Tính toán mức độ thành thạo
  double _calculateMasteryLevel(int correctAnswers, int totalAttempts) {
    if (totalAttempts == 0) return 0.0;
    return (correctAnswers / totalAttempts).clamp(0.0, 1.0);
  }

  /// Tự động khởi tạo quiz từ question số 1 của reading
  /// Extract các từ từ correctAnswers của question 1 và thêm vào quiz
  Future<int> initializeFromQuestion1(String readingId) async {
    try {
      // Kiểm tra xem đã có từ nào chưa
      final existingWords = await getReadingQuizWords(readingId);
      if (existingWords.isNotEmpty) {
        // Đã có từ rồi, không cần initialize
        return 0;
      }

      // Lấy questions từ reading
      final readingRepository = ReadingRepository();
      final questions = await readingRepository.loadQuestionsForReading(readingId);
      
      if (questions.isEmpty) {
        // Không có question nào
        return 0;
      }

      // Lấy question số 1 (index 0)
      final PracticeQuestion question1 = questions[0];
      
      // Extract words từ correctAnswers
      final wordsToAdd = <Word>[];
      final dictionaryRepo = DictionaryWordsRepository();
      
      // Extract words từ tất cả correctAnswers
      for (final answerText in question1.correctAnswers) {
        final extractedWords = _extractWordsFromText(answerText);
        
        // Lấy Word objects từ dictionary
        for (final wordText in extractedWords) {
          final word = await dictionaryRepo.getWord(wordText);
          if (word != null) {
            // Tạo Word với topic là reading title
            final reading = await readingRepository.getReading(readingId);
            final topic = reading?.title ?? 'Reading';
            
            final quizWord = word.copyWith(
              topic: topic,
              reviewCount: 0,
              nextReview: DateTime.now(),
              lastReviewed: null,
              correctAnswers: 0,
              totalAttempts: 0,
            );
            
            // Kiểm tra xem từ đã có trong list chưa (tránh duplicate)
            if (!wordsToAdd.any((w) => w.en.toLowerCase() == wordText.toLowerCase())) {
              wordsToAdd.add(quizWord);
            }
          }
        }
      }

      // Thêm các từ vào quiz
      if (wordsToAdd.isNotEmpty) {
        await addWordsToReadingQuiz(readingId, wordsToAdd);
        return wordsToAdd.length;
      }

      return 0;
    } catch (e) {
      print('Error initializing quiz from question 1: $e');
      return 0;
    }
  }

  /// Extract English words from text (helper method)
  List<String> _extractWordsFromText(String text) {
    // Match English words (letters, apostrophes, hyphens)
    final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
    final matches = wordPattern.allMatches(text);
    
    final words = <String>{};
    for (final match in matches) {
      final word = match.group(0)!.toLowerCase();
      // Filter out common short words (articles, prepositions, etc.)
      if (word.length > 2 && !_isCommonWord(word)) {
        words.add(word);
      }
    }
    
    return words.toList()..sort();
  }

  /// Check if word is a common English word (articles, prepositions, etc.)
  bool _isCommonWord(String word) {
    const commonWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
      'including', 'against', 'among', 'throughout', 'despite', 'towards',
      'upon', 'concerning',
      'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had',
      'do', 'does', 'did', 'will', 'would', 'should', 'could', 'may', 'might',
      'can', 'must', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she',
      'it', 'we', 'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his',
      'its', 'our', 'their', 'what', 'which', 'who', 'whom', 'whose',
      'where', 'when', 'why', 'how', 'all', 'each', 'every', 'both', 'few',
      'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only',
      'own', 'same', 'so', 'than', 'too', 'very', 'just', 'now'
    };
    return commonWords.contains(word);
  }
}

