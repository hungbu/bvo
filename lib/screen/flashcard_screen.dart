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

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadWords();
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
    String correctAnswer = widget.words[_currentIndex].en
        .trim()
        .toLowerCase()
        .replaceAll("-", " ");

    if (userAnswer == correctAnswer) {
      // Increment the reviewCount
      widget.words[_currentIndex].reviewCount += 1;

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
        setState(() {
          _feedbackMessage = 'You have reviewed all words in ${widget.topic}.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FlashCard - ${widget.topic}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
        return Flashcard(word: widget.words[index]);
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
