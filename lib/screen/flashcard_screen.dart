import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';
import 'package:bvo/repository/user_progress_repository.dart';
import 'package:bvo/service/smart_notification_service.dart';
import 'package:bvo/service/gamification_service.dart';

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
  
  // Card flip and countdown state
  bool _isCardFlipped = false;
  int _countdownSeconds = 5;
  bool _isCountdownActive = false;
  bool _isCountdownPaused = false;
  
  // Countdown time settings (0s means auto-next, -1 means always pause)
  int _selectedCountdownTime = 5;
  final List<int> _countdownOptions = [-1, 0, 3, 5, 7, 10, 15];
  
  // Track if we're waiting for manual next after correct answer
  bool _waitingForManualNext = false;

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
    List<String>? savedWordsJson =
        _prefs.getStringList('words_${widget.topic}');
    if (savedWordsJson != null) {
      widget.words.clear();
      for (var wordJson in savedWordsJson) {
        widget.words.add(Word.fromJson(jsonDecode(wordJson)));
      }
      
      // Sort words by difficulty to ensure consistent order
      _sortWordsByDifficulty();
    } else {
      // Ensure words are sorted even when not loading from saved data
      _sortWordsByDifficulty();
      await saveWords();
    }
  }
  
  /// Sort words by difficulty (ascending), then by English word (alphabetical)
  void _sortWordsByDifficulty() {
    widget.words.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
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
      
      // 1. Update daily progress via UserProgressRepository (centralized)
      final progressRepo = UserProgressRepository();
      await progressRepo.updateTodayWordsLearned(widget.words.length);
      
      // 2. Update topic progress for the session  
      await progressRepo.updateTopicProgressBatch(widget.topic, widget.words.length);
      
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
      await _prefs.setInt('${sessionKey}_incorrect_answers', _incorrectAnswers);
      await _prefs.setInt('${sessionKey}_total_attempts', _totalAttempts);
      await _prefs.setDouble('${sessionKey}_accuracy', accuracy);
      await _prefs.setInt('${sessionKey}_duration_seconds', sessionDuration.inSeconds);
      await _prefs.setString('${sessionKey}_date', now.toIso8601String());
      
      // 5. Topic statistics are now handled by UserProgressRepository
      // via updateWordProgress() and updateTopicProgressBatch()
      print('📊 Session completed: ${widget.words.length} words, ${_correctAnswers}/${_totalAttempts} correct');
      
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


  /// Helper method để lấy danh sách từ khó (có tỷ lệ sai cao)
  Future<List<String>> getDifficultWords() async {
    List<String> difficultWords = [];
    final allKeys = _prefs.getKeys();
    
    // Sử dụng UserProgressRepository key pattern
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
              if (errorRate > 0.3) { // Từ có tỷ lệ sai > 30%
                // Extract word từ key: word_progress_topic_word
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



  // Hàm kiểm tra realtime - chỉ khi độ dài bằng nhau mới coi là trả lời
  void _checkAnswerRealtime() {
    String userAnswer = _controller.text.trim().toLowerCase();
    String correctAnswer = _currentWords[_currentIndex].en
        .trim()
        .toLowerCase()
        .replaceAll("-", " ");

    // Chỉ khi độ dài input = độ dài từ đúng thì mới coi là một lần trả lời
    if (userAnswer.length == correctAnswer.length) {
      // Gọi hàm kiểm tra chính thức để tính thống kê và xử lý
      _checkAnswerOfficial();
    } else {
      // Nếu độ dài chưa bằng nhau, chỉ clear feedback (không coi là trả lời)
      setState(() {
        _feedbackMessage = userAnswer.isEmpty ? '' : '';
      });
    }
  }

  // Hàm kiểm tra chính thức (tính thống kê) - chỉ gọi khi độ dài bằng nhau
  Future<void> _checkAnswerOfficial() async {
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
      
      // 1. Phát âm từ đúng
      await _speakEnglish(_currentWords[_currentIndex].en);
      
      // 2. Lật card qua mặt sau thay vì chuyển card ngay
      _flipCurrentCard();
    } else {
      // Update progress for incorrect answer
      await _progressRepository.updateWordProgress(
        widget.topic, 
        _currentWords[_currentIndex], 
        false
      );
      
      _incorrectAnswers++; // Track incorrect answers
      
      setState(() {
        _feedbackMessage = 'Try again.';
      });
    }
  }

  // Hàm wrapper để tương thích với onSubmitted
  Future<void> _checkAnswer() async {
    await _checkAnswerOfficial();
  }

  void _flipCurrentCard() {
    if (_selectedCountdownTime == 0) {
      // Timer off - immediately move to next card after a brief delay
      _nextSlide(delay: 1000); // 1 second delay to show feedback
    } else if (_selectedCountdownTime == -1) {
      // Always pause - flip card and wait for manual next
      setState(() {
        _isCardFlipped = true;
        _isCountdownActive = false;
        _isCountdownPaused = false;
        _waitingForManualNext = true;
      });
    } else {
      // Countdown mode - flip card but wait for user to start countdown
      setState(() {
        _isCardFlipped = true;
        _isCountdownActive = false;
        _isCountdownPaused = false;
        _waitingForManualNext = false;
      });
    }
  }
  
  void _startCountdown() {
    if (_countdownSeconds > 0 && !_isCountdownPaused) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isCountdownActive && !_isCountdownPaused) {
          setState(() {
            _countdownSeconds--;
          });
          
          if (_countdownSeconds > 0) {
            _startCountdown();
          } else {
            // Countdown finished, move to next card
            _nextSlide();
          }
        }
      });
    }
  }
  
  void _toggleCountdownPause() {
    setState(() {
      _isCountdownPaused = !_isCountdownPaused;
    });
    
    if (!_isCountdownPaused) {
      _startCountdown();
    }
  }

  void _showCountdownSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.settings, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Countdown Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: const Text(
                  'Choose how cards advance after you answer correctly:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Options
              ...(_countdownOptions.map((seconds) {
                final isSelected = _selectedCountdownTime == seconds;
                String title;
                String description;
                IconData icon;
                Color color;
                
                if (seconds == -1) {
                  title = 'Manual';
                  description = 'Use Next button to advance';
                  icon = Icons.pan_tool;
                  color = Colors.blue;
                } else if (seconds == 0) {
                  title = 'Auto';
                  description = 'Advance immediately';
                  icon = Icons.flash_on;
                  color = Colors.orange;
                } else {
                  title = '${seconds}s Timer';
                  description = 'Auto-advance after $seconds seconds';
                  icon = Icons.timer;
                  color = Colors.green;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCountdownTime = seconds;
                        _countdownSeconds = seconds;
                        if (_isCountdownActive && seconds == 0) {
                          _isCountdownActive = false;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? color : Colors.grey[400],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? color : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: color,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _startCountdownWithSettings() {
    if (_selectedCountdownTime == 0) {
      // Timer disabled - just flip card without countdown
      setState(() {
        _isCardFlipped = true;
        _isCountdownActive = false;
        _isCountdownPaused = false;
      });
      return;
    }
    
    setState(() {
      _isCardFlipped = true;
      _countdownSeconds = _selectedCountdownTime;
      _isCountdownActive = true;
      _isCountdownPaused = false;
    });
    
    _startCountdown();
  }
  
  void _resetCardState() {
    setState(() {
      _isCardFlipped = false;
      _countdownSeconds = _selectedCountdownTime;
      _isCountdownActive = false;
      _isCountdownPaused = false;
      _waitingForManualNext = false;
    });
  }

  // Next Button - Always visible and functional
  Widget _buildNextButton() {
    bool canProceed = _isCardFlipped || _waitingForManualNext || _selectedCountdownTime == 0;
    bool isActive = canProceed;
    
    return GestureDetector(
      onTap: isActive ? () {
        setState(() {
          _waitingForManualNext = false;
        });
        _nextSlide();
      } : null,
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

  // Countdown Settings Button - Shows current mode and provides access to settings
  Widget _buildCountdownSettingsButton() {
    String modeText;
    Color backgroundColor;
    Color textColor;
    
    if (_selectedCountdownTime == -1) {
      modeText = 'Manual';
      backgroundColor = Colors.blue[300]!;
      textColor = Colors.white;
    } else if (_selectedCountdownTime == 0) {
      modeText = 'Auto';
      backgroundColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
    } else {
      if (_isCountdownActive) {
        modeText = '${_countdownSeconds}s';
        backgroundColor = _isCountdownPaused ? Colors.orange : Colors.green;
        textColor = Colors.white;
      } else {
        // Show different state based on whether card is flipped and ready for countdown
        if (_isCardFlipped) {
          modeText = 'Start ${_selectedCountdownTime}s';
          backgroundColor = Colors.blue[600]!;
          textColor = Colors.white;
        } else {
          modeText = '${_selectedCountdownTime}s';
          backgroundColor = Colors.blue[300]!;
          textColor = Colors.white;
        }
      }
    }
    
    return GestureDetector(
      onTap: () {
        // For countdown mode, allow start/pause/resume
        if (_selectedCountdownTime > 0) {
          if (_isCountdownActive) {
            _toggleCountdownPause(); // Pause/resume if countdown is running
          } else {
            _startCountdownWithSettings(); // Start countdown if not running
          }
        } else {
          // For other modes (manual/auto), show settings
          _showCountdownSettings();
        }
      },
      onLongPress: _showCountdownSettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: backgroundColor == Colors.grey[300] 
              ? Colors.grey[400]! 
              : backgroundColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings,  // Always show settings icon to indicate it's for configuration
              size: 18,
              color: textColor,
            ),
            const SizedBox(width: 4),
            Text(
              modeText,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextSlide({int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_currentIndex < _currentWords.length - 1) {
        _resetCardState();
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
    
    // Trigger smart notification after learning session
    await _smartNotificationService.triggerAfterLearningSession(_currentWords.length, widget.topic);
    
    // Check for achievements
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
                    
                    // Correct answers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Câu đúng:'),
                          ],
                        ),
                        Text(
                          '$_correctAnswers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Incorrect answers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cancel, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Câu sai:'),
                          ],
                        ),
                        Text(
                          '$_incorrectAnswers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
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
                Navigator.pop(context, 'completed'); // Go back with result to trigger refresh
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
      _incorrectAnswers = 0;
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
        title: Text('FlashCard - ${widget.topic} (${_currentWords.length} từ)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),),
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
          isFlipped: index == _currentIndex ? _isCardFlipped : false,
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
          Row(
            children: [
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
              const SizedBox(width: 10),
              // Next Button (always visible)
              _buildNextButton(),
              const SizedBox(width: 8),
              // Countdown Settings Button
              _buildCountdownSettingsButton(),
            ],
          ),
          
          const SizedBox(height: 10),
          Text(
            _feedbackMessage,
            style: TextStyle(
              fontSize: 14,
              color:
                  _feedbackMessage == 'Correct!' ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
