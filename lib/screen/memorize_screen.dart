import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';

class MemorizeScreen extends StatefulWidget {
  final String topic;
  final List<Word> words;

  const MemorizeScreen({Key? key, required this.topic, required this.words})
      : super(key: key);

  @override
  _MemorizeScreenState createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends State<MemorizeScreen> {
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
          title: const Text('Well Done!'),
          content: const Text('You have completed all due words for today.'),
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
  Widget build(BuildContext context) {
    if (dueWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Memorize ${widget.topic}')),
        body: const Center(
          child: Text('No words due for review today!'),
        ),
      );
    }

    Word currentWord = dueWords[currentWordIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Memorize ${widget.topic}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    showAnswer ? currentWord.vi : currentWord.en,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!showAnswer)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showAnswer = true;
                    });
                  },
                  child: const Text('Show Answer'),
                )
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        onRemembered(true);
                      },
                      child: const Text('I remembered'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        onRemembered(false);
                      },
                      child: const Text('I forgot'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
