import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For CupertinoIcons

import 'package:bvo/model/word.dart';
import 'package:bvo/model/topic.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/repository/topic_repository.dart';
import 'package:bvo/screen/topic_screen.dart';

class HomeContent extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const HomeContent({super.key, this.onTabChange});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  Map<String, List<Word>> reviewedWordsByTopic = {};
  List<Topic> topics = [];
  bool isLoadingTopics = true;
  bool showAllTopics = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _loadReviewedWords();
  }

  Future<void> _loadTopics() async {
    try {
      print("Starting to load topics...");
      final loadedTopics = await TopicRepository().getTopics();
      print("Loaded ${loadedTopics.length} topics: ${loadedTopics.map((t) => t.topic).toList()}");
      if (mounted) {
        setState(() {
          topics = loadedTopics;
          isLoadingTopics = false;
        });
      }
    } catch (e) {
      print("Error loading topics: $e");
      if (mounted) {
        setState(() {
          isLoadingTopics = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading topics: $e')),
        );
      }
    }
  }

  Future<void> _loadReviewedWords() async {
    try {
      final reviewed = await WordRepository().getReviewedWordsGroupedByTopic();
      setState(() {
        reviewedWordsByTopic = reviewed;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reviewed words: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Continue your vocabulary journey',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          'FlashCard',
                          Icons.quiz,
                          () {
                            // Use callback to parent to change tab
                            if (widget.onTabChange != null) {
                              widget.onTabChange!(1);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionButton(
                          'Memorize',
                          Icons.psychology,
                          () {
                            // Use callback to parent to change tab
                            if (widget.onTabChange != null) {
                              widget.onTabChange!(2);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Topics',
                    topics.length.toString(),
                    Icons.topic,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Words Learned',
                    reviewedWordsByTopic.values
                        .fold<int>(0, (sum, words) => sum + words.length)
                        .toString(),
                    Icons.school,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Topics Section
            const Text(
              'Your Topics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (isLoadingTopics)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (topics.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No topics available yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: showAllTopics ? topics.length : (topics.length > 6 ? 6 : topics.length),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final reviewedCount = reviewedWordsByTopic[topic.topic]?.length ?? 0;
                  
                  return _buildTopicCard(topic, reviewedCount);
                },
              ),

            if (topics.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        showAllTopics = !showAllTopics;
                      });
                    },
                    icon: Icon(
                      showAllTopics ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).primaryColor,
                    ),
                    label: Text(
                      showAllTopics ? 'Show Less' : 'View All Topics (${topics.length})',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(Topic topic, int reviewedCount) {
    // Get topic-specific data
    final topicData = _getTopicData(topic.topic);
    final totalWords = topicData['totalWords'] as int;
    final difficulty = topicData['difficulty'] as String;
    final icon = topicData['icon'] as IconData;
    final color = topicData['color'] as Color;
    final estimatedTime = topicData['estimatedTime'] as String;
    
    // Calculate progress
    final progress = totalWords > 0 ? (reviewedCount / totalWords).clamp(0.0, 1.0) : 0.0;
    final progressPercentage = (progress * 100).round();
    
    // Determine completion status
    final isCompleted = progress >= 1.0;
    final isStarted = reviewedCount > 0;
    
    return Card(
      elevation: 3,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicScreen(topic: topic.topic),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 8),
                          SizedBox(width: 1),
                          Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isStarted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Learning',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 6),
              
              // Topic title
              Text(
                topic.topic.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Difficulty and time
              Row(
                children: [
                  _buildDifficultyStars(difficulty),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 10,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    estimatedTime,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),
              
              // Progress section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '$reviewedCount/$totalWords words',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$progressPercentage%',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyStars(String difficulty) {
    int stars = difficulty == 'Beginner' ? 1 : 
                difficulty == 'Intermediate' ? 2 : 3;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          size: 10,
          color: index < stars ? Colors.amber : Colors.grey[400],
        );
      }),
    );
  }

  Map<String, dynamic> _getTopicData(String topicName) {
    // Topic-specific configurations
    final topicConfigs = {
      'schools': {
        'totalWords': 25,
        'difficulty': 'Beginner',
        'icon': Icons.school,
        'color': Colors.blue,
        'estimatedTime': '15 min',
      },
      'examination': {
        'totalWords': 20,
        'difficulty': 'Intermediate',
        'icon': Icons.quiz,
        'color': Colors.orange,
        'estimatedTime': '12 min',
      },
      'extracurricular': {
        'totalWords': 18,
        'difficulty': 'Intermediate',
        'icon': Icons.sports_soccer,
        'color': Colors.green,
        'estimatedTime': '10 min',
      },
      'school stationery': {
        'totalWords': 22,
        'difficulty': 'Beginner',
        'icon': Icons.edit,
        'color': Colors.purple,
        'estimatedTime': '13 min',
      },
      'school subjects': {
        'totalWords': 15,
        'difficulty': 'Beginner',
        'icon': Icons.book,
        'color': Colors.indigo,
        'estimatedTime': '8 min',
      },
      'classroom': {
        'totalWords': 28,
        'difficulty': 'Beginner',
        'icon': Icons.class_,
        'color': Colors.teal,
        'estimatedTime': '18 min',
      },
      'universities': {
        'totalWords': 30,
        'difficulty': 'Advanced',
        'icon': Icons.account_balance,
        'color': Colors.deepPurple,
        'estimatedTime': '20 min',
      },
      'body': {
        'totalWords': 35,
        'difficulty': 'Beginner',
        'icon': Icons.accessibility,
        'color': Colors.pink,
        'estimatedTime': '22 min',
      },
      'appearance': {
        'totalWords': 25,
        'difficulty': 'Intermediate',
        'icon': Icons.face,
        'color': Colors.cyan,
        'estimatedTime': '15 min',
      },
      'characteristics': {
        'totalWords': 20,
        'difficulty': 'Advanced',
        'icon': Icons.psychology,
        'color': Colors.amber,
        'estimatedTime': '12 min',
      },
      'age': {
        'totalWords': 12,
        'difficulty': 'Beginner',
        'icon': Icons.cake,
        'color': Colors.brown,
        'estimatedTime': '6 min',
      },
      'feelings': {
        'totalWords': 30,
        'difficulty': 'Intermediate',
        'icon': Icons.sentiment_satisfied,
        'color': Colors.red,
        'estimatedTime': '18 min',
      },
      'family': {
        'totalWords': 18,
        'difficulty': 'Beginner',
        'icon': Icons.family_restroom,
        'color': Colors.lightGreen,
        'estimatedTime': '10 min',
      },
      'relationships': {
        'totalWords': 22,
        'difficulty': 'Advanced',
        'icon': Icons.favorite,
        'color': Colors.pinkAccent,
        'estimatedTime': '14 min',
      },
      'colors': {
        'totalWords': 15,
        'difficulty': 'Beginner',
        'icon': Icons.palette,
        'color': Colors.deepOrange,
        'estimatedTime': '8 min',
      },
      'shapes': {
        'totalWords': 12,
        'difficulty': 'Beginner',
        'icon': Icons.category,
        'color': Colors.blueGrey,
        'estimatedTime': '6 min',
      },
      'numbers': {
        'totalWords': 20,
        'difficulty': 'Beginner',
        'icon': Icons.numbers,
        'color': Colors.lime,
        'estimatedTime': '12 min',
      },
      'ordinal numbers': {
        'totalWords': 15,
        'difficulty': 'Intermediate',
        'icon': Icons.format_list_numbered,
        'color': Colors.lightBlue,
        'estimatedTime': '8 min',
      },
      'days of the week': {
        'totalWords': 7,
        'difficulty': 'Beginner',
        'icon': Icons.calendar_today,
        'color': Colors.deepPurpleAccent,
        'estimatedTime': '4 min',
      },
    };

    return topicConfigs[topicName.toLowerCase()] ?? {
      'totalWords': 20,
      'difficulty': 'Beginner',
      'icon': Icons.topic,
      'color': Theme.of(context).primaryColor,
      'estimatedTime': '12 min',
    };
  }

  Widget _buildQuickActionButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
