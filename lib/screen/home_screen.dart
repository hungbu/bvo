import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For CupertinoIcons

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, List<Word>> reviewedWordsByTopic = {};

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    reviewedWordsByTopic =
        await WordRepository().getReviewedWordsGroupedByTopic();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Box of Your Vocabulary"),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            // navigator or show topic screen to choose topic screen
          },
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.orange, width: 1),
          ),
          tooltip: 'Add words',
          child: const Icon(Icons.add)),
      body: reviewedWordsByTopic.isEmpty
          ? const Center(
              child: Text(
                'No words have been reviewed yet.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: reviewedWordsByTopic.length,
              itemBuilder: (context, index) {
                String topic = reviewedWordsByTopic.keys.elementAt(index);
                List<Word> words = reviewedWordsByTopic[topic]!;
                return topicSection(topic, words);
              },
            ),
    );
  }

  Widget topicSection(String topic, List<Word> words) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        topic,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: words.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 items per row
              childAspectRatio: 2.5, // Increase this value to reduce height
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
            ),
            itemBuilder: (context, index) {
              final word = words[index];
              return wordCard(word);
            },
          ),
        ),
      ],
    );
  }

  Widget wordCard(Word word) {
    return GestureDetector(
      onTap: () {
        // Optionally, navigate to a detail screen for the word
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.en,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      word.vi,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.heart_fill,
                    size: 16,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${word.reviewCount}",
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(width: 16.0),
            ],
          ),
        ),
      ),
    );
  }
}
