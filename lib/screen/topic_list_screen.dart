import 'package:flutter/material.dart';
import 'package:bvo/model/topic.dart';
import 'package:bvo/repository/topic_repository.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/repository/topic_configs_repository.dart';
import 'package:bvo/screen/topic_screen.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({Key? key}) : super(key: key);

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  List<Topic> topics = [];
  Map<String, int> reviewedWordsByTopic = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final loadedTopics = await TopicRepository().getTopics();
      final reviewedWords = await WordRepository().getReviewedWordsGroupedByTopic();
      
      setState(() {
        topics = loadedTopics;
        reviewedWordsByTopic = reviewedWords.map((key, value) => MapEntry(key, value.length));
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading topics: $e')),
        );
      }
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
                  'All Topics',
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
              pinned: true,
            ),
            isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
          : topics.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                  child: Text(
                    'No topics available yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                            ),
                    ),
                  ),
                )
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              // Create rows of 2 cards each
                              if (index * 2 >= topics.length) return null;
                              
                              final leftTopic = topics[index * 2];
                              final leftReviewedCount = reviewedWordsByTopic[leftTopic.topic] ?? 0;
                              
                              Widget? rightCard;
                              if (index * 2 + 1 < topics.length) {
                                final rightTopic = topics[index * 2 + 1];
                                final rightReviewedCount = reviewedWordsByTopic[rightTopic.topic] ?? 0;
                                rightCard = Expanded(
                                  child: _buildTopicCard(rightTopic, rightReviewedCount),
                                );
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTopicCard(leftTopic, leftReviewedCount),
                                    ),
                                    if (rightCard != null) ...[
                                      const SizedBox(width: 12),
                                      rightCard,
                                    ] else
                                      const Expanded(child: SizedBox()),
                                  ],
                                ),
                              );
                            },
                            childCount: (topics.length + 1) ~/ 2, // Ceiling division
                          ),
                        ),
                      ),
          ],
        ),
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
    return TopicConfigsRepository.getTopicData(topicName);
  }
}