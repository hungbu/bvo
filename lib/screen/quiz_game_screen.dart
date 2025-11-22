import 'dart:math';
import 'package:flutter/material.dart';
import '../model/word.dart';
import '../repository/quiz_repository.dart';
import '../repository/user_progress_repository.dart';
import '../service/notification_service.dart';
import '../service/audio_service.dart';

enum QuizType {
  multipleChoice,    // Trắc nghiệm 4 đáp án (từ EN → nghĩa VI)
  fillInBlank,      // Điền từ vào chỗ trống (nghĩa VI → từ EN)
  reverseTranslation, // Dịch sang tiếng Anh (nghĩa VI → từ EN)
}

class QuizGameScreen extends StatefulWidget {
  final List<Word> words;
  final String title;

  const QuizGameScreen({
    Key? key,
    required this.words,
    this.title = 'Quiz',
  }) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> with TickerProviderStateMixin {
  late List<Word> shuffledWords;
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  int totalQuestions = 0;
  
  QuizType currentQuizType = QuizType.multipleChoice;
  List<String> currentOptions = [];
  String correctAnswer = '';
  String? selectedAnswer;
  bool showResult = false;
  bool isAnswerCorrect = false;
  
  late AnimationController _progressController;
  late AnimationController _resultController;
  late Animation<double> _progressAnimation;
  late Animation<double> _resultAnimation;
  
  final TextEditingController _fillInController = TextEditingController();
  final Random _random = Random();
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    
    _resultAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );
    
