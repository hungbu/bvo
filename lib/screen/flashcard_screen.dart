import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';

class FlashCardScreen extends StatefulWidget {
  final List<Word> words;
  final String topic;

  const FlashCardScreen({super.key, required this.words, required this.topic});

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

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadWords();
    _sessionStartTime = DateTime.now(); // Start tracking session time
    if (widget.words.isNotEmpty) {
      _speakEnglish(widget.words[0].en);
    }

    setState(() {
      _inputFocusNode.requestFocus();
    });
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


  void _checkAnswer() {
    String userAnswer = _controller.text.trim().toLowerCase();
    String correctAnswer = widget.words[_currentIndex].en
        .trim()
        .toLowerCase()
        .replaceAll("-", " ");

    _totalAttempts++; // Track total attempts

    if (userAnswer == correctAnswer) {
      // Update the word with incremented reviewCount using copyWith
      widget.words[_currentIndex] = widget.words[_currentIndex].copyWith(
        reviewCount: widget.words[_currentIndex].reviewCount + 1,
        correctAnswers: widget.words[_currentIndex].correctAnswers + 1,
        totalAttempts: widget.words[_currentIndex].totalAttempts + 1,
        lastReviewed: DateTime.now(),
      );
      _correctAnswers++; // Track correct answers

      // Save the updated words
      saveWords();

      setState(() {
        _feedbackMessage = 'Correct!';
      });
      _nextSlide();
    } else {
      setState(() {
        _feedbackMessage = 'Try again.';
      });
    }
  }

  void _nextSlide({int delay = 500}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_currentIndex < widget.words.length - 1) {
        _carouselController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
        );
        _controller.clear();
      } else {
        // Show completion dialog instead of just text message
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
                'Bạn đã hoàn thành chủ đề "${widget.topic}"',
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
                          '${widget.words.length}',
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
                _restartSession();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Học lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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

  void _restartSession() {
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
    if (widget.words.isNotEmpty) {
      _speakEnglish(widget.words[0].en);
    }
    
    // Focus input
    _inputFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FlashCard - ${widget.topic}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
      body: widget.words.isEmpty 
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
      itemCount: widget.words.length,
      options: CarouselOptions(
        height: double.infinity,
        enlargeCenterPage: true,
        viewportFraction: 0.8,
        onPageChanged: (index, reason) {
          setState(() {
            _currentIndex = index;
            _controller.clear();
            _feedbackMessage = '';
            _speakEnglish(widget.words[_currentIndex].en);
            _inputFocusNode.requestFocus();
          });
        },
      ),
      itemBuilder: (context, index, realIndex) {
        return Flashcard(
          word: widget.words[index],
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
