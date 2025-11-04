import 'package:flutter/material.dart';
import 'package:bvo/model/topic.dart';
import 'package:bvo/service/topic_service.dart';
import 'package:bvo/screen/topic_detail_screen.dart';
import 'package:bvo/screen/topic_level_screen.dart';
import 'package:bvo/main.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({Key? key}) : super(key: key);

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> with RouteAware {
  List<Topic> topics = [];
  bool isLoading = true;
  final TopicService _topicService = TopicService();

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
      final loadedTopics = await _topicService.getTopicsForDisplay();
      
      setState(() {
        topics = loadedTopics;
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
    await _loadTopics(); // Simply reload all topics with fresh data
  }

  /* Deprecated: Helper methods no longer needed as topic model has built-in icon and color
  // Helper method để map icon cho từng topic (deprecated - now using topic.icon)
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

  // Helper method để lấy màu theo level (deprecated - now using topic.color)
  Color _getTopicColor(Topic topic) {
    return topic.color; // Use built-in color from topic model
  }
  */

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TopicLevelScreen(),
            ),
          ).then((_) {
            // Refresh data when returning
            _refreshTopicsData();
          });
        },
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.layers, color: Colors.white),
        label: const Text(
          'Học theo Level',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTopicsByLevel() {
    // Nhóm topics theo level
    final basicTopics = topics.where((topic) => topic.level == 'BASIC').toList();
    final intermediateTopics = topics.where((topic) => topic.level == 'INTERMEDIATE').toList();
    final advancedTopics = topics.where((topic) => topic.level == 'ADVANCED').toList();

    return CustomScrollView(
      slivers: [
        if (basicTopics.isNotEmpty) ..._buildLevelSection('Cơ Bản', Colors.green, basicTopics),
        if (intermediateTopics.isNotEmpty) ..._buildLevelSection('Trung Cấp', Colors.orange, intermediateTopics),
        if (advancedTopics.isNotEmpty) ..._buildLevelSection('Nâng Cao', Colors.purple, advancedTopics),
      ],
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

  List<Widget> _buildLevelSection(String levelName, Color color, List<Topic> levelTopics) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _buildLevelHeader(levelName, color, levelTopics.length),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.30,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final topic = levelTopics[index];
              return _buildTopicCard(topic);
            },
            childCount: levelTopics.length,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _buildTopicCard(Topic topic) {
    // Use data from new topic model
    final totalWords = topic.totalWords;
    final learnedWords = topic.learnedWords;
    final icon = topic.icon; // Use built-in icon
    final color = topic.color; // Use built-in color
    final estimatedTime = topic.estimatedTime;
    
    final progress = topic.progressPercentage;
    final progressPercentage = (progress * 100).round();
    final difficulty = topic.level; // Use topic level as difficulty
    final isCompleted = progress >= 1.0;
    final isStarted = topic.isStarted || topic.lastStudied != null;
    
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
                              builder: (context) => TopicDetailScreen(topic: topic.id),
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
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withOpacity(0.6)
                  : (isStarted ? Colors.orange.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
              width: 1,
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
                  _buildStatusChip(isCompleted: isCompleted, isStarted: isStarted),
                ],
              ),
              
              const SizedBox(height: 6),
              
              // Topic title
              Text(
                topic.name.toUpperCase(),
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
                        child:               Text(
                '$learnedWords/$totalWords từ đã thuộc',
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
    int stars = difficulty == 'BASIC' ? 1 : 
                difficulty == 'INTERMEDIATE' ? 2 : 3;
    
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

  Widget _buildStatusChip({required bool isCompleted, required bool isStarted}) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              'Đã xong',
              style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    if (isStarted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
            SizedBox(width: 4),
            Text(
              'Đang học',
              style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.hourglass_empty, color: Colors.grey, size: 14),
          SizedBox(width: 4),
          Text(
            'Chưa học',
            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

}