    _initializeQuiz();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _resultController.dispose();
    _fillInController.dispose();
    // AudioService is singleton, no need to stop
    super.dispose();
  }

  void _initializeQuiz() {
    shuffledWords = List.from(widget.words)..shuffle(_random);
    totalQuestions = shuffledWords.length;
    _generateQuestion();
    _progressController.forward();
  }

  Future<void> _speakEnglish(String text) async {
    await _audioService.speakNormal(text);
  }

  void _generateQuestion() {
    print('🟡 [QUIZ] _generateQuestion() called');
    print('   - currentQuestionIndex: $currentQuestionIndex');
    print('   - shuffledWords.length: ${shuffledWords.length}');
    
    if (currentQuestionIndex >= shuffledWords.length) {
      print('   ⚠️ All questions completed, showing final results');
      _showFinalResults();
      return;
    }

    final currentWord = shuffledWords[currentQuestionIndex];
    print('   - currentWord: ${currentWord.en} (${currentWord.vi})');
    
    // Randomly select quiz type
    final quizTypes = QuizType.values;
    currentQuizType = quizTypes[_random.nextInt(quizTypes.length)];
    print('   - Selected quiz type: ${currentQuizType.toString().split('.').last}');
    
    // Clear controller first
    _fillInController.clear();
    print('   - TextField controller cleared');
    
    print('   🎨 Updating state...');
    setState(() {
      showResult = false;
      selectedAnswer = null;
      isAnswerCorrect = false;
    });
    print('   ✅ State updated: showResult=false, selectedAnswer=null, isAnswerCorrect=false');

    switch (currentQuizType) {
      case QuizType.multipleChoice:
        print('   📝 Generating multiple choice question...');
        _generateMultipleChoiceQuestion(currentWord);
        break;
      case QuizType.fillInBlank:
        print('   📝 Generating fill in blank question...');
        _generateFillInBlankQuestion(currentWord);
        break;
      case QuizType.reverseTranslation:
        print('   📝 Generating reverse translation question...');
        _generateReverseTranslationQuestion(currentWord);
        break;
    }
    print('   ✅ Question generated successfully');
  }

  void _generateMultipleChoiceQuestion(Word word) {
    correctAnswer = word.vi;
    currentOptions = [correctAnswer];
    
    // Generate 3 wrong answers from other words
    final otherWords = shuffledWords.where((w) => w.en != word.en).toList();
    otherWords.shuffle(_random);
    
    for (int i = 0; i < 3 && i < otherWords.length; i++) {
      currentOptions.add(otherWords[i].vi);
    }
    
    // Fill remaining slots if needed
    while (currentOptions.length < 4) {
      currentOptions.add('Đáp án ${currentOptions.length}');
    }
    
    currentOptions.shuffle(_random);
  }

  void _generateFillInBlankQuestion(Word word) {
    correctAnswer = word.en.toLowerCase().trim();
    currentOptions = [];
  }


  void _generateReverseTranslationQuestion(Word word) {
    correctAnswer = word.en;
    
    // Generate options from other words
    final otherWords = shuffledWords.where((w) => w.vi != word.vi).toList();
    otherWords.shuffle(_random);
    
    currentOptions = [correctAnswer];
    for (int i = 0; i < 3 && i < otherWords.length; i++) {
      currentOptions.add(otherWords[i].en);
    }
    
    while (currentOptions.length < 4) {
      currentOptions.add('Answer ${currentOptions.length}');
    }
    
    currentOptions.shuffle(_random);
  }

  void _submitAnswer() async {
    print('🔵 [QUIZ] _submitAnswer() called');
    print('   - showResult: $showResult');
    print('   - currentQuestionIndex: $currentQuestionIndex');
    print('   - totalQuestions: $totalQuestions');
    
    // Prevent double submission
    if (showResult) {
      print('   ❌ Already showing result, returning early');
      return;
    }
    
    String userAnswer = '';
    
    switch (currentQuizType) {
      case QuizType.fillInBlank:
        userAnswer = _fillInController.text.toLowerCase().trim();
        print('   - FillInBlank: userAnswer = "$userAnswer"');
        break;
      default:
        userAnswer = selectedAnswer ?? '';
        print('   - MultipleChoice/ReverseTranslation: userAnswer = "$userAnswer"');
        break;
    }

    // Check if answer is provided
    if (userAnswer.isEmpty) {
      print('   ❌ User answer is empty, returning early');
      return;
    }

    print('   - correctAnswer: "$correctAnswer"');
    isAnswerCorrect = userAnswer == correctAnswer || 
                     (currentQuizType == QuizType.fillInBlank && 
                      userAnswer == correctAnswer.toLowerCase());
    print('   - isAnswerCorrect: $isAnswerCorrect');

    final currentWord = shuffledWords[currentQuestionIndex];
    print('   - currentWord: ${currentWord.en}');
    
    // Don't wait for audio to complete - fire and forget
    if (isAnswerCorrect) {
      correctAnswers++;
      print('   ✅ Correct! Total correct: $correctAnswers');
      // Phát âm từ đúng khi trả lời đúng (fire and forget)
      _speakEnglish(currentWord.en).catchError((e) {
        print('   ⚠️ Error speaking: $e');
      });
    } else {
      print('   ❌ Incorrect! Total correct: $correctAnswers');
      // Phát âm từ đúng khi trả lời sai để người dùng học (fire and forget)
      _speakEnglish(currentWord.en).catchError((e) {
        print('   ⚠️ Error speaking: $e');
      });
    }

    print('   📝 Updating word progress...');
    try {
      // Update word progress in repository
      await QuizRepository().updateWordProgress(currentWord, isAnswerCorrect);
      
      // Also update UserProgressRepository for comprehensive tracking
      await UserProgressRepository().updateWordProgress(currentWord.topic, currentWord, isAnswerCorrect);
      print('   ✅ Word progress updated');
    } catch (e) {
      print('   ❌ Error updating progress: $e');
    }

    print('   🎨 Setting showResult = true');
    if (mounted) {
      setState(() {
        showResult = true;
      });
      print('   ✅ showResult set to true');
    } else {
      print('   ⚠️ Widget not mounted, cannot setState');
    }

    print('   🎬 Starting result animation');
    if (mounted) {
      _resultController.reset();
      _resultController.forward();
      print('   ✅ Result animation started');
    } else {
      print('   ⚠️ Widget not mounted, cannot start animation');
    }

    print('   ✅ _submitAnswer() completed successfully');
  }

  void _nextQuestion() {
    print('🟢 [QUIZ] _nextQuestion() called');
    print('   - currentQuestionIndex before: $currentQuestionIndex');
    print('   - shuffledWords.length: ${shuffledWords.length}');
    print('   - totalQuestions: $totalQuestions');
    
    if (currentQuestionIndex >= shuffledWords.length - 1) {
      print('   ⚠️ Last question reached, will show final results');
    }
    
    currentQuestionIndex++;
    print('   - currentQuestionIndex after increment: $currentQuestionIndex');
    
    print('   📝 Generating next question...');
    _generateQuestion();
    print('   ✅ Next question generated');
    
    // Update progress animation
    print('   🎬 Resetting and starting progress animation');
    _progressController.reset();
    _progressController.forward();
    print('   ✅ Progress animation started');
    print('   ✅ _nextQuestion() completed successfully');
  }

  void _showFinalResults() async {
    final accuracy = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100) : 0.0;
    
    // Mark quiz as completed and trigger notifications
    final notificationService = NotificationService();
    await notificationService.markQuizCompleted();
    await notificationService.updateLastActiveDate();
    
    // Check for accuracy achievements
    if (accuracy == 100.0) {
      await notificationService.showAchievementNotification(
        achievementTitle: 'Perfect Score!',
        achievementDescription: '100% accuracy! Your memory is amazing!',
        achievementType: 'accuracy',
      );
    } else if (accuracy >= 90.0) {
      await notificationService.showAchievementNotification(
        achievementTitle: 'Quiz Master',
        achievementDescription: 'Excellent performance! 90%+ accuracy!',
        achievementType: 'quiz_master',
      );
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                accuracy >= 80 ? Icons.emoji_events : 
                accuracy >= 60 ? Icons.thumb_up : Icons.refresh,
                color: accuracy >= 80 ? Colors.amber : 
                       accuracy >= 60 ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text('Kết quả Quiz'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: accuracy / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  accuracy >= 80 ? Colors.green : 
                  accuracy >= 60 ? Colors.orange : Colors.red,
                ),
                strokeWidth: 8,
              ),
              const SizedBox(height: 16),
              Text(
                '${accuracy.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Đúng: $correctAnswers/$totalQuestions câu'),
              const SizedBox(height: 16),
              Text(
                accuracy >= 80 ? 'Xuất sắc! 🎉' :
                accuracy >= 60 ? 'Tốt lắm! 👍' : 'Cần cố gắng thêm! 💪',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to quiz list
              },
              child: const Text('Hoàn thành'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _restartQuiz();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Làm lại'),
            ),
          ],
        );
      },
    );
  }

  void _restartQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      correctAnswers = 0;
      showResult = false;
    });
    _initializeQuiz();
  }

  @override
  Widget build(BuildContext context) {
    if (currentQuestionIndex >= shuffledWords.length) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentWord = shuffledWords[currentQuestionIndex];
    final progress = (currentQuestionIndex + 1) / totalQuestions;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Cho phép resize khi keyboard mở
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${currentQuestionIndex + 1}/$totalQuestions',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          Container(
            height: 4,
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: progress * _progressAnimation.value,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  // Scrollable content area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Quiz Type Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getQuizTypeTitle(),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Question
                          _buildQuestion(currentWord),
                          
                          const SizedBox(height: 20),
                          
                          // Answer Options
                          _buildAnswerSection(currentWord),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  // Fixed Submit/Next Button at bottom
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: showResult
                          ? ElevatedButton(
                              onPressed: () {
                                print('🟢 [QUIZ] Next button clicked');
                                print('   - showResult: $showResult');
                                print('   - currentQuestionIndex: $currentQuestionIndex');
                                print('   - shuffledWords.length: ${shuffledWords.length}');
                                _nextQuestion();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Câu tiếp theo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _canSubmit() ? () {
                                print('🔵 [QUIZ] Submit button clicked');
                                print('   - canSubmit: ${_canSubmit()}');
                                print('   - showResult: $showResult');
                                _submitAnswer();
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Trả lời',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getQuizTypeTitle() {
    switch (currentQuizType) {
      case QuizType.multipleChoice:
        return 'Trắc nghiệm';
      case QuizType.fillInBlank:
        return 'Điền từ';
      case QuizType.reverseTranslation:
        return 'Dịch sang tiếng Anh';
    }
  }

  Widget _buildQuestion(Word word) {
    String questionText = '';
    
    switch (currentQuizType) {
      case QuizType.multipleChoice:
        questionText = 'Nghĩa của từ "${word.en}" là gì?';
        break;
      case QuizType.fillInBlank:
        questionText = 'Điền từ tiếng Anh có nghĩa là:\n"${word.vi}"';
        break;
      case QuizType.reverseTranslation:
        questionText = 'Từ tiếng Anh của "${word.vi}" là gì?';
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              questionText,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            // Nút phát âm cho từ tiếng Anh (chỉ khi có từ tiếng Anh trong câu hỏi)
            if (currentQuizType == QuizType.multipleChoice) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _speakEnglish(word.en),
                    icon: const Icon(Icons.volume_up),
                    iconSize: 28,
                    color: Theme.of(context).primaryColor,
                    tooltip: 'Phát âm từ tiếng Anh',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    word.en,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
            if (word.sentence.isNotEmpty && currentQuizType != QuizType.fillInBlank) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Ví dụ:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.sentence,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection(Word word) {
    if (showResult) {
      return AnimatedBuilder(
        animation: _resultAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _resultAnimation.value,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: isAnswerCorrect ? Colors.green[50] : Colors.red[50],
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAnswerCorrect ? Icons.check_circle : Icons.cancel,
                      size: 64,
                      color: isAnswerCorrect ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAnswerCorrect ? 'Chính xác!' : 'Sai rồi!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isAnswerCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isAnswerCorrect) ...[
                      Text(
                        'Đáp án đúng: $correctAnswer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      '${word.en} = ${word.vi}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    switch (currentQuizType) {
      case QuizType.fillInBlank:
        return _buildFillInBlankAnswer();
      default:
        return _buildMultipleChoiceAnswer();
    }
  }

  Widget _buildMultipleChoiceAnswer() {
    return Column(
      children: currentOptions.map((option) {
        final isSelected = selectedAnswer == option;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                selectedAnswer = option;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.white,
              foregroundColor: isSelected 
                  ? Colors.white 
                  : Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              elevation: isSelected ? 4 : 1,
            ),
            child: Text(
              option,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFillInBlankAnswer() {
    return Column(
      children: [
        const SizedBox(height: 20),
        TextField(
          key: ValueKey('fillIn_$currentQuestionIndex'), // Force rebuild when question changes
          controller: _fillInController,
          decoration: InputDecoration(
            hintText: 'Nhập từ tiếng Anh...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
          autofocus: false,
          onChanged: (value) {
            setState(() {}); // Trigger rebuild to update submit button state
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  bool _canSubmit() {
    bool canSubmit = false;
    switch (currentQuizType) {
      case QuizType.fillInBlank:
        canSubmit = _fillInController.text.trim().isNotEmpty;
        print('🔍 [QUIZ] _canSubmit() - FillInBlank: text="${_fillInController.text.trim()}", canSubmit=$canSubmit');
        break;
      default:
        canSubmit = selectedAnswer != null;
        print('🔍 [QUIZ] _canSubmit() - MultipleChoice/ReverseTranslation: selectedAnswer="$selectedAnswer", canSubmit=$canSubmit');
        break;
    }
    return canSubmit;
  }
}
