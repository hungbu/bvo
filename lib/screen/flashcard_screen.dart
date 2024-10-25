import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart'; // Ensure correct import

import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      CarouselSliderController(); // Updated controller
  final FocusNode _inputFocusNode = FocusNode();

  late List<Word> dueWords = [];
  int currentWordIndex = 0;
  bool showAnswer = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadWords();
    filterDueWords();
    if (dueWords.isNotEmpty) {
      _speakEnglish(dueWords[0].en);
    }
    setState(() {});
  }

  Future<void> loadWords() async {
    // Load words from SharedPreferences
    List<String>? savedWordsJson =
        _prefs.getStringList('words_${widget.topic}');
    if (savedWordsJson != null) {
      widget.words.clear();
      for (var wordJson in savedWordsJson) {
        widget.words.add(Word.fromJson(jsonDecode(wordJson)));
      }
    } else {
      // First time, save the initial words
      await saveWords();
    }
  }

  Future<void> saveWords() async {
    List<String> wordsJson =
        widget.words.map((word) => jsonEncode(word.toJson())).toList();
    await _prefs.setStringList('words_${widget.topic}', wordsJson);
  }

  void filterDueWords() {
    DateTime now = DateTime.now();
    dueWords = widget.words
        .where((word) =>
            word.nextReview.isBefore(now) ||
            word.nextReview.isAtSameMomentAs(now))
        .toList();
  }

  void updateWord(Word word, bool remembered) {
    if (remembered) {
      word.reviewCount += 1;
      int intervalDays = getIntervalDays(word.reviewCount);
      word.nextReview = DateTime.now().add(Duration(days: intervalDays));
    } else {
      word.reviewCount = 0;
      word.nextReview = DateTime.now().add(Duration(days: 1));
    }
  }

  int getIntervalDays(int reviewCount) {
    // Simple exponential backoff
    return pow(2, reviewCount).toInt();
  }

  void onRemembered(bool remembered) async {
    Word currentWord = dueWords[currentWordIndex];
    updateWord(currentWord, remembered);
    await saveWords();

    setState(() {
      showAnswer = false;
      if (currentWordIndex < dueWords.length - 1) {
        currentWordIndex += 1;
      } else {
        // No more words to review
        showCompletionDialog();
      }
    });
  }

  void showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tuyệt vời'),
          content: const Text('Bạn đã hoàn thành nhiệm vụ hôm nay'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to previous screen
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

  Future<void> _speakVietnamese(String text) async {
    await _flutterTts.stop();
    await _flutterTts.setLanguage("vi-VN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _checkAnswer() {
    String userAnswer = _controller.text.trim().toLowerCase();
    String correctAnswer =
        dueWords[_currentIndex].en.trim().toLowerCase().replaceAll("-", " ");

    if (userAnswer == correctAnswer) {
      updateWord(dueWords[_currentIndex], true);
      saveWords();
      setState(() {
        _feedbackMessage = 'Chính xác!';
      });
      _nextSlide();
    } else {
      setState(() {
        _feedbackMessage = 'Chưa đúng';
      });
    }
  }

  _nextSlide({int delay = 500}) {
// Move to the next slide after a short delay
    Future.delayed(Duration(milliseconds: delay), () {
      if (_currentIndex < dueWords.length - 1) {
        _carouselController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
        );

        // forcus input
        _controller.clear();
      } else {
        // Optionally, handle the end of the list
        setState(() {
          _feedbackMessage = 'bạn đã xem hết các từ của chủ đề ${widget.topic}';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return dueWords.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : bodyWidget();
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
      carouselController: _carouselController, // Assign the controller here
      itemCount: dueWords.length,
      options: CarouselOptions(
        height: double.infinity,
        enlargeCenterPage: true,
        viewportFraction: 0.8,
        onPageChanged: (index, reason) {
          setState(() {
            _currentIndex = index;
            _controller.clear();
            _feedbackMessage = '';
            _speakEnglish(dueWords[_currentIndex].en);
            _inputFocusNode.requestFocus();
          });
        },
      ),
      itemBuilder: (context, index, realIndex) {
        return Flashcard(word: dueWords[index]);
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
              labelText: 'Điền từ tiếng anh',
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
              color: _feedbackMessage == 'Chính xác!'
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () {
                updateWord(dueWords[_currentIndex], true);
                saveWords();
                _nextSlide(delay: 0);
              },
              child: Text("Đã thuộc"))
        ],
      ),
    );
  }
}
