// lib/widgets/flashcard.dart
import 'dart:math';

import 'package:bvo/model/word.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:bvo/repository/user_progress_repository.dart';

class Flashcard extends StatefulWidget {
  final Word word;
  final bool sessionHideEnglishText;
  final Function(String)? onAnswerSubmitted;
  final VoidCallback? onMastered; // Callback when user marks word as mastered
  final bool isFlipped;

  const Flashcard({
    super.key, 
    required this.word,
    this.sessionHideEnglishText = false,
    this.onAnswerSubmitted,
    this.onMastered,
    this.isFlipped = false,
  });

  @override
  _FlashcardState createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard> {
  bool _showEnglishText = true;
  bool _localIsFlipped = false; // Local flip state for manual flipping
  final FlutterTts _flutterTts = FlutterTts();
  int _actualReviewCount = 0;
  final UserProgressRepository _progressRepository = UserProgressRepository();

  @override
  void initState() {
    super.initState();
    _showEnglishText = !widget.sessionHideEnglishText; // Use session setting
    _loadActualReviewCount();
  }

  Future<void> _loadActualReviewCount() async {
    try {
      final progress = await _progressRepository.getWordProgress(widget.word.topic, widget.word.en);
      setState(() {
        _actualReviewCount = progress['reviewCount'] ?? 0;
      });
    } catch (e) {
      // If error, fall back to word.reviewCount
      setState(() {
        _actualReviewCount = widget.word.reviewCount;
      });
    }
  }

  @override
  void didUpdateWidget(Flashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update visibility when session setting changes
    if (oldWidget.sessionHideEnglishText != widget.sessionHideEnglishText) {
      setState(() {
        _showEnglishText = !widget.sessionHideEnglishText;
      });
    }
    
    // Reset local flip state when parent flips the card
    if (widget.isFlipped != oldWidget.isFlipped && widget.isFlipped) {
      setState(() {
        _localIsFlipped = false;
      });
    }
    
    // Reload review count if word changes
    if (widget.word.en != oldWidget.word.en) {
      _loadActualReviewCount();
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _flipCard() {
    // Don't allow manual flip when parent has control
    // if (widget.isFlipped) {
    //   return;
    // }
    
    // Flip local state
    setState(() {
      _localIsFlipped = !_localIsFlipped;
    });
    
    if (_localIsFlipped) {
      _speakVietnamese(); // Speak Vietnamese translation when card is flipped
    } else {
      _speakEnglish(); // Speak English word when flipping back
    }
  }

  Future<void> _speakEnglish() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // Normal speed
    await _flutterTts.speak(widget.word.en);
  }

  Future<void> _speakEnglishSlow() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.1); // Slow speed
    await _flutterTts.speak(widget.word.en);
    await Future.delayed(const Duration(seconds: 1));
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speakVietnamese() async {
    await _flutterTts.setLanguage("vi-VN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(widget.word.vi);
  }

  Future<void> _markAsMastered(Word word) async {
    try {
      // Get current progress
      final currentProgress = await _progressRepository.getWordProgress(word.topic, word.en);
      
      // Update to mastered status (reviewCount = 5)
      currentProgress['reviewCount'] = 5;
      currentProgress['isLearned'] = true;
      currentProgress['lastReviewed'] = DateTime.now().toIso8601String();
      
      // Save updated progress
      await _progressRepository.saveWordProgress(word.topic, word.en, currentProgress);
      
      print('✅ FlashCard: Marked "${word.en}" as mastered (reviewCount = 5)');
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Đã đánh dấu "${word.en}" là đã thuộc!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Notify parent to enable Next button
      if (widget.onMastered != null) {
        widget.onMastered!();
      }
      
      // No automatic card flipping - user must flip manually
      
    } catch (e) {
      print('❌ Error marking word as mastered: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Có lỗi xảy ra khi đánh dấu từ'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: 1.0, end: 0.0).animate(animation);
          return RotationYTransition(
            turns: rotate,
            child: child,
          );
        },
        child: _localIsFlipped
            ? _buildCardBack(widget.word)
            : _buildCardFront(widget.word),
      ),
    );
  }

  Widget _buildCardFront(Word word) {
    return Card(
      key: ValueKey('front-${widget.isFlipped}-$_localIsFlipped'),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audio controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          _speakEnglish();
                        },
                        icon: const Icon(Icons.volume_up, size: 28),
                        tooltip: 'Phát âm bình thường',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          _speakEnglishSlow();
                        },
                        icon: const Icon(Icons.hearing, size: 28),
                        tooltip: 'Phát âm chậm',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // English text (can be hidden)
                  AnimatedOpacity(
                    opacity: _showEnglishText ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _showEnglishText ? word.en : '???',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Phonetic pronunciation
                  AnimatedOpacity(
                    opacity: _showEnglishText ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _showEnglishText && word.pronunciation.isNotEmpty 
                          ? '/${word.pronunciation}/' 
                          : '',
                      style: TextStyle(
                        fontSize: 14, 
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        "Lượt xem: $_actualReviewCount",
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          // "Đã thuộc" button at top right
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // Mark word as mastered
                  await _markAsMastered(word);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Đã thuộc',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Word word) {
    return Card(
      key: ValueKey('back-${widget.isFlipped}-$_localIsFlipped'),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 3.2: Hiển thị từ tiếng Anh ở đầu (kích thước nhỏ hơn)
                    Text(
                      word.en,
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      word.vi,
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pronunciation: ${word.pronunciation}',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        'Sentence: ${word.sentence}',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 3.3: Hiển thị sentenceVi phía dưới sentence
                    Flexible(
                      child: Text(
                        'Nghĩa: ${word.sentenceVi}',
                        style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Topic: ${word.topic}',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// Helper widget for rotation animation
class RotationYTransition extends AnimatedWidget {
  const RotationYTransition({
    super.key,
    required Animation<double> turns,
    this.alignment = Alignment.center,
    required this.child,
  }) : super(listenable: turns);

  final Alignment alignment;
  final Widget child;

  Animation<double> get turns => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final double rotationValue = turns.value;
    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateY(rotationValue * pi);

    return Transform(
      transform: transform,
      alignment: alignment,
      child: child,
    );
  }
}
