import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';
import 'package:bvo/repository/user_progress_repository.dart';
import 'package:bvo/service/smart_notification_service.dart';
import 'package:bvo/service/gamification_service.dart';
import 'package:bvo/service/audio_service.dart';

class FlashCardScreen extends StatefulWidget {
  final List<Word> words;
  final String topic;
  final int startIndex;

  const FlashCardScreen({
    super.key,
    required this.words,
    required this.topic,
    this.startIndex = 0,
  });

  @override
  State<FlashCardScreen> createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  int _currentIndex = 0;
  final TextEditingController _controller = TextEditingController();
  String _feedbackMessage = '';
  final AudioService _audioService = AudioService();
  final CarouselSliderController _carouselController = CarouselSliderController();
  final FocusNode _inputFocusNode = FocusNode();
  late SharedPreferences _prefs;

  // Statistics tracking
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  int _totalAttempts = 0;
  DateTime? _sessionStartTime;

  // Flashcard settings
  bool _sessionHideEnglishText = false;

  // Pagination for 20 words limit
  List<Word> _currentWords = [];
  int _currentBatchIndex = 0;
  static const int _wordsPerBatch = 20;

  // Progress tracking
  final UserProgressRepository _progressRepository = UserProgressRepository();
  final SmartNotificationService _smartNotificationService = SmartNotificationService();
  final GamificationService _gamificationService = GamificationService();

  // Card flip state
  bool _isCardFlipped = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadWords();
    _initializeBatchIndex();
    _loadCurrentBatch();
    _sessionStartTime = DateTime.now();
    if (_currentWords.isNotEmpty) {
      _speakEnglish(_currentWords[0].en);
    }

