import 'package:bvo/model/topic.dart';
import 'package:bvo/repository/topic_repository.dart';
import 'package:bvo/screen/topic_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Topic> topics = [];

  @override
  void initState() {
    super.initState();

    init();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text("Bun Vocabulary"),
      ),
      body: ListView(
        children: getTopics,
      ),
    );
  }

  List<Widget> get getTopics {
    List<Widget> topicWidgets = [];

    if (topics.isNotEmpty) {
      for (var topic in topics) {
        topicWidgets.add(topicWidget(topic: topic.topic));
      }
    }

    List<Widget> result = [];
    // add a spacer
    result.add(const SizedBox(height: 20));
    // get 20 topics
    result = topicWidgets.take(20).toList();
    // add a spacer
    result.add(const SizedBox(height: 20));

    return result;
  }

  Widget topicWidget({required String topic}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TopicScreen(topic: topic)),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(topic),
        ),
      ),
    );
  }

  init() async {
    topics = await TopicRepository().getTopics();
    setState(() {});
  }
}
