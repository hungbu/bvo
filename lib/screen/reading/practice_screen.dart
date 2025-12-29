import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../model/practice_question.dart';
import '../../repository/practice_repository.dart';
import '../../repository/reading_repository.dart';
import '../../repository/word_repository.dart';
import '../../repository/reading_quiz_repository.dart';
import '../../repository/dictionary_words_repository.dart';
import '../../repository/practice_history_repository.dart';
import '../../model/practice_history.dart';
import 'practice_history_screen.dart';
import '../../model/word.dart';
import '../../widget/selectable_text_with_word_lookup.dart';
import '../../service/dialog_manager.dart';
import '../dictionary/word_search_dialog.dart';

class PracticeScreen extends StatefulWidget {
  final String readingId;
  
  const PracticeScreen({
    Key? key,
    required this.readingId,
  }) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final PracticeRepository _repository = PracticeRepository();
  final ReadingRepository _readingRepository = ReadingRepository();
  final WordRepository _wordRepository = WordRepository();
  final DictionaryWordsRepository _dictionaryRepository = DictionaryWordsRepository();
  final PracticeHistoryRepository _historyRepository = PracticeHistoryRepository();
  List<PracticeQuestion> _questions = [];
  Map<String, List<String>> _userAnswers = {};
  Map<String, bool> _submittedResults = {}; // Track if question has been submitted
  Map<String, bool> _isCorrect = {}; // Track if answer is correct
  bool _allQuestionsSubmitted = false; // Track if all questions have been submitted
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  Map<String, TextEditingController> _textControllers = {}; // Controllers for text answer questions
  String? _readingTitle;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Dispose all text controllers
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load reading to get title
      final reading = await _readingRepository.getReading(widget.readingId);
      
      // Load questions for this specific reading
      final questions = await _readingRepository.loadQuestionsForReading(widget.readingId);
      
      // Load answers for these questions
      final Map<String, List<String>> answers = {};
      for (final question in questions) {
        final answer = await _repository.loadAnswer(question.id);
        if (answer.isNotEmpty) {
          answers[question.id] = answer;
        }
      }
      
      // Initialize text controllers for text answer questions
      for (final question in questions) {
        if (question.type == QuestionType.answerText) {
          if (!_textControllers.containsKey(question.id)) {
            final answer = answers[question.id] ?? [];
            _textControllers[question.id] = TextEditingController(
              text: answer.isNotEmpty ? answer.first : '',
            );
          }
        }
      }
      
