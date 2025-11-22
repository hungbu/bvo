import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../model/practice_question.dart';
import '../../widget/selectable_text_with_word_lookup.dart' show TextWithWordLookup;
import '../../repository/dictionary_words_repository.dart';
import '../../service/dialog_manager.dart';
import '../dictionary/word_search_dialog.dart' show WordDetailDialog;

class ListenReadingDialog extends StatefulWidget {
  final List<PracticeQuestion> questions;

  const ListenReadingDialog({
    Key? key,
    required this.questions,
  }) : super(key: key);

  @override
  State<ListenReadingDialog> createState() => _ListenReadingDialogState();
}

class _ListenReadingDialogState extends State<ListenReadingDialog> {
  final FlutterTts _flutterTts = FlutterTts();
  final DictionaryWordsRepository _dictionaryRepository = DictionaryWordsRepository();
  bool _isPlaying = false;
  bool _isPaused = false;
  String _fullText = '';
  Completer<void>? _currentSentenceCompleter;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _prepareText();
  }

  @override
  void dispose() {
    // Stop TTS without setState since widget is being disposed
    _flutterTts.stop();
    // Safely complete completer if it exists
    if (_currentSentenceCompleter != null && !_currentSentenceCompleter!.isCompleted) {
      _currentSentenceCompleter!.complete();
    }
    _currentSentenceCompleter = null;
    super.dispose();
  }

  Future<void> _initializeTts() async {
    if (_isInitialized) return;
    
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.3); // Slow speed
      
      // Listen for completion
      _flutterTts.setCompletionHandler(() {
        if (mounted && _currentSentenceCompleter != null && !_currentSentenceCompleter!.isCompleted) {
          _currentSentenceCompleter!.complete();
        }
      });
      
      _isInitialized = true;
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  void _prepareText() {
    // Find first fillToSentence question
    final fillQuestion = widget.questions.firstWhere(
      (q) => q.type == QuestionType.fillToSentence,
      orElse: () => widget.questions.first,
    );

    if (fillQuestion.type != QuestionType.fillToSentence) {
      // If no fillToSentence, just use question text
      _fullText = fillQuestion.questionText;
      return;
    }

    // Fill correct answers into the sentence
    String filledText = fillQuestion.questionText;
    final blankPositions = fillQuestion.blankPositions ?? [];
    final correctAnswers = fillQuestion.correctAnswers;

    // Replace (1), (2), etc. with correct answers
    // blankPositions contains the position numbers (1, 2, 3...)
    // correctAnswers contains the answers in order
    for (int i = 0; i < blankPositions.length && i < correctAnswers.length; i++) {
      final position = blankPositions[i];
      final answer = correctAnswers[i];
      // Replace (position) with answer, keeping spaces around
      filledText = filledText.replaceAll('($position)', answer);
    }

    _fullText = filledText;
  }

  Future<void> _startPlayback() async {
    if (_fullText.isEmpty) return;

    if (mounted) {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });
    }

    await _playFullText();
  }

  Future<void> _playFullText() async {
    // Play the entire text as one continuous speech
    if (!_isPlaying || _isPaused) {
      return;
    }

    if (_fullText.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      return;
    }

    // Play the full text slowly
    _currentSentenceCompleter = Completer<void>();
    try {
      await _flutterTts.speak(_fullText);
      // Wait for completion
      await _currentSentenceCompleter!.future;
    } catch (e) {
      print('Error playing text: $e');
      if (_currentSentenceCompleter != null && !_currentSentenceCompleter!.isCompleted) {
        _currentSentenceCompleter!.complete();
      }
    }

    // After playing, wait 3 seconds and repeat if still playing
    if (_isPlaying && !_isPaused && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (_isPlaying && !_isPaused && mounted) {
        await _playFullText();
      }
    } else {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _pausePlayback() {
    if (mounted) {
      setState(() {
        _isPaused = true;
      });
    }
    _flutterTts.pause();
    // Safely complete completer if it exists and not completed
    if (_currentSentenceCompleter != null && !_currentSentenceCompleter!.isCompleted) {
      _currentSentenceCompleter!.complete();
    }
    _currentSentenceCompleter = null;
  }

  void _resumePlayback() {
    if (!_isPlaying) {
      _startPlayback();
      return;
    }
    if (mounted) {
      setState(() {
        _isPaused = false;
      });
    }
    _playFullText();
  }

  void _stopPlayback() {
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
      });
    }
    _flutterTts.stop();
    // Safely complete completer if it exists and not completed
    if (_currentSentenceCompleter != null && !_currentSentenceCompleter!.isCompleted) {
      _currentSentenceCompleter!.complete();
    }
    _currentSentenceCompleter = null;
  }

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
          builder: (context) => WordDetailDialog(word: word),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nghe đoạn văn',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _stopPlayback();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isPlaying || _isPaused)
                  ElevatedButton.icon(
                    onPressed: _isPaused ? _resumePlayback : _startPlayback,
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.play_circle_outline),
                    label: Text(_isPaused ? 'Tiếp tục' : 'Phát'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pausePlayback,
                    icon: const Icon(Icons.pause),
                    label: const Text('Tạm dừng'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _stopPlayback,
                  icon: const Icon(Icons.stop),
                  label: const Text('Dừng'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status indicator
            if (_isPlaying)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Đang phát...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else if (_isPaused)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause_circle_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Đã tạm dừng',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Text display with word lookup
            Expanded(
              child: SingleChildScrollView(
                child: TextWithWordLookup(
                  text: _fullText,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  onWordSelected: _showWordDetail,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

