import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

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
  
  // New dashboard data
  String userName = "Bạn";
  int streakDays = 0;
  int totalWordsLearned = 0;
  int dailyGoal = 10;
  int todayWordsLearned = 0;
  String lastTopic = "";
  Map<String, dynamic> wordOfTheDay = {};
  
  // Topic groups structure
  List<Map<String, dynamic>> topicGroups = [];
  String currentActiveGroup = "Basic 1";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadTopics();
    _loadReviewedWords();
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "Bạn";
      streakDays = prefs.getInt('streak_days') ?? 7; // Demo value
      totalWordsLearned = prefs.getInt('total_words_learned') ?? 2500; // Demo value
      todayWordsLearned = prefs.getInt('today_words_learned') ?? 5; // Demo value
      lastTopic = prefs.getString('last_topic') ?? "food";
      
      // Initialize topic groups
      _initializeTopicGroups();
      
      // Word of the day (demo data)
      wordOfTheDay = {
        'word': 'Ambition',
        'pronunciation': '/æmˈbɪʃ.ən/',
        'meaning': 'Tham vọng, hoài bão',
        'example': 'She has big ambitions to become a doctor.',
        'exampleVi': 'Cô ấy có tham vọng lớn trở thành bác sĩ.',
      };
    });
  }

  void _initializeTopicGroups() {
    topicGroups = [
      // Basic Groups (1000 words each)
      {
        'id': 'basic_1',
        'name': 'Basic 1',
        'description': 'Từ vựng cơ bản hàng ngày',
        'targetWords': 1000,
        'learnedWords': 850, // Demo data
        'color': Colors.green,
        'icon': Icons.star,
        'topics': ['schools', 'family', 'colors', 'numbers', 'body'],
        'level': 'basic',
        'order': 1,
      },
      {
        'id': 'basic_2',
        'name': 'Basic 2',
        'description': 'Từ vựng sinh hoạt và học tập',
        'targetWords': 1000,
        'learnedWords': 650, // Demo data
        'color': Colors.blue,
        'icon': Icons.school,
        'topics': ['examination', 'classroom', 'food', 'animals'],
        'level': 'basic',
        'order': 2,
      },
      {
        'id': 'basic_3',
        'name': 'Basic 3',
        'description': 'Từ vựng giao tiếp cơ bản',
        'targetWords': 1000,
        'learnedWords': 200, // Demo data
        'color': Colors.orange,
        'icon': Icons.chat,
        'topics': ['feelings', 'weather', 'transportation', 'shapes'],
        'level': 'basic',
        'order': 3,
      },
      
      // Advanced Groups (2000 words each)
      {
        'id': 'advanced_1',
        'name': 'Advanced 1',
        'description': 'Từ vựng nâng cao - Học thuật',
        'targetWords': 2000,
        'learnedWords': 0, // Demo data
        'color': Colors.purple,
        'icon': Icons.psychology,
        'topics': ['universities', 'school subjects', 'extracurricular'],
        'level': 'advanced',
        'order': 1,
      },
      {
        'id': 'advanced_2',
        'name': 'Advanced 2',
        'description': 'Từ vựng nâng cao - Xã hội',
        'targetWords': 2000,
        'learnedWords': 0, // Demo data
        'color': Colors.indigo,
        'icon': Icons.people,
        'topics': ['relationships', 'characteristics', 'appearance'],
        'level': 'advanced',
        'order': 2,
      },
      {
        'id': 'advanced_3',
        'name': 'Advanced 3',
        'description': 'Từ vựng nâng cao - Chuyên ngành',
        'targetWords': 2000,
        'learnedWords': 0, // Demo data
        'color': Colors.teal,
        'icon': Icons.work,
        'topics': ['school stationery', 'age', 'ordinal numbers', 'days of the week'],
        'level': 'advanced',
        'order': 3,
      },
    ];
    
    // Determine current active group based on progress
    _determineActiveGroup();
  }

  void _determineActiveGroup() {
    for (var group in topicGroups) {
      final progress = (group['learnedWords'] as int) / (group['targetWords'] as int);
      if (progress < 1.0) {
        currentActiveGroup = group['name'];
        break;
      }
    }
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
            // 1. Header with greeting and streak
            _buildHeader(),
            
            const SizedBox(height: 24),
            
            // 2. Overall Progress Circle
            _buildOverallProgress(),
            
            const SizedBox(height: 24),
            
            // 3. Daily Goal Tracker
            _buildDailyGoal(),
            
            const SizedBox(height: 24),
            
            // 4. Primary Action Button
            _buildContinueLearningButton(),
            
            const SizedBox(height: 24),
            
            // 5. Recommended Topics
            _buildRecommendedTopics(),
            
            const SizedBox(height: 24),
            
            // 6. Word of the Day
            _buildWordOfTheDay(),
            
            const SizedBox(height: 24),
            
            // 7. Footer Stats
            _buildFooterStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Chào $userName, hôm nay học $dailyGoal từ mới nhé! 🌟',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Streak Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '$streakDays ngày liên tiếp',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Giữ nguyên để nhận badge mới!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress() {
    if (topicGroups.isEmpty) return const SizedBox();
    
    // Find current active group
    final activeGroup = topicGroups.firstWhere(
      (group) => group['name'] == currentActiveGroup,
      orElse: () => topicGroups.first,
    );
    
    final learnedWords = activeGroup['learnedWords'] as int;
    final targetWords = activeGroup['targetWords'] as int;
    final progress = learnedWords / targetWords;
    final remainingWords = targetWords - learnedWords;
    final groupColor = activeGroup['color'] as Color;
    final groupIcon = activeGroup['icon'] as IconData;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Current group header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(groupIcon, color: groupColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeGroup['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      activeGroup['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Progress circle for current group
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(groupColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '$learnedWords/$targetWords từ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            remainingWords > 0 
                ? 'Còn $remainingWords từ để hoàn thành ${activeGroup['name']}!'
                : 'Hoàn thành ${activeGroup['name']}! 🎉',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // All groups overview
          _buildGroupsOverview(),
        ],
      ),
    );
  }

  Widget _buildGroupsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tất cả nhóm từ vựng',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Basic groups
        _buildLevelSection('Basic', 'basic'),
        
        const SizedBox(height: 12),
        
        // Advanced groups
        _buildLevelSection('Advanced', 'advanced'),
      ],
    );
  }

  Widget _buildLevelSection(String levelName, String levelType) {
    final levelGroups = topicGroups.where((group) => group['level'] == levelType).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          levelName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        
        const SizedBox(height: 6),
        
        Row(
          children: levelGroups.map((group) {
            final progress = (group['learnedWords'] as int) / (group['targetWords'] as int);
            final isActive = group['name'] == currentActiveGroup;
            final groupColor = group['color'] as Color;
            
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                child: Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? groupColor : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isActive ? groupColor : Colors.grey[400]!,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      group['name'].toString().split(' ')[1], // Just the number
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? groupColor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDailyGoal() {
    final progress = todayWordsLearned / dailyGoal;
    final remainingWords = dailyGoal - todayWordsLearned;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mục tiêu hôm nay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$todayWordsLearned/$dailyGoal từ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            remainingWords > 0 
                ? 'Học thêm $remainingWords từ để hoàn thành mục tiêu hôm nay!'
                : 'Tuyệt vời! Bạn đã hoàn thành mục tiêu hôm nay! 🎉',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicScreen(topic: lastTopic),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 24),
            const SizedBox(width: 8),
            Text(
              lastTopic.isNotEmpty 
                  ? 'Tiếp tục học chủ đề ${lastTopic.toUpperCase()}'
                  : 'Bắt đầu học',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedTopics() {
    if (isLoadingTopics) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final recommendedTopics = topics.take(4).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Dành cho bạn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendedTopics.length,
            itemBuilder: (context, index) {
              final topic = recommendedTopics[index];
              final reviewedCount = reviewedWordsByTopic[topic.topic]?.length ?? 0;
              return _buildRecommendedTopicCard(topic, reviewedCount);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedTopicCard(Topic topic, int reviewedCount) {
    final topicData = _getTopicData(topic.topic);
    final totalWords = topicData['totalWords'] as int;
    final icon = topicData['icon'] as IconData;
    final color = topicData['color'] as Color;
    final progress = totalWords > 0 ? (reviewedCount / totalWords).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TopicScreen(topic: topic.topic),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                
                const SizedBox(height: 6),
                
                // Topic name
                Text(
                  topic.topic.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 3),
                
                // Progress
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                
                const SizedBox(height: 2),
                
                // Words count
                Text(
                  '$reviewedCount/$totalWords từ',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordOfTheDay() {
    if (wordOfTheDay.isEmpty) return const SizedBox();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple[50]!,
            Colors.blue[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.star, color: Colors.purple[600], size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Từ vựng trong ngày',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Word
          Text(
            wordOfTheDay['word'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Pronunciation
          Text(
            wordOfTheDay['pronunciation'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Meaning
          Text(
            wordOfTheDay['meaning'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Example
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wordOfTheDay['example'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  wordOfTheDay['exampleVi'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Add to quiz button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã thêm vào danh sách ôn tập!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.add_task, size: 16),
              label: const Text('Thêm vào ôn tập'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple[600],
                side: BorderSide(color: Colors.purple[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStats() {
    // Calculate totals from topic groups
    final totalTargetWords = topicGroups.fold<int>(0, (sum, group) => sum + (group['targetWords'] as int));
    final totalLearnedWords = topicGroups.fold<int>(0, (sum, group) => sum + (group['learnedWords'] as int));
    final remainingWords = totalTargetWords - totalLearnedWords;
    final currentLevel = (totalLearnedWords / 1000).floor() + 1;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Quick stats
          Text(
            'Tổng: ${totalLearnedWords.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} từ | Level: $currentLevel | Hôm qua: ${todayWordsLearned - 2} từ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Subtle CTA
          GestureDetector(
            onTap: () {
              if (widget.onTabChange != null) {
                widget.onTabChange!(1); // Navigate to Topics tab
              }
            },
            child: Text(
              'Khám phá ${remainingWords.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} từ còn lại →',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTopicData(String topicName) {
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
        'difficulty': 'Beginner',
        'icon': Icons.sports_soccer,
        'color': Colors.green,
        'estimatedTime': '10 min',
      },
      'family': {
        'totalWords': 22,
        'difficulty': 'Beginner',
        'icon': Icons.family_restroom,
        'color': Colors.pink,
        'estimatedTime': '13 min',
      },
      'food': {
        'totalWords': 30,
        'difficulty': 'Intermediate',
        'icon': Icons.restaurant,
        'color': Colors.red,
        'estimatedTime': '18 min',
      },
      'animals': {
        'totalWords': 28,
        'difficulty': 'Beginner',
        'icon': Icons.pets,
        'color': Colors.brown,
        'estimatedTime': '16 min',
      },
      'colors': {
        'totalWords': 15,
        'difficulty': 'Beginner',
        'icon': Icons.palette,
        'color': Colors.purple,
        'estimatedTime': '8 min',
      },
      'numbers': {
        'totalWords': 20,
        'difficulty': 'Beginner',
        'icon': Icons.numbers,
        'color': Colors.indigo,
        'estimatedTime': '12 min',
      },
      'weather': {
        'totalWords': 16,
        'difficulty': 'Intermediate',
        'icon': Icons.wb_sunny,
        'color': Colors.amber,
        'estimatedTime': '9 min',
      },
      'transportation': {
        'totalWords': 24,
        'difficulty': 'Intermediate',
        'icon': Icons.directions_car,
        'color': Colors.cyan,
        'estimatedTime': '14 min',
      },
    };

    return topicConfigs[topicName] ?? {
      'totalWords': 20,
      'difficulty': 'Beginner',
      'icon': Icons.book,
      'color': Colors.grey,
      'estimatedTime': '12 min',
    };
  }
}