      setState(() {
        _questions = questions;
        _userAnswers = answers;
        _readingTitle = reading?.title ?? 'Practice';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }


  Future<void> _saveAnswer(String questionId, List<String> answers) async {
    await _repository.saveAnswer(questionId, answers);
    setState(() {
      _userAnswers[questionId] = answers;
      // Clear submission if answer is changed after submission
      if (_submittedResults.containsKey(questionId)) {
        _submittedResults.remove(questionId);
        _isCorrect.remove(questionId);
        _allQuestionsSubmitted = false;
      }
    });
  }

  Future<void> _clearAnswer(String questionId) async {
    await _repository.clearAnswer(questionId);
    setState(() {
      _userAnswers.remove(questionId);
      _submittedResults.remove(questionId);
      _isCorrect.remove(questionId);
      _allQuestionsSubmitted = false;
    });
  }

  Future<void> _resetPractice() async {
    // Clear all answers for current reading
    final questionIds = _questions.map((q) => q.id).toList();
    await _repository.clearAnswersForQuestions(questionIds);
    
    // Clear text controllers
    for (final controller in _textControllers.values) {
      controller.clear();
    }
    
    setState(() {
      _userAnswers.clear();
      _submittedResults.clear();
      _isCorrect.clear();
      _allQuestionsSubmitted = false;
      _currentQuestionIndex = 0;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã reset bài practice. Bạn có thể làm lại từ đầu.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showResetConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Làm lại bài practice?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa tất cả câu trả lời và làm lại từ đầu không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Làm lại'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _resetPractice();
    }
  }

  bool _areAllQuestionsAnswered() {
    if (_questions.isEmpty) return false;
    for (final question in _questions) {
      final userAnswer = _userAnswers[question.id] ?? [];
      if (userAnswer.isEmpty) {
        return false;
      }
    }
    return true;
  }

  bool _checkAnswerForQuestion(PracticeQuestion question) {
    final userAnswer = _userAnswers[question.id] ?? [];
    
    if (userAnswer.isEmpty) {
      return false;
    }
    
    bool isCorrect = false;
    
    switch (question.type) {
      case QuestionType.fillToSentence:
        // For fill-to-sentence, check if each blank is filled correctly
        // The correct answer should match the first blank position
        if (userAnswer.isNotEmpty && question.correctAnswers.isNotEmpty) {
          // Check if the first answer matches (case-insensitive)
          isCorrect = userAnswer[0].trim().toLowerCase() == 
                     question.correctAnswers[0].trim().toLowerCase();
          
          // If there are multiple blanks, check all of them
          if (question.correctAnswers.length > 1 && userAnswer.length > 1) {
            isCorrect = true;
            for (int i = 0; i < question.correctAnswers.length && i < userAnswer.length; i++) {
              if (userAnswer[i].trim().toLowerCase() != 
                  question.correctAnswers[i].trim().toLowerCase()) {
                isCorrect = false;
                break;
              }
            }
            // Also check if the number of answers matches
            if (userAnswer.length != question.correctAnswers.length) {
              isCorrect = false;
            }
          }
        }
        break;
        
      case QuestionType.chooseOne:
        // For single answer, check if user answer matches (case-insensitive)
        if (userAnswer.length == 1 && question.correctAnswers.length == 1) {
          isCorrect = userAnswer[0].trim().toLowerCase() == 
                     question.correctAnswers[0].trim().toLowerCase();
        }
        break;
        
      case QuestionType.chooseMulti:
        // For multiple answers, check if all correct answers are selected and no extra
        final userAnswerSet = userAnswer.map((a) => a.trim().toLowerCase()).toSet();
        final correctAnswerSet = question.correctAnswers.map((a) => a.trim().toLowerCase()).toSet();
        isCorrect = userAnswerSet.length == correctAnswerSet.length &&
                   userAnswerSet.every((ans) => correctAnswerSet.contains(ans));
        break;
        
      case QuestionType.answerText:
        // For text answers, do case-insensitive comparison
        // Also check if the answer contains the correct answer (for partial matches)
        final userText = userAnswer.first.trim().toLowerCase();
        final correctText = question.correctAnswers.first.trim().toLowerCase();
        
        // Exact match or contains the key parts
        isCorrect = userText == correctText || 
                   userText.contains(correctText) ||
                   correctText.contains(userText);
        
        // For text editor, we can also check if it matches the example pattern
        // Remove example text if present (e.g., "(My name is ...) - Example: Alice")
        final cleanCorrect = correctText.split('-')[0].split('(')[0].trim();
        if (cleanCorrect.isNotEmpty) {
          isCorrect = isCorrect || userText.contains(cleanCorrect);
        }
        break;
    }
    
    return isCorrect;
  }

  Future<void> _submitAllQuestions() async {
    // Check all answers
    int correctCount = 0;
    int totalCount = _questions.length;
    final Map<String, bool> questionResults = {};
    
    for (final question in _questions) {
      final isCorrect = _checkAnswerForQuestion(question);
      _submittedResults[question.id] = true;
      _isCorrect[question.id] = isCorrect;
      questionResults[question.id] = isCorrect;
      if (isCorrect) {
        correctCount++;
      }
    }
    
    setState(() {
      _allQuestionsSubmitted = true;
    });
    
    // Save to history
    await _saveToHistory(correctCount, totalCount, questionResults);
    
    // Show results dialog
    if (mounted) {
      await _showResultsDialog(correctCount, totalCount);
    }
  }

  Future<void> _saveToHistory(
    int correctCount,
    int totalCount,
    Map<String, bool> questionResults,
  ) async {
    try {
      final history = PracticeHistory(
        id: '${widget.readingId}_${DateTime.now().millisecondsSinceEpoch}',
        readingId: widget.readingId,
        completedAt: DateTime.now(),
        totalQuestions: totalCount,
        correctAnswers: correctCount,
        accuracy: totalCount > 0 ? correctCount / totalCount : 0.0,
        userAnswers: Map<String, List<String>>.from(_userAnswers),
        questionResults: questionResults,
      );
      
      await _historyRepository.saveHistory(history);
      print('✅ Practice history saved: ${history.id}');
    } catch (e) {
      print('❌ Error saving practice history: $e');
    }
  }

  Future<void> _showResultsDialog(int correctCount, int totalCount) async {
    final percentage = (correctCount / totalCount * 100).round();
    final resultColor = percentage >= 70 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Practice Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              percentage >= 70 ? Icons.celebration : 
              percentage >= 50 ? Icons.sentiment_satisfied : 
              Icons.sentiment_dissatisfied,
              size: 64,
              color: resultColor,
            ),
            const SizedBox(height: 16),
            Text(
              '$correctCount / $totalCount',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: resultColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage% Correct',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: resultColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              percentage >= 70 ? 'Excellent work! 🎉' :
              percentage >= 50 ? 'Good job! Keep practicing!' :
              'Keep practicing! You\'ll improve! 💪',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset to first question for review
              setState(() {
                _currentQuestionIndex = 0;
              });
            },
            child: const Text('Review Answers'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Exercises'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Xem lịch sử',
            onPressed: () async {
              final title = _readingTitle ?? 'Practice';
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PracticeHistoryScreen(
                    readingId: widget.readingId,
                    readingTitle: title,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm lại từ đầu',
            onPressed: _userAnswers.isEmpty && !_allQuestionsSubmitted
                ? null
                : () => _showResetConfirmation(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPracticeTab(),
    );
  }

  Widget _buildPracticeTab() {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Không có câu hỏi nào',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Bài reading này chưa có câu hỏi',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final userAnswer = _userAnswers[currentQuestion.id] ?? [];

    return Column(
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _questions.length,
                ),
              ),
              const SizedBox(width: 16),
              Text('${_currentQuestionIndex + 1}/${_questions.length}'),
            ],
          ),
        ),
        
        // Question display
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildQuestionWidget(currentQuestion, userAnswer, _allQuestionsSubmitted),
                      ],
                    ),
                  ),
                ),
                
                // User's answer display
                if (userAnswer.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Answer:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...userAnswer.map((ans) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $ans'),
                          )),
                          const SizedBox(height: 8),
                          if (!_allQuestionsSubmitted)
                            TextButton.icon(
                              onPressed: () => _clearAnswer(currentQuestion.id),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Re-do'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                // Result display
                if (_submittedResults.containsKey(currentQuestion.id)) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: _isCorrect[currentQuestion.id] == true 
                        ? Colors.green[50] 
                        : Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isCorrect[currentQuestion.id] == true 
                                        ? Icons.check_circle 
                                        : Icons.cancel,
                                    color: _isCorrect[currentQuestion.id] == true 
                                        ? Colors.green 
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isCorrect[currentQuestion.id] == true 
                                        ? 'Correct!' 
                                        : 'Incorrect',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _isCorrect[currentQuestion.id] == true 
                                          ? Colors.green 
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Correct Answer(s):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...currentQuestion.correctAnswers.map((ans) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $ans',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          )),
                          if (_isCorrect[currentQuestion.id] != true) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Your Answer:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...userAnswer.map((ans) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $ans'),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Navigation buttons and Submit button
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Submit All button (only show when all questions are answered and not yet submitted)
              if (_areAllQuestionsAnswered() && !_allQuestionsSubmitted)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _submitAllQuestions(),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Submit All Answers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              
              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentQuestionIndex > 0
                        ? () {
                            setState(() {
                              _currentQuestionIndex--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _currentQuestionIndex < _questions.length - 1
                        ? () {
                            setState(() {
                              _currentQuestionIndex++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionWidget(PracticeQuestion question, List<String> userAnswer, bool isReadOnly) {
    switch (question.type) {
      case QuestionType.fillToSentence:
        return _buildFillToSentenceWidget(question, userAnswer, isReadOnly);
      case QuestionType.chooseOne:
        return _buildChooseOneWidget(question, userAnswer, isReadOnly);
      case QuestionType.chooseMulti:
        return _buildChooseMultiWidget(question, userAnswer, isReadOnly);
      case QuestionType.answerText:
        return _buildAnswerTextWidget(question, userAnswer, isReadOnly);
    }
  }

  Widget _buildFillToSentenceWidget(PracticeQuestion question, List<String> userAnswer, bool isReadOnly) {
    // Parse sentence with blanks
    String sentence = question.questionText;
    final blankMatches = RegExp(r'\((\d+)\)').allMatches(sentence);
    
    // Get number of blanks
    final numBlanks = blankMatches.length;
    final blankPositions = question.blankPositions ?? List.generate(numBlanks, (i) => i + 1);
    
    // Map blank position number to user answer index
    // blankPositions contains the position numbers (1, 2, 3...)
    // userAnswer is indexed by order (0, 1, 2...)
    final blanks = <int, String>{};
    for (int i = 0; i < blankPositions.length; i++) {
      final blankNum = blankPositions[i];
      final userAnswerForBlank = i < userAnswer.length ? userAnswer[i] : '';
      blanks[blankNum] = userAnswerForBlank;
    }
    
    // Replace (1), (2), etc. with filled words or ___ in display
    String displaySentence = sentence;
    final blankMatchesList = blankMatches.toList();
    // Process from end to start to preserve positions
    for (int i = blankMatchesList.length - 1; i >= 0; i--) {
      final match = blankMatchesList[i];
      final blankNum = int.parse(match.group(1)!);
      final filledWord = blanks[blankNum] ?? '';
      // Replace with filled word if available, otherwise ___
      final replacement = filledWord.isEmpty ? '___' : filledWord;
      displaySentence = displaySentence.replaceFirst(match.group(0)!, replacement);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWithWordLookup(
          text: displaySentence,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
          onWordSelected: _showWordDetail,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: question.options.map((option) {
            final isSelected = userAnswer.contains(option);
            
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: isReadOnly ? null : (selected) {
                if (selected) {
                  // Find which blank position to fill (next empty blank)
                  final nextBlankIndex = _getNextBlankIndex(userAnswer, blankPositions.length);
                  if (nextBlankIndex != null) {
                    final newAnswer = List<String>.from(userAnswer);
                    while (newAnswer.length <= nextBlankIndex) {
                      newAnswer.add('');
                    }
                    newAnswer[nextBlankIndex] = option;
                    _saveAnswer(question.id, newAnswer);
                  }
                } else {
                  // Remove the option and shift remaining answers
                  final newAnswer = List<String>.from(userAnswer);
                  final indexToRemove = newAnswer.indexOf(option);
                  if (indexToRemove != -1) {
                    newAnswer.removeAt(indexToRemove);
                    _saveAnswer(question.id, newAnswer);
                  }
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  int? _getNextBlankIndex(List<String> userAnswer, int numBlanks) {
    for (int i = 0; i < numBlanks; i++) {
      if (userAnswer.length <= i || userAnswer[i].isEmpty) {
        return i;
      }
    }
    return null;
  }

  TextSpan _buildSentenceWithBlanks(String sentence, Map<int, String> blanks, List<int> blankPositions) {
    final parts = sentence.split('___');
    final spans = <TextSpan>[];
    
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ));
      if (i < parts.length - 1 && i < blankPositions.length) {
        final blankNum = blankPositions[i];
        final answer = blanks[blankNum] ?? '';
        spans.add(TextSpan(
          text: answer.isEmpty ? '___' : answer,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: answer.isEmpty ? Colors.red : Colors.green,
            decoration: answer.isEmpty ? TextDecoration.underline : null,
          ),
        ));
      }
    }
    
    return TextSpan(children: spans);
  }

  Widget _buildChooseOneWidget(PracticeQuestion question, List<String> userAnswer, bool isReadOnly) {
    // Get the currently selected value (first item if any)
    final String? selectedValue = userAnswer.isNotEmpty ? userAnswer.first : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableTextWithWordLookup(
          text: question.questionText,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
          onWordSelected: _showWordDetail,
        ),
        const SizedBox(height: 16),
        // TODO: Migrate to RadioGroup when available in stable Flutter
        // ignore: deprecated_member_use
        ...question.options.map((option) {
          return RadioListTile<String>(
            title: TextWithWordLookup(
              text: option,
              onWordSelected: _showWordDetail,
            ),
            value: option,
            // ignore: deprecated_member_use
            groupValue: selectedValue,
            // ignore: deprecated_member_use
            onChanged: isReadOnly ? null : (String? value) {
              if (value != null) {
                _saveAnswer(question.id, [value]);
              }
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildChooseMultiWidget(PracticeQuestion question, List<String> userAnswer, bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableTextWithWordLookup(
          text: question.questionText,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
          onWordSelected: _showWordDetail,
        ),
        const SizedBox(height: 16),
        ...question.options.map((option) {
          final isSelected = userAnswer.contains(option);
          return CheckboxListTile(
            title: TextWithWordLookup(
              text: option,
              onWordSelected: _showWordDetail,
            ),
            value: isSelected,
            onChanged: isReadOnly ? null : (selected) {
              final newAnswer = List<String>.from(userAnswer);
              if (selected == true) {
                if (!newAnswer.contains(option)) {
                  newAnswer.add(option);
                }
              } else {
                newAnswer.remove(option);
              }
              _saveAnswer(question.id, newAnswer);
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAnswerTextWidget(PracticeQuestion question, List<String> userAnswer, bool isReadOnly) {
    // Get or create controller for this question
    if (!_textControllers.containsKey(question.id)) {
      _textControllers[question.id] = TextEditingController(
        text: userAnswer.isNotEmpty ? userAnswer.first : '',
      );
    } else {
      // Update controller text if it doesn't match current answer
      final controller = _textControllers[question.id]!;
      final currentText = userAnswer.isNotEmpty ? userAnswer.first : '';
      if (controller.text != currentText) {
        controller.text = currentText;
        // Move cursor to end
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: currentText.length),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableTextWithWordLookup(
          text: question.questionText,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
          onWordSelected: _showWordDetail,
        ),
        const SizedBox(height: 16),
        TextField(
          key: ValueKey(question.id), // Force rebuild when question changes
          controller: _textControllers[question.id],
          maxLines: 5,
          enabled: !isReadOnly,
          textDirection: TextDirection.ltr, // Ensure left-to-right text direction
          textAlign: TextAlign.left, // Ensure left alignment
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter your answer',
          ),
          onChanged: isReadOnly ? null : (value) {
            _saveAnswer(question.id, [value]);
          },
        ),
      ],
    );
  }

  /// Extract English words from text
  List<String> _extractWordsFromText(String text) {
    // Remove special characters and split by spaces
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

  /// Extract words from a practice question (questionText + options)
  List<String> _extractWordsFromQuestion(PracticeQuestion question) {
    final allText = <String>[];
    
    // Add question text
    allText.add(question.questionText);
    
    // Add all options
    allText.addAll(question.options);
    
    // Add correct answers
    allText.addAll(question.correctAnswers);
    
    // Extract words from all text
    final allWords = <String>{};
    for (final text in allText) {
      final words = _extractWordsFromText(text);
      allWords.addAll(words);
    }
    
    return allWords.toList()..sort();
  }

  /// Show word detail dialog when a word is selected
  Future<void> _showWordDetail(String selectedText) async {
    // Check if dialog is already open
    final dialogManager = DialogManager();
    if (!dialogManager.canOpenWordDetailDialog()) {
      return; // Dialog is already open, ignore this request
    }

    // Extract the word from selected text (remove punctuation, get first word)
    final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
    final match = wordPattern.firstMatch(selectedText.trim());
    if (match == null) return;
    
    final wordText = match.group(0)!.toLowerCase();
    
    try {
      // Search for the word in dictionary
      final words = await _dictionaryRepository.searchWord(wordText);
      
      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không tìm thấy từ "$wordText" trong từ điển'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Show the first matching word (should be exact match due to ranking)
      final word = words.first;
      
      if (mounted && dialogManager.canOpenWordDetailDialog()) {
        await showDialog(
          context: context,
          builder: (context) => WordDetailDialog(
            word: word,
            readingId: widget.readingId,
            readingQuizRepository: ReadingQuizRepository(),
          ),
        );
        // Dialog closed, flag is reset in dispose()
      }
    } catch (e) {
      print('Error showing word detail: $e');
      dialogManager.setWordDetailDialogOpen(false); // Reset on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Show dialog to extract words from current question and add to quiz
  @Deprecated('This feature has been removed. Use word selection instead.')
  Future<void> _showExtractWordsFromQuestionDialog(BuildContext context, PracticeQuestion question) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Extract words from question
      final extractedWords = _extractWordsFromQuestion(question);
      
      if (extractedWords.isEmpty) {
        Navigator.of(context).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy từ vựng nào trong câu hỏi này')),
          );
        }
        return;
      }

      // Search for words in repository
      final allWords = await _wordRepository.getAllWords();
      final wordMap = <String, Word>{};
      for (final word in allWords) {
        final key = word.en.toLowerCase();
        if (!wordMap.containsKey(key)) {
          wordMap[key] = word;
        }
      }

      final matchedWords = <Word>[];
      for (final extractedWord in extractedWords) {
        if (wordMap.containsKey(extractedWord)) {
          matchedWords.add(wordMap[extractedWord]!);
        }
      }

      Navigator.of(context).pop(); // Close loading dialog

      if (matchedWords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã trích xuất ${extractedWords.length} từ, nhưng không tìm thấy từ nào trong từ điển'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Show selection dialog
      Set<String> selectedWords = {};
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Trích xuất từ vựng từ câu hỏi'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đã tìm thấy ${matchedWords.length} từ trong câu hỏi:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chọn từ cần học:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (selectedWords.length == matchedWords.length) {
                              selectedWords.clear();
                            } else {
                              selectedWords = matchedWords.map((w) => w.en.toLowerCase()).toSet();
                            }
                          });
                        },
                        child: Text(
                          selectedWords.length == matchedWords.length
                              ? 'Bỏ chọn tất cả'
                              : 'Chọn tất cả',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: matchedWords.length,
                      itemBuilder: (context, index) {
                        final word = matchedWords[index];
                        final wordKey = word.en.toLowerCase();
                        final isSelected = selectedWords.contains(wordKey);
                        
                        return CheckboxListTile(
                          title: Text(
                            word.en,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(word.vi),
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedWords.add(wordKey);
                              } else {
                                selectedWords.remove(wordKey);
                              }
                            });
                          },
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: selectedWords.isEmpty
                    ? null
                    : () async {
                        final wordsToAdd = matchedWords.where(
                          (w) => selectedWords.contains(w.en.toLowerCase()),
                        ).toList();

                        if (wordsToAdd.isEmpty) {
                          Navigator.of(context).pop();
                          return;
                        }

                        // Add to ReadingQuizRepository (quiz riêng cho reading này)
                        final readingQuizRepo = ReadingQuizRepository();
                        final addedCount = await readingQuizRepo.addWordsToReadingQuiz(
                          widget.readingId,
                          wordsToAdd,
                        );
                        Navigator.of(context).pop();
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                addedCount > 0
                                    ? 'Đã thêm $addedCount từ vào quiz của bài reading này'
                                    : 'Không có từ nào được thêm (có thể đã tồn tại)',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                child: Text(
                  selectedWords.isEmpty
                      ? 'Chọn từ'
                      : 'Thêm ${selectedWords.length} từ vào Quiz',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

}

