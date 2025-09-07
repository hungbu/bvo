import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import 'package:bvo/model/word.dart';
import 'package:bvo/model/topic.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/repository/topic_repository.dart';
import 'package:bvo/repository/topic_configs_repository.dart';
import 'package:bvo/repository/dictionary.dart';
import 'package:bvo/screen/topic_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    
    // Load basic user data
    userName = prefs.getString('user_name') ?? "Bạn";
    dailyGoal = prefs.getInt('daily_goal') ?? 10;
    lastTopic = prefs.getString('last_topic') ?? "schools";
    
    // Calculate real statistics
    await _calculateRealStatistics();
    
    // Initialize topic groups with real data
    await _initializeTopicGroupsWithRealData();
    
    // Load word of the day
    await _loadWordOfTheDay();
    
    setState(() {});
  }

  Future<void> _calculateRealStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Calculate total words learned from reviewed words
      final reviewedWords = await WordRepository().getReviewedWordsGroupedByTopic();
      totalWordsLearned = reviewedWords.values.fold(0, (sum, words) => sum + words.length);
      
      // Calculate streak days
      streakDays = await _calculateStreakDays();
      
      // Calculate today's words learned
      todayWordsLearned = await _calculateTodayWordsLearned();
      
      // Save calculated values
      await prefs.setInt('total_words_learned', totalWordsLearned);
      await prefs.setInt('streak_days', streakDays);
      await prefs.setInt('today_words_learned', todayWordsLearned);
      
    } catch (e) {
      print('Error calculating statistics: $e');
      // Fallback to saved values or defaults
      final prefs = await SharedPreferences.getInstance();
      totalWordsLearned = prefs.getInt('total_words_learned') ?? 0;
      streakDays = prefs.getInt('streak_days') ?? 0;
      todayWordsLearned = prefs.getInt('today_words_learned') ?? 0;
    }
  }

  Future<int> _calculateStreakDays() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    // Check if user learned today
    final learnedToday = prefs.getBool('learned_$todayKey') ?? false;
    
    if (!learnedToday) {
      // If not learned today, check yesterday to maintain streak
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      final learnedYesterday = prefs.getBool('learned_$yesterdayKey') ?? false;
      
      if (!learnedYesterday) {
        return 0; // Streak broken
      }
    }
    
    // Count consecutive days
    int streak = 0;
    DateTime checkDate = today;
    
    for (int i = 0; i < 365; i++) { // Check up to a year
      final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      final learned = prefs.getBool('learned_$dateKey') ?? false;
      
      if (learned) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  Future<int> _calculateTodayWordsLearned() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    return prefs.getInt('words_learned_$todayKey') ?? 0;
  }

  Future<void> _loadWordOfTheDay() async {
    try {
      // Check if dictionary is not empty
      if (dictionary.isEmpty) {
        throw Exception('Dictionary is empty');
      }
      
      // Get a random word from dictionary for word of the day
      final random = math.Random();
      final wordIndex = random.nextInt(dictionary.length);
      final selectedWord = dictionary[wordIndex];
      
      wordOfTheDay = {
        'word': selectedWord.en,
        'pronunciation': selectedWord.pronunciation,
        'meaning': selectedWord.vi,
        'example': selectedWord.sentence,
        'exampleVi': selectedWord.sentenceVi,
      };
    } catch (e) {
      print('Error loading word of the day: $e');
      // Fallback word
      wordOfTheDay = {
        'word': 'Learning',
        'pronunciation': '/ˈlɜːrnɪŋ/',
        'meaning': 'Học tập, việc học',
        'example': 'Learning English is fun and rewarding.',
        'exampleVi': 'Học tiếng Anh thật thú vị và bổ ích.',
      };
    }
  }

  Future<void> _initializeTopicGroupsWithRealData() async {
    try {
      // Get all available topics
      final allTopics = await TopicRepository().getTopics();
      final reviewedWords = await WordRepository().getReviewedWordsGroupedByTopic();
      
      // Define topic groups with real topics
      final basicTopics = allTopics.where((topic) {
        final config = TopicConfigsRepository.getTopicConfig(topic.topic);
        return config.difficulty == 'Beginner';
      }).take(30).toList(); // First 30 beginner topics
      
      final intermediateTopics = allTopics.where((topic) {
        final config = TopicConfigsRepository.getTopicConfig(topic.topic);
        return config.difficulty == 'Intermediate';
      }).take(30).toList(); // First 30 intermediate topics
      
      final advancedTopics = allTopics.where((topic) {
        final config = TopicConfigsRepository.getTopicConfig(topic.topic);
        return config.difficulty == 'Advanced';
      }).take(30).toList(); // First 30 advanced topics
      
      // Calculate learned words for each group
      int calculateLearnedWords(List<Topic> topics) {
        return topics.fold(0, (sum, topic) {
          final reviewed = reviewedWords[topic.topic] ?? [];
          return sum + reviewed.length;
        });
      }
      
      int calculateTargetWords(List<Topic> topics) {
        return topics.fold(0, (sum, topic) {
          final config = TopicConfigsRepository.getTopicConfig(topic.topic);
          return sum + config.totalWords;
        });
      }
      
      // Split basic topics into 3 groups (with safety checks)
      final basicGroup1 = basicTopics.take(math.min(10, basicTopics.length)).toList();
      final basicGroup2 = basicTopics.skip(math.min(10, basicTopics.length)).take(math.min(10, math.max(0, basicTopics.length - 10))).toList();
      final basicGroup3 = basicTopics.skip(math.min(20, basicTopics.length)).take(math.min(10, math.max(0, basicTopics.length - 20))).toList();
      
      // Split intermediate topics into 2 groups (with safety checks)
      final intermediateGroup1 = intermediateTopics.take(math.min(15, intermediateTopics.length)).toList();
      final intermediateGroup2 = intermediateTopics.skip(math.min(15, intermediateTopics.length)).take(math.min(15, math.max(0, intermediateTopics.length - 15))).toList();
      
      topicGroups = [
        // Basic Groups
        {
          'id': 'basic_1',
          'name': 'Basic 1',
          'description': 'Từ vựng cơ bản hàng ngày',
          'targetWords': calculateTargetWords(basicGroup1),
          'learnedWords': calculateLearnedWords(basicGroup1),
          'color': Colors.green,
          'icon': Icons.star,
          'topics': basicGroup1.map((t) => t.topic).toList(),
          'level': 'basic',
          'order': 1,
        },
        {
          'id': 'basic_2',
          'name': 'Basic 2',
          'description': 'Từ vựng sinh hoạt và học tập',
          'targetWords': calculateTargetWords(basicGroup2),
          'learnedWords': calculateLearnedWords(basicGroup2),
          'color': Colors.blue,
          'icon': Icons.school,
          'topics': basicGroup2.map((t) => t.topic).toList(),
          'level': 'basic',
          'order': 2,
        },
        {
          'id': 'basic_3',
          'name': 'Basic 3',
          'description': 'Từ vựng giao tiếp cơ bản',
          'targetWords': calculateTargetWords(basicGroup3),
          'learnedWords': calculateLearnedWords(basicGroup3),
          'color': Colors.orange,
          'icon': Icons.chat,
          'topics': basicGroup3.map((t) => t.topic).toList(),
          'level': 'basic',
          'order': 3,
        },
        
        // Intermediate Groups
        {
          'id': 'intermediate_1',
          'name': 'Intermediate 1',
          'description': 'Từ vựng trung cấp - Giao tiếp',
          'targetWords': calculateTargetWords(intermediateGroup1),
          'learnedWords': calculateLearnedWords(intermediateGroup1),
          'color': Colors.purple,
          'icon': Icons.psychology,
          'topics': intermediateGroup1.map((t) => t.topic).toList(),
          'level': 'intermediate',
          'order': 1,
        },
        {
          'id': 'intermediate_2',
          'name': 'Intermediate 2',
          'description': 'Từ vựng trung cấp - Xã hội',
          'targetWords': calculateTargetWords(intermediateGroup2),
          'learnedWords': calculateLearnedWords(intermediateGroup2),
          'color': Colors.indigo,
          'icon': Icons.people,
          'topics': intermediateGroup2.map((t) => t.topic).toList(),
          'level': 'intermediate',
          'order': 2,
        },
        
        // Advanced Group
        {
          'id': 'advanced_1',
          'name': 'Advanced',
          'description': 'Từ vựng nâng cao - Chuyên ngành',
          'targetWords': calculateTargetWords(advancedTopics),
          'learnedWords': calculateLearnedWords(advancedTopics),
          'color': Colors.teal,
          'icon': Icons.work,
          'topics': advancedTopics.map((t) => t.topic).toList(),
          'level': 'advanced',
          'order': 1,
        },
      ];
      
      // Determine current active group based on progress
      _determineActiveGroup();
      
    } catch (e) {
      print('Error initializing topic groups: $e');
      // Fallback to basic structure
      _initializeBasicTopicGroups();
    }
  }

  void _initializeBasicTopicGroups() {
    // Fallback basic structure if real data loading fails
    topicGroups = [
      {
        'id': 'basic_1',
        'name': 'Basic 1',
        'description': 'Từ vựng cơ bản hàng ngày',
        'targetWords': 500,
        'learnedWords': totalWordsLearned.clamp(0, 500),
        'color': Colors.green,
        'icon': Icons.star,
        'topics': ['schools', 'family', 'colors', 'numbers'],
        'level': 'basic',
        'order': 1,
      },
      {
        'id': 'basic_2',
        'name': 'Basic 2',
        'description': 'Từ vựng sinh hoạt và học tập',
        'targetWords': 500,
        'learnedWords': (totalWordsLearned - 500).clamp(0, 500),
        'color': Colors.blue,
        'icon': Icons.school,
        'topics': ['food', 'animals', 'weather', 'transportation'],
        'level': 'basic',
        'order': 2,
      },
    ];
    
    _determineActiveGroup();
  }

  void _determineActiveGroup() {
    if (topicGroups.isEmpty) {
      currentActiveGroup = "Basic 1";
      return;
    }
    
    for (var group in topicGroups) {
      final learnedWords = group['learnedWords'] as int;
      final targetWords = group['targetWords'] as int;
      
      // Avoid division by zero
      if (targetWords == 0) {
        continue;
      }
      
      final progress = learnedWords / targetWords;
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
    final progress = targetWords > 0 ? learnedWords / targetWords : 0.0;
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
        
        // Intermediate groups
        _buildLevelSection('Intermediate', 'intermediate'),
        
        const SizedBox(height: 12),
        
        // Advanced groups
        _buildLevelSection('Advanced', 'advanced'),
      ],
    );
  }

  Widget _buildLevelSection(String levelName, String levelType) {
    final levelGroups = topicGroups.where((group) => group['level'] == levelType).toList();
    
    // If no groups found, return empty container
    if (levelGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    
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
            final learnedWords = group['learnedWords'] as int;
            final targetWords = group['targetWords'] as int;
            final progress = targetWords > 0 ? learnedWords / targetWords : 0.0;
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
                      _getGroupDisplayName(group['name']?.toString() ?? ''),
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
              builder: (context) => TopicDetailScreen(topic: lastTopic),
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
                            builder: (context) => TopicDetailScreen(topic: topic.topic),
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
              onPressed: () async {
                await _addWordOfTheDayToReview();
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
    return TopicConfigsRepository.getTopicData(topicName);
  }

  String _getGroupDisplayName(String groupName) {
    if (groupName.isEmpty) return '';
    
    // Extract the number part from group names like "Basic 1", "Intermediate 2", etc.
    final parts = groupName.split(' ');
    if (parts.length > 1) {
      return parts.last; // Return the last part (usually the number)
    }
    return groupName; // Return the whole name if no space found
  }

  // Utility methods for progress tracking
  Future<void> _addWordOfTheDayToReview() async {
    try {
      if (wordOfTheDay.isEmpty) return;
      
      // Find the word in dictionary and mark as reviewed
      final wordToAdd = dictionary.firstWhere(
        (word) => word.en.toLowerCase() == wordOfTheDay['word'].toString().toLowerCase(),
        orElse: () => dictionary.first, // Fallback
      );
      
      // Mark word as reviewed by updating its review count
      final updatedWord = Word(
        en: wordToAdd.en,
        vi: wordToAdd.vi,
        pronunciation: wordToAdd.pronunciation,
        sentence: wordToAdd.sentence,
        sentenceVi: wordToAdd.sentenceVi,
        topic: wordToAdd.topic,
        level: wordToAdd.level,
        type: wordToAdd.type,
        difficulty: wordToAdd.difficulty,
        nextReview: wordToAdd.nextReview,
        isKidFriendly: wordToAdd.isKidFriendly,
        mnemonicTip: wordToAdd.mnemonicTip,
        tags: wordToAdd.tags,
        reviewCount: wordToAdd.reviewCount + 1, // Increment review count
      );
      
      // Get existing words for the topic and update the list
      final existingWords = await WordRepository().getWordsOfTopic(wordToAdd.topic);
      final updatedWords = existingWords.map((word) {
        if (word.en == wordToAdd.en) {
          return updatedWord;
        }
        return word;
      }).toList();
      
      // If word doesn't exist in topic, add it
      if (!existingWords.any((word) => word.en == wordToAdd.en)) {
        updatedWords.add(updatedWord);
      }
      
      // Save updated words
      await WordRepository().saveWords(wordToAdd.topic, updatedWords);
      await _updateDailyProgress(1);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm vào danh sách ôn tập!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding word of the day to review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi thêm từ vào ôn tập'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateDailyProgress(int wordsLearned) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    // Update today's word count
    final currentCount = prefs.getInt('words_learned_$todayKey') ?? 0;
    final newCount = currentCount + wordsLearned;
    await prefs.setInt('words_learned_$todayKey', newCount);
    
    // Mark today as learned
    await prefs.setBool('learned_$todayKey', true);
    
    // Update total words learned
    final totalWords = prefs.getInt('total_words_learned') ?? 0;
    await prefs.setInt('total_words_learned', totalWords + wordsLearned);
    
    // Refresh dashboard data
    await _loadDashboardData();
  }

  // Method to refresh dashboard when returning from other screens
  Future<void> refreshDashboard() async {
    await _loadDashboardData();
    await _loadReviewedWords();
  }
}
