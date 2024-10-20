import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/screen/learn_screen.dart';
import 'package:flutter/material.dart';

class TopicScreen extends StatefulWidget {
  final String topic;
  const TopicScreen({super.key, required this.topic});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  List<Word> words = [];

  @override
  void initState() {
    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.topic),
        ),
        body: listWord(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      LearnScreen(topic: widget.topic, words: words)),
            );
          },
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.green, width: 1),
          ),
          tooltip: 'Learn',
          child: const Icon(Icons.note_alt_outlined),
        ));
  }

  Widget listWord() {
    return GridView.builder(
      itemCount: words.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Maximum 2 cards per row
        childAspectRatio: 3 / 2, // Adjust the aspect ratio as needed
        mainAxisSpacing: 4.0, // Space between rows
        crossAxisSpacing: 4.0, // Space between columns
      ),
      padding: const EdgeInsets.all(4.0),
      itemBuilder: (context, index) {
        final word = words[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word.en,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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

  init() async {
    words = await WordRepository().getWordsOfTopic(widget.topic);
    setState(() {});
  }
}
