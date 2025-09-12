import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';
import 'package:bvo/repository/user_progress_repository.dart';

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
  final FlutterTts _flutterTts = FlutterTts();
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  final FocusNode _inputFocusNode = FocusNode();
  late SharedPreferences _prefs;
  
  // Statistics tracking
  int _correctAnswers = 0;
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

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadWords();
    _initializeBatchIndex(); // Initialize batch index first
    _loadCurrentBatch();
    _sessionStartTime = DateTime.now(); // Start tracking session time
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
    List<String>? savedWordsJson =
        _prefs.getStringList('words_${widget.topic}');
    if (savedWordsJson != null) {
      widget.words.clear();
      for (var wordJson in savedWordsJson) {
        widget.words.add(Word.fromJson(jsonDecode(wordJson)));
      }
    } else {
      await saveWords();
    }
  }

  Future<void> saveWords() async {
    List<String> wordsJson =
        widget.words.map((word) => jsonEncode(word.toJson())).toList();
    await _prefs.setStringList('words_${widget.topic}', wordsJson);
  }


  Future<void> _saveCompletionStatistics(Duration sessionDuration, double accuracy) async {
    try {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      
      // 1. Update daily progress
      final currentWordsLearned = _prefs.getInt('words_learned_$todayKey') ?? 0;
      await _prefs.setInt('words_learned_$todayKey', currentWordsLearned + widget.words.length);
      
      // 2. Mark today as learned
      await _prefs.setBool('learned_$todayKey', true);
      
      // 3. Update total words learned
      final totalWords = _prefs.getInt('total_words_learned') ?? 0;
      await _prefs.setInt('total_words_learned', totalWords + widget.words.length);
      
      // 4. Save session statistics
      final sessionKey = 'session_${now.millisecondsSinceEpoch}';
      await _prefs.setString('${sessionKey}_topic', widget.topic);
      await _prefs.setInt('${sessionKey}_words_count', widget.words.length);
      await _prefs.setInt('${sessionKey}_correct_answers', _correctAnswers);
      await _prefs.setInt('${sessionKey}_total_attempts', _totalAttempts);
      await _prefs.setDouble('${sessionKey}_accuracy', accuracy);
      await _prefs.setInt('${sessionKey}_duration_seconds', sessionDuration.inSeconds);
      await _prefs.setString('${sessionKey}_date', now.toIso8601String());
      
      // 5. Update topic-specific statistics
      final topicCorrect = _prefs.getInt('${widget.topic}_correct_answers') ?? 0;
      final topicTotal = _prefs.getInt('${widget.topic}_total_attempts') ?? 0;
      final topicSessions = _prefs.getInt('${widget.topic}_sessions') ?? 0;
      
      await _prefs.setInt('${widget.topic}_correct_answers', topicCorrect + _correctAnswers);
      await _prefs.setInt('${widget.topic}_total_attempts', topicTotal + _totalAttempts);
      await _prefs.setInt('${widget.topic}_sessions', topicSessions + 1);
      await _prefs.setString('${widget.topic}_last_studied', now.toIso8601String());
      
      // 6. Update streak and learning statistics
      await _updateStreakStatistics();
      
      // 7. Save best accuracy for this topic
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
      
      // Check if already learned today
      final learnedToday = _prefs.getBool('learned_$todayKey') ?? false;
      
      if (!learnedToday) {
        // First session today, update streak
        final currentStreak = _prefs.getInt('streak_days') ?? 0;
        final learnedYesterday = _prefs.getBool('learned_$yesterdayKey') ?? false;
        
        int newStreak;
        if (learnedYesterday || currentStreak == 0) {
          // Continue streak or start new one
          newStreak = currentStreak + 1;
        } else {
          // Streak broken, restart
          newStreak = 1;
        }
        
        await _prefs.setInt('streak_days', newStreak);
        
        // Update longest streak
        final longestStreak = _prefs.getInt('longest_streak') ?? 0;
        if (newStreak > longestStreak) {
          await _prefs.setInt('longest_streak', newStreak);
        }
      }
      
      // Update total study time
      final totalStudyTime = _prefs.getInt('total_study_time_seconds') ?? 0;
      final sessionDuration = _sessionStartTime != null 
          ? DateTime.now().difference(_sessionStartTime!).inSeconds 
          : 0;
      await _prefs.setInt('total_study_time_seconds', totalStudyTime + sessionDuration);
      
    } catch (e) {
      print('❌ Error updating streak statistics: $e');
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    _flutterTts.stop();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _speakEnglish(String text) async {
    await _flutterTts.stop();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }



  Future<void> _checkAnswer() async {
    String userAnswer = _controller.text.trim().toLowerCase();
    String correctAnswer = _currentWords[_currentIndex].en
        .trim()
        .toLowerCase()
        .replaceAll("-", " ");

    _totalAttempts++; // Track total attempts

    if (userAnswer == correctAnswer) {
      // Update progress using UserProgressRepository
      await _progressRepository.updateWordProgress(
        widget.topic, 
        _currentWords[_currentIndex], 
        true
      );
      
      _correctAnswers++; // Track correct answers

      setState(() {
        _feedbackMessage = 'Correct!';
      });
      _nextSlide();
    } else {
      // Update progress for incorrect answer
      // await _progressRepository.updateWordProgress(
      //   widget.topic, 
      //   _currentWords[_currentIndex], 
      //   false
      // );
      
      setState(() {
        _feedbackMessage = 'Try again.';
      });
    }
  }

  void _nextSlide({int delay = 500}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_currentIndex < _currentWords.length - 1) {
        _carouselController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
        );
        _controller.clear();
      } else {
        // Show completion dialog for current batch
        _showCompletionDialog();
      }
    });
  }

  void _showCompletionDialog() async {
    // Calculate session statistics
    Duration sessionDuration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!) 
        : Duration.zero;
    
    double accuracy = _totalAttempts > 0 
        ? (_correctAnswers / _totalAttempts * 100) 
        : 0.0;

    // Save completion statistics to SharedPreferences
    await _saveCompletionStatistics(sessionDuration, accuracy);

    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.celebration,
                color: Colors.amber,
                size: 30,
              ),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 20),
              
              // Statistics section
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
                    
                    // Words learned
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.book, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Số từ đã học:'),
                          ],
                        ),
                        Text(
                          '${_currentWords.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Accuracy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.track_changes, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Độ chính xác:'),
                          ],
                        ),
                        Text(
                          '${accuracy.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: accuracy >= 80 ? Colors.green : 
                                   accuracy >= 60 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Session time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, size: 20, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Thời gian học:'),
                          ],
                        ),
                        Text(
                          formatDuration(sessionDuration),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Total attempts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.quiz, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Tổng lượt trả lời:'),
                          ],
                        ),
                        Text(
                          '$_totalAttempts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
          actions: [
            // Back to Topics button
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            
            // Study Again button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _restartCurrentBatch();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Làm lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            // Continue with next batch button (if available)
            if (_hasMoreWords())
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _loadNextBatch();
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Làm tiếp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _restartCurrentBatch() {
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _totalAttempts = 0;
      _sessionStartTime = DateTime.now();
      _feedbackMessage = '';
      _controller.clear();
    });
    
    // Reset carousel to first card
    _carouselController.animateToPage(0);
    
    // Speak first word
    if (_currentWords.isNotEmpty) {
      _speakEnglish(_currentWords[0].en);
    }
    
    // Focus input
    _inputFocusNode.requestFocus();
  }
  
  bool _hasMoreWords() {
    int nextBatchStartIndex = (_currentBatchIndex + 1) * _wordsPerBatch;
    return nextBatchStartIndex < widget.words.length;
  }
  
  void _loadNextBatch() {
    print('🔄 _loadNextBatch called. Current batch: $_currentBatchIndex');
    print('📊 Total words: ${widget.words.length}, Has more: ${_hasMoreWords()}');
    
    if (_hasMoreWords()) {
      int oldBatchIndex = _currentBatchIndex;
      _currentBatchIndex++;
      print('⬆️ Incrementing batch from $oldBatchIndex to $_currentBatchIndex');
      
      _loadCurrentBatch();
      
      setState(() {
        _feedbackMessage = '';
        _controller.clear();
      });
      
      // Reset carousel to first card of new batch
      _carouselController.animateToPage(0);
      
      // Speak first word of new batch
      if (_currentWords.isNotEmpty) {
        _speakEnglish(_currentWords[0].en);
        print('🔊 Speaking first word of new batch: ${_currentWords[0].en}');
      }
      
      // Focus input
      _inputFocusNode.requestFocus();
      
      // Show info about new batch
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bắt đầu batch ${_currentBatchIndex + 1}: ${_currentWords.length} từ mới'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      print('❌ No more words available');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FlashCard - ${widget.topic} (${_currentWords.length} từ)'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Hide English Text Toggle
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
        onPageChanged: (index, reason) {
          setState(() {
            _currentIndex = index;
            _controller.clear();
            _feedbackMessage = '';
            _speakEnglish(_currentWords[_currentIndex].en);
            _inputFocusNode.requestFocus();
          });
        },
      ),
      itemBuilder: (context, index, realIndex) {
        return Flashcard(
          word: _currentWords[index],
          sessionHideEnglishText: _sessionHideEnglishText,
          onAnswerSubmitted: (answer) {
            _checkAnswer();
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
          TextField(
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
            onChanged: (value) => _checkAnswer(),
          ),
          const SizedBox(height: 10),
          Text(
            _feedbackMessage,
            style: TextStyle(
              fontSize: 18,
              color:
                  _feedbackMessage == 'Correct!' ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
