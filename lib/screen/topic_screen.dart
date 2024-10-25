import 'package:bvo/screen/memorize_screen.dart';
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/screen/flashcard_screen.dart';

class TopicScreen extends StatefulWidget {
  final String topic;
  const TopicScreen({super.key, required this.topic});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  List<Word> words = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    words = await WordRepository().getWordsOfTopic(widget.topic);
    setState(() {});
  }

  // Define the list of pages
  final List<Widget> _pages = [];

  @override
  Widget build(BuildContext context) {
    // Initialize _pages after words are loaded
    _pages.clear();
    _pages.addAll([
      listWord(),
      flashCardPage(),
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(widget.topic)),
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        items: const [
          TabItem(icon: Icons.list, title: 'Words'),
          TabItem(icon: Icons.rate_review, title: 'PlashCard'),
        ],
        initialActiveIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
            if (_currentIndex == 0 && words.isEmpty) {
              init();
            }
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      MemorizeScreen(topic: widget.topic, words: words)),
            );
          },
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.orange, width: 1),
          ),
          tooltip: 'Memorize',
          child: const Icon(Icons.note_alt_outlined)),
    );
  }

  Widget listWord() {
    return ListView.builder(
      itemCount: words.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        final word = words[index];
        return Card(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.en,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.deepPurple,
                  ),
                ),
                Text(
                  word.vi,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget flashCardPage() {
    // Placeholder for the Review page
    return FlashCardScreen(topic: widget.topic, words: words);
  }
}
