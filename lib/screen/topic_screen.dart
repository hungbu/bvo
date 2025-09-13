import 'package:flutter/material.dart';
import 'package:dongsonword/model/topic.dart';
import 'package:dongsonword/repository/topic_repository.dart';
import 'package:dongsonword/repository/topic_configs_repository.dart';
import 'package:dongsonword/repository/user_progress_repository.dart';
import 'package:dongsonword/screen/topic_detail_screen.dart';
import 'package:dongsonword/main.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({Key? key}) : super(key: key);

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> with RouteAware {
  List<Topic> topics = [];
  Map<String, int> reviewedWordsByTopic = {};
  Map<String, Map<String, dynamic>> topicsProgress = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
    print('🔄 TopicScreen: didPopNext - refreshing data');
    _refreshTopicsData();
  }


  Future<void> _loadTopics() async {
    try {
      final loadedTopics = await TopicRepository().getTopics();
      final progressRepo = UserProgressRepository();
      final allProgress = await progressRepo.getAllTopicsProgress();
      
      // Calculate reviewed words from progress data
      final reviewedWords = <String, int>{};
      for (final topic in loadedTopics) {
        final progress = allProgress[topic.topic];
        if (progress != null) {
          reviewedWords[topic.topic] = progress['learnedWords'] ?? 0;
        } else {
          reviewedWords[topic.topic] = 0;
        }
      }
      
      setState(() {
        topics = loadedTopics;
        reviewedWordsByTopic = reviewedWords;
        topicsProgress = allProgress;
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

  /// Refresh topics data after returning from TopicDetailScreen
  Future<void> _refreshTopicsData() async {
    print('🔄 Refreshing topics data...');
    
    try {
      final progressRepo = UserProgressRepository();
      final allProgress = await progressRepo.getAllTopicsProgress();
      
      // Calculate reviewed words from progress data
      final reviewedWords = <String, int>{};
      for (final topic in topics) {
        final progress = allProgress[topic.topic];
        if (progress != null) {
          reviewedWords[topic.topic] = progress['learnedWords'] ?? 0;
        } else {
          reviewedWords[topic.topic] = 0;
        }
      }
      
      if (mounted) {
        setState(() {
          reviewedWordsByTopic = reviewedWords;
          topicsProgress = allProgress;
        });
        
        print('✅ Topics data refreshed - ${reviewedWords.length} topics updated');
      }
    } catch (e) {
      print('❌ Error refreshing topics data: $e');
    }
  }

  // Helper method để map icon cho từng topic
  IconData _getTopicIcon(String topicName) {
    // Map topic names to appropriate icons
    final iconMap = {
      // Family & People
      'family': Icons.family_restroom,
      'people': Icons.people,
      'friends': Icons.group,
      'relationships': Icons.favorite,
      
      // Education
      'school': Icons.school,
      'education': Icons.menu_book,
      'learning': Icons.psychology,
      'books': Icons.book,
      'study': Icons.school,
      
      // Work & Business
      'work': Icons.work,
      'business': Icons.business,
      'office': Icons.business_center,
      'job': Icons.work_outline,
      'career': Icons.trending_up,
      
      // Food & Drink
      'food': Icons.restaurant,
      'cooking': Icons.kitchen,
      'restaurant': Icons.restaurant_menu,
      'drinks': Icons.local_drink,
      'fruits': Icons.apple,
      
      // Travel & Transport
      'travel': Icons.flight,
      'transport': Icons.directions_bus,
      'car': Icons.directions_car,
      'airplane': Icons.airplanemode_active,
      'hotel': Icons.hotel,
      
      // Health & Body
      'health': Icons.health_and_safety,
      'body': Icons.accessibility,
      'medical': Icons.medical_services,
      'exercise': Icons.fitness_center,
      'sports': Icons.sports,
      
      // Home & Living
      'home': Icons.home,
      'house': Icons.house,
      'furniture': Icons.chair,
      'kitchen': Icons.kitchen,
      'bedroom': Icons.bed,
      
      // Nature & Weather
      'weather': Icons.wb_sunny,
      'nature': Icons.nature,
      'animals': Icons.pets,
      'plants': Icons.local_florist,
      'environment': Icons.eco,
      
      // Technology
      'technology': Icons.computer,
      'internet': Icons.wifi,
      'phone': Icons.phone,
      'computer': Icons.laptop,
      
      // Entertainment
      'music': Icons.music_note,
      'movies': Icons.movie,
      'games': Icons.games,
      'art': Icons.palette,
      'photography': Icons.camera_alt,
      
      // Shopping & Money
      'shopping': Icons.shopping_cart,
      'money': Icons.attach_money,
      'clothes': Icons.checkroom,
      'fashion': Icons.style,
      
      // Basic concepts
      'colors': Icons.color_lens,
      'numbers': Icons.numbers,
      'time': Icons.access_time,
      'directions': Icons.directions,
      'shapes': Icons.category,
    };
    
    // Try exact match first
    if (iconMap.containsKey(topicName.toLowerCase())) {
      return iconMap[topicName.toLowerCase()]!;
    }
    
    // Try partial matches
    for (final entry in iconMap.entries) {
      if (topicName.toLowerCase().contains(entry.key) || 
          entry.key.contains(topicName.toLowerCase())) {
        return entry.value;
      }
    }
    
    // Default icon based on topic level
    return Icons.topic;
  }

  // Helper method để lấy màu theo level
  Color _getTopicColor(Topic topic) {
    switch (topic.level) {
      case TopicLevel.BASIC:
        return Colors.green;
      case TopicLevel.INTERMEDIATE:
        return Colors.orange;
      case TopicLevel.ADVANCED:
        return Colors.purple;
      default:
        return Colors.blue;
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : topics.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có chủ đề nào.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : _buildTopicsByLevel(),
      ),
    );
  }

  Widget _buildTopicsByLevel() {
    // Nhóm topics theo level
    final basicTopics = topics.where((topic) => topic.level == TopicLevel.BASIC).toList();
    final intermediateTopics = topics.where((topic) => topic.level == TopicLevel.INTERMEDIATE).toList();
    final advancedTopics = topics.where((topic) => topic.level == TopicLevel.ADVANCED).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Level Section
          if (basicTopics.isNotEmpty) ...[
            _buildLevelHeader('Cơ Bản', Colors.green, basicTopics.length),
            const SizedBox(height: 12),
            _buildTopicGrid(basicTopics),
            const SizedBox(height: 24),
          ],
          
          // Intermediate Level Section
          if (intermediateTopics.isNotEmpty) ...[
            _buildLevelHeader('Trung Cấp', Colors.orange, intermediateTopics.length),
            const SizedBox(height: 12),
            _buildTopicGrid(intermediateTopics),
            const SizedBox(height: 24),
          ],
          
          // Advanced Level Section
          if (advancedTopics.isNotEmpty) ...[
            _buildLevelHeader('Nâng Cao', Colors.purple, advancedTopics.length),
            const SizedBox(height: 12),
            _buildTopicGrid(advancedTopics),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelHeader(String levelName, Color color, int topicCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getLevelIcon(levelName),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '$topicCount chủ đề',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLevelIcon(String levelName) {
    switch (levelName.toLowerCase()) {
      case 'basic':
        return Icons.star;
      case 'intermediate':
        return Icons.trending_up;
      case 'advanced':
        return Icons.emoji_events;
      default:
        return Icons.book;
    }
  }

  Widget _buildTopicGrid(List<Topic> levelTopics) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: levelTopics.map((topic) {
        final reviewedCount = reviewedWordsByTopic[topic.topic] ?? 0;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 44) / 2, // 2 columns với padding
          child: _buildTopicCard(topic, reviewedCount),
        );
      }).toList(),
    );
  }

  Widget _buildTopicCard(Topic topic, int reviewedCount) {
    // Get topic-specific data từ vocabulary data
    final totalWords = topic.totalWords;
    final difficulty = topic.level.toString().split('.').last;
    final icon = _getTopicIcon(topic.topic); // Sử dụng helper method mới
    final color = _getTopicColor(topic); // Sử dụng helper method mới
    final estimatedTime = '${(totalWords / 10).ceil()} phút'; // Ước tính thời gian
    
    // Calculate progress
    final progress = totalWords > 0 ? (reviewedCount / totalWords).clamp(0.0, 1.0) : 0.0;
    final progressPercentage = (progress * 100).round();
    
    // Determine completion status
    final isCompleted = progress >= 1.0;
    final isStarted = reviewedCount > 0;
    
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopicDetailScreen(topic: topic.topic),
                            ),
                          );
                          
                          // Refresh data when returning from TopicDetailScreen
                          if (result != null || mounted) {
                            await _refreshTopicsData();
                          }
                        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.08),
                color.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 16,
                    ),
                  ),
                  if (isCompleted)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
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
