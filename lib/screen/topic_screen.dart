import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
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
      body: Text(widget.topic),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TopicScreen(topic: widget.topic)),
          );
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.black, width: 2),
        ),
        tooltip: 'Learn',
        child: const Icon(Icons.note_alt_outlined),
      )
    );
  }



  init() async {
    words = await WordRepository().getWordsOfTopic(widget.topic);
  }
}
