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
    return ListView.builder(
      itemCount: words.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        final word = words[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.en,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
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