    setState(() {
      _inputFocusNode.requestFocus();
    });
  }

  void _loadCurrentBatch() {
    int startIndex = _currentBatchIndex * _wordsPerBatch;
    int endIndex = (startIndex + _wordsPerBatch).clamp(0, widget.words.length);

    _currentWords = widget.words.sublist(startIndex, endIndex);
    _currentIndex = 0;
    _correctAnswers = 0;
    _incorrectAnswers = 0;
    _totalAttempts = 0;
    _sessionStartTime = DateTime.now();

    print('📚 Loading batch ${_currentBatchIndex + 1}: words $startIndex to ${endIndex - 1} (${_currentWords.length} words)');
    if (_currentWords.isNotEmpty) {
      print('📖 First word in batch: ${_currentWords[0].en}');
      print('📖 Last word in batch: ${_currentWords.last.en}');
    }
  }

  void _initializeBatchIndex() {
    _currentBatchIndex = widget.startIndex ~/ _wordsPerBatch;
    print('🎯 Initialized batch index: $_currentBatchIndex (startIndex: ${widget.startIndex})');
  }

  Future<void> loadWords() async {
    // DON'T reload from SharedPreferences - use the filtered list passed to this screen
    // This preserves the filtering (e.g., removing mastered words) done before launching FlashCardScreen
    print('📚 FlashCardScreen: Using ${widget.words.length} words passed to screen (already filtered)');
    
    // Don't sort - maintain the order from the caller (already sorted if needed)
    // Sorting by alphabet would put mastered words like "a" at the beginning
  }

  Future<void> saveWords() async {
    List<String> wordsJson = widget.words.map((word) => jsonEncode(word.toJson())).toList();
    await _prefs.setStringList('words_${widget.topic}', wordsJson);
  }

  Future<void> _saveCompletionStatistics(Duration sessionDuration, double accuracy) async {
    try {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';

      final progressRepo = UserProgressRepository();
      await progressRepo.updateTodayWordsLearned(widget.words.length);
      await progressRepo.updateTopicProgressBatch(widget.topic, widget.words.length);
      await _prefs.setBool('learned_$todayKey', true);

      final totalWords = _prefs.getInt('total_words_learned') ?? 0;
      await _prefs.setInt('total_words_learned', totalWords + widget.words.length);

      final sessionKey = 'session_${now.millisecondsSinceEpoch}';
      await _prefs.setString('${sessionKey}_topic', widget.topic);
      await _prefs.setInt('${sessionKey}_words_count', widget.words.length);
      await _prefs.setInt('${sessionKey}_correct_answers', _correctAnswers);
      await _prefs.setInt('${sessionKey}_incorrect_answers', _incorrectAnswers);
      await _prefs.setInt('${sessionKey}_total_attempts', _totalAttempts);
      await _prefs.setDouble('${sessionKey}_accuracy', accuracy);
      await _prefs.setInt('${sessionKey}_duration_seconds', sessionDuration.inSeconds);
      await _prefs.setString('${sessionKey}_date', now.toIso8601String());

      print('📊 Session completed: ${widget.words.length} words, ${_correctAnswers}/${_totalAttempts} correct');

      await _updateStreakStatistics();

      final bestAccuracy = _prefs.getDouble('${widget.topic}_best_accuracy') ?? 0.0;
      if (accuracy > bestAccuracy) {
        await _prefs.setDouble('${widget.topic}_best_accuracy', accuracy);
      }

      print('✅ Completion statistics saved successfully');
    } catch (e) {
      print('❌ Error saving completion statistics: $e');
    }
  }

  Future<void> _updateStreakStatistics() async {
    try {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final yesterdayKey = '${now.subtract(const Duration(days: 1)).year}-${now.subtract(const Duration(days: 1)).month}-${now.subtract(const Duration(days: 1)).day}';

      final learnedToday = _prefs.getBool('learned_$todayKey') ?? false;

      if (!learnedToday) {
        final currentStreak = _prefs.getInt('streak_days') ?? 0;
        final learnedYesterday = _prefs.getBool('learned_$yesterdayKey') ?? false;

        int newStreak;
        if (learnedYesterday || currentStreak == 0) {
          newStreak = currentStreak + 1;
        } else {
          newStreak = 1;
        }

        await _prefs.setInt('streak_days', newStreak);

        final longestStreak = _prefs.getInt('longest_streak') ?? 0;
        if (newStreak > longestStreak) {
          await _prefs.setInt('longest_streak', newStreak);
        }
      }

      final totalStudyTime = _prefs.getInt('total_study_time_seconds') ?? 0;
      final sessionDuration = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 0;
      await _prefs.setInt('total_study_time_seconds', totalStudyTime + sessionDuration);

    } catch (e) {
      print('❌ Error updating streak statistics: $e');
    }
  }

  Future<List<String>> getDifficultWords() async {
    List<String> difficultWords = [];
    final allKeys = _prefs.getKeys();

    for (String key in allKeys) {
      if (key.startsWith('word_progress_${widget.topic}_')) {
        final progressJson = _prefs.getString(key);
        if (progressJson != null) {
          try {
            final progress = Map<String, dynamic>.from(jsonDecode(progressJson));
            final totalAttempts = progress['totalAttempts'] ?? 0;
            final correctAnswers = progress['correctAnswers'] ?? 0;

            if (totalAttempts > 0) {
              final incorrectCount = totalAttempts - correctAnswers;
              final errorRate = incorrectCount / totalAttempts;
              if (errorRate > 0.3) {
                final keyParts = key.split('_');
                final wordEn = keyParts.sublist(3).join('_');
                difficultWords.add(wordEn);
              }
            }
          } catch (e) {
            print('❌ Error parsing progress for key $key: $e');
          }
        }
      }
    }

    print('🔍 Found ${difficultWords.length} difficult words in topic ${widget.topic}');
    return difficultWords;
  }

  @override
  void dispose() {
    _controller.dispose();
    // AudioService is singleton, no need to stop
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _speakEnglish(String text) async {
    await _audioService.speakNormal(text);
  }

  void _checkAnswerRealtime() {
    String userAnswer = _controller.text.trim().toLowerCase();
    String correctAnswer = _currentWords[_currentIndex].en
        .trim()
        .toLowerCase()
        .replaceAll("-", " ");

    if (userAnswer.length == correctAnswer.length) {
      _checkAnswerOfficial();
    } else {
      setState(() {
        _feedbackMessage = userAnswer.isEmpty ? '' : '';
      });
    }
  }

  Future<void> _checkAnswerOfficial() async {
    String userAnswer = _controller.text.trim().toLowerCase();
    String correctAnswer = _currentWords[_currentIndex].en
        .trim()
        .toLowerCase()
        .replaceAll("-", " ");

    _totalAttempts++;

    if (userAnswer == correctAnswer) {
      await _progressRepository.updateWordProgress(
          widget.topic,
          _currentWords[_currentIndex],
          true
      );

      _correctAnswers++;

      setState(() {
        _feedbackMessage = 'Correct!';
        _isCardFlipped = !_isCardFlipped; // Auto flip card when correct
      });

      await _speakEnglish(_currentWords[_currentIndex].en);

    } else {
      await _progressRepository.updateWordProgress(
          widget.topic,
          _currentWords[_currentIndex],
          false
      );

      _incorrectAnswers++;

      setState(() {
        _feedbackMessage = 'Try again.';
      });
    }
  }

  Future<void> _checkAnswer() async {
    await _checkAnswerOfficial();
  }

  void _resetCardState() {
    setState(() {
      _isCardFlipped = false;
    });
  }

  Widget _buildNextButton() {
    bool isActive = _isCardFlipped;

    return GestureDetector(
      onTap: isActive ? _nextSlide : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.grey[400],
          borderRadius: BorderRadius.circular(25),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_forward,
              size: 20,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              'Next',
              style: TextStyle(
                fontSize: 14,
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousButton() {
    bool isActive = _currentIndex > 0;

    return GestureDetector(
      onTap: isActive ? _previousSlide : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey[400],
          borderRadius: BorderRadius.circular(25),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back,
              size: 20,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              'Previous',
              style: TextStyle(
                fontSize: 14,
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextSlide() {
    if (_currentIndex < _currentWords.length - 1) {
      _resetCardState();
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
      _controller.clear();
      setState(() {
        _feedbackMessage = '';
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previousSlide() {
    if (_currentIndex > 0) {
      _resetCardState();
      _carouselController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
      _controller.clear();
      setState(() {
        _feedbackMessage = '';
      });
    }
  }

  void _showCompletionDialog() async {
    Duration sessionDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;

    double accuracy = _totalAttempts > 0
        ? (_correctAnswers / _totalAttempts * 100)
        : 0.0;

    await _saveCompletionStatistics(sessionDuration, accuracy);
    await _smartNotificationService.triggerAfterLearningSession(_currentWords.length, widget.topic);

    final totalWordsLearned = _prefs.getInt('total_words_learned') ?? 0;
    final streakDays = _prefs.getInt('streak_days') ?? 0;
    await _gamificationService.checkAchievements(
      wordsLearned: totalWordsLearned,
      streakDays: streakDays,
      accuracy: accuracy,
    );

    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.amber, size: 30),
              SizedBox(width: 10),
              Text(
                'Xuất sắc!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn đã hoàn thành ${_currentWords.length} từ trong chủ đề "${widget.topic}"',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Thống kê phiên học',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildStatRow(Icons.book, 'Số từ đã học:', '${_currentWords.length}', Colors.blue),
                      SizedBox(height: 8),
                      _buildStatRow(
                          Icons.track_changes,
                          'Độ chính xác:',
                          '${accuracy.toStringAsFixed(1)}%',
                          accuracy >= 80 ? Colors.green : accuracy >= 60 ? Colors.orange : Colors.red
                      ),
                      SizedBox(height: 8),
                      _buildStatRow(Icons.timer, 'Thời gian học:', formatDuration(sessionDuration), Colors.purple),
                      SizedBox(height: 8),
                      _buildStatRow(Icons.check_circle, 'Câu đúng:', '$_correctAnswers', Colors.green),
                      SizedBox(height: 8),
                      _buildStatRow(Icons.cancel, 'Câu sai:', '$_incorrectAnswers', Colors.red),
                      SizedBox(height: 8),
                      _buildStatRow(Icons.quiz, 'Tổng lượt trả lời:', '$_totalAttempts', Colors.orange),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, 'completed');
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _restartCurrentBatch();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Làm lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (_hasMoreWords())
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _loadNextBatch();
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Làm tiếp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 8),
            Text(label),
          ],
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _restartCurrentBatch() {
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _incorrectAnswers = 0;
      _totalAttempts = 0;
      _sessionStartTime = DateTime.now();
      _feedbackMessage = '';
      _controller.clear();
      _isCardFlipped = false;
    });

    _carouselController.animateToPage(0);

    if (_currentWords.isNotEmpty) {
      _speakEnglish(_currentWords[0].en);
    }

    _inputFocusNode.requestFocus();
  }

  bool _hasMoreWords() {
    int nextBatchStartIndex = (_currentBatchIndex + 1) * _wordsPerBatch;
    return nextBatchStartIndex < widget.words.length;
  }

  void _loadNextBatch() {
    if (_hasMoreWords()) {
      _currentBatchIndex++;
      _loadCurrentBatch();

      setState(() {
        _feedbackMessage = '';
        _controller.clear();
        _isCardFlipped = false;
      });

      _carouselController.animateToPage(0);

      if (_currentWords.isNotEmpty) {
        _speakEnglish(_currentWords[0].en);
      }

      _inputFocusNode.requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bắt đầu batch ${_currentBatchIndex + 1}: ${_currentWords.length} từ mới'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FlashCard - ${widget.topic} (${_currentWords.length} từ)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_sessionHideEnglishText ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _sessionHideEnglishText = !_sessionHideEnglishText;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_sessionHideEnglishText ? 'Ẩn từ tiếng Anh' : 'Hiện từ tiếng Anh'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: _sessionHideEnglishText ? 'Hiện từ tiếng Anh' : 'Ẩn từ tiếng Anh',
          ),
        ],
      ),
      body: _currentWords.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : bodyWidget(),
    );
  }

  Widget bodyWidget() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16.0),
          Expanded(
            flex: 4,
            child: flashCardWidget(),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: learnWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget flashCardWidget() {
    return CarouselSlider.builder(
      carouselController: _carouselController,
      itemCount: _currentWords.length,
      options: CarouselOptions(
        height: double.infinity,
        enlargeCenterPage: true,
        viewportFraction: 0.8,
        enableInfiniteScroll: false,
        onPageChanged: (index, reason) {
          setState(() {
            _currentIndex = index;
            _controller.clear();
            _feedbackMessage = '';
            _isCardFlipped = false;
            _speakEnglish(_currentWords[_currentIndex].en);
            _inputFocusNode.requestFocus();
          });
        },
      ),
      itemBuilder: (context, index, realIndex) {
        return Flashcard(
          word: _currentWords[index],
          sessionHideEnglishText: _sessionHideEnglishText,
          //isFlipped: index == _currentIndex ? _isCardFlipped : false,
          onAnswerSubmitted: (answer) {
            _checkAnswer();
          },
          onMastered: () {
            _removeWordFromList(_currentWords[index]);
          },
        );
      },
    );
  }

  Widget learnWidget() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildPreviousButton(),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Enter the English word',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    _checkAnswer();
                  },
                  onChanged: (value) => _checkAnswerRealtime(),
                ),
              ),
              
              
              const SizedBox(width: 8),
              _buildNextButton(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _feedbackMessage,
            style: TextStyle(
              fontSize: 14,
              color: _feedbackMessage == 'Correct!' ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeWordFromList(Word word) async {
    final removeIndex = _currentWords.indexWhere(
      (w) => w.en == word.en && w.topic == word.topic,
    );

    if (removeIndex == -1) return;

    setState(() {
      _currentWords.removeAt(removeIndex);

      // Adjust current index if needed
      if (_currentIndex > removeIndex) {
        _currentIndex--;
      }
      if (_currentIndex >= _currentWords.length) {
        _currentIndex = _currentWords.isEmpty ? 0 : _currentWords.length - 1;
      }

      // Reset states for next card
      _isCardFlipped = false;
      _feedbackMessage = '';
      _controller.clear();
    });

    // If no words remain, show completion dialog
    if (_currentWords.isEmpty) {
      _showCompletionDialog();
      return;
    }

    // Jump carousel to the adjusted index and focus input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carouselController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
      _speakEnglish(_currentWords[_currentIndex].en);
      _inputFocusNode.requestFocus();
    });
  }
}