import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart'; // Ensure correct import

import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';

class LearnScreen extends StatefulWidget {
  final List<Word> words;
  final String topic;

  const LearnScreen({Key? key, required this.words, required this.topic})
      : super(key: key);

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late List<Word> words = [];
  int _currentIndex = 0;
  final TextEditingController _controller = TextEditingController();
  String _feedbackMessage = '';
  final FlutterTts _flutterTts = FlutterTts();
  final CarouselSliderController _carouselController =
      CarouselSliderController(); // Updated controller
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _flutterTts.stop();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> init() async {
    words = await WordRepository().getWordsOfTopic(widget.topic);
    setState(() {});
    if (words.isNotEmpty) {
      _speakEnglish(words[0].en);
    }
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
    String correctAnswer = words[_currentIndex].en.trim().toLowerCase();

    if (userAnswer == correctAnswer) {
      setState(() {
        _feedbackMessage = 'Correct!';
      });
      // Move to the next slide after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (_currentIndex < words.length - 1) {
          _carouselController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.linear,
          );

          // forcus input
          _controller.clear();
        } else {
          // Optionally, handle the end of the list
          setState(() {
            _feedbackMessage = 'You have completed all cards!';
          });
        }
      });
    } else {
      setState(() {
        _feedbackMessage = 'Incorrect. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Learn ${widget.topic}"),
      ),
      body: words.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : bodyWidget(),
    );
  }

  Widget bodyWidget() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: flashCardWidget(),
          ),
          Expanded(
            flex: 3,
            child: learnWidget(),
          ),
        ],
      ),
    );
  }

  Widget flashCardWidget() {
    return CarouselSlider.builder(
      carouselController: _carouselController, // Assign the controller here
      itemCount: words.length,
      options: CarouselOptions(
        height: double.infinity,
        enlargeCenterPage: true,
        viewportFraction: 0.8,
        onPageChanged: (index, reason) {
          setState(() {
            _currentIndex = index;
            _controller.clear();
            _feedbackMessage = '';
            _speakEnglish(words[_currentIndex].en);
            _inputFocusNode.requestFocus();
          });
        },
      ),
      itemBuilder: (context, index, realIndex) {
        return Flashcard(word: words[index]);
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
            decoration: const InputDecoration(
              labelText: 'Enter the English word',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              _checkAnswer();
            },
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _checkAnswer,
            child: const Text('Check'),
          ),
          const SizedBox(height: 10),
          Text(
            _feedbackMessage,
            style: TextStyle(
              fontSize: 18,
              color: _feedbackMessage == 'Correct!' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
