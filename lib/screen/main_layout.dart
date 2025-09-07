import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'home_screen.dart';
import 'topic_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'profile_screen.dart';
import '../repository/topic_repository.dart';
import '../repository/word_repository.dart';
import '../model/topic.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // Danh sách các màn hình được build dynamically để pass callback
  List<Widget> get _screens => [
    HomeScreen(onTabChange: (index) => setState(() => _currentIndex = index)), // Home - Dashboard & Overview
    const TopicScreen(), // Topics - All topics list
    const QuizScreen(), // Quiz - Review & Testing unlearned words
    const ProfileScreen(), // Profile - Stats & Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        backgroundColor: Theme.of(context).primaryColor,
        activeColor: Colors.white,
        color: Colors.white70,
        height: 60,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.topic, title: 'Topics'),
          TabItem(icon: Icons.quiz, title: 'Quiz'),
          TabItem(icon: Icons.person, title: 'Profile'),
        ],
        initialActiveIndex: 0,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// Placeholder screens - bạn có thể thay thế bằng các screen thực tế
class LearnScreen extends StatelessWidget {
  const LearnScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Learn Screen',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

class FlashCardMainScreen extends StatefulWidget {
  const FlashCardMainScreen({Key? key}) : super(key: key);

  @override
  State<FlashCardMainScreen> createState() => _FlashCardMainScreenState();
}

class _FlashCardMainScreenState extends State<FlashCardMainScreen> {
  List<Topic> topics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final loadedTopics = await TopicRepository().getTopics();
      setState(() {
        topics = loadedTopics;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              backgroundColor: Theme.of(context).primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'FlashCard Learning',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : topics.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No topics available for FlashCard',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final topic = topics[index];
                              return _buildTopicCard(topic);
                            },
                            childCount: topics.length,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(Topic topic) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          // Load words for the topic first
          try {
            final words = await WordRepository().getWordsOfTopic(topic.topic);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FlashCardScreen(
                  words: words, 
                  topic: topic.topic,
                ),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading words: $e')),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Theme.of(context).primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz,
                size: 36,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  topic.topic,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Start Learning',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

