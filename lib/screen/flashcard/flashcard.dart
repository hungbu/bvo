// lib/widgets/flashcard.dart
import 'dart:math';

import 'package:bvo/model/word.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Flashcard extends StatefulWidget {
  final Word word;

  const Flashcard({super.key, required this.word});

  @override
  _FlashcardState createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard> {
  bool _isFlipped = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    //_speakEnglish(); // Speak English word when card is displayed
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });

    if (_isFlipped) {
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
  }

  Future<void> _speakVietnamese() async {
    await _flutterTts.setLanguage("vi-VN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(widget.word.vi);
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
        child: _isFlipped
            ? _buildCardBack(widget.word)
            : _buildCardFront(widget.word),
      ),
    );
  }

  Widget _buildCardFront(Word word) {
    return Card(
      key: const ValueKey('front'),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: SizedBox(
          height: 145,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _speakEnglish();
                    },
                    icon: const Icon(Icons.volume_up, size: 32),
                    tooltip: 'Phát âm bình thường',
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      _speakEnglishSlow();
                    },
                    icon: const Icon(Icons.hearing, size: 32),
                    tooltip: 'Phát âm chậm',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                word.en,
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_red_eye_outlined),
                  const SizedBox(width: 8),
                  Text("Lượt xem: ${word.reviewCount}"),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(Word word) {
    return Card(
      key: const ValueKey('back'),
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
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
