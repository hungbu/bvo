import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/model/topic.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/service/topic_service.dart';
import 'package:bvo/repository/user_progress_repository.dart';
import 'package:bvo/service/notification_manager.dart';
import 'package:bvo/screen/topic_detail_screen.dart';
import 'package:bvo/service/difficult_words_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WordRepository _wordRepository = WordRepository();
  final TopicService _topicService = TopicService();
  final DifficultWordsService _difficultWordsService = DifficultWordsService();
  Map<String, List<Word>> reviewedWordsByTopic = {};
  List<Topic> topics = [];
  bool isLoadingTopics = true;
  
  // New dashboard data
  String userName = "Bạn";
  int streakDays = 0;
  int longestStreak = 0;
  int totalWordsLearned = 0;
  int dailyGoal = 10;
  int todayWordsLearned = 0;
  String lastTopic = "";
  String lastTopicName = "";
  Map<String, dynamic> wordOfTheDay = {};
  bool isDashboardLoading = true;
  
  // Topic groups structure
  List<Map<String, dynamic>> topicGroups = [];
  String currentActiveGroup = "Basic";

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
    
    // Load last topic from UserProgressRepository
    final progressRepo = UserProgressRepository();
    lastTopic = await progressRepo.getLastTopic() ?? (await _getFirstTopicId()) ?? '';
    print('📍 Loaded last_topic from prefs (fallback first topic if empty): $lastTopic');
    await _resolveLastTopicName();
    
    // Calculate real statistics
    await _calculateRealStatistics();
    
    // Topic groups will be initialized in _loadTopics
    
    // Load word of the day
    await _loadWordOfTheDay();
    
    setState(() {
      isDashboardLoading = false;
    });
  }

  Future<String?> _getFirstTopicId() async {
    try {
      final all = await _topicService.getTopicsForDisplay();
      if (all.isNotEmpty) return all.first.id;
    } catch (_) {}
    return null;
  }

  Future<void> _resolveLastTopicName() async {
    try {
      if (lastTopic.isEmpty) {
        lastTopicName = '';
        return;
      }
      final topic = await _topicService.getTopicDetail(lastTopic);
      setState(() {
        lastTopicName = topic?.name ?? lastTopic;
      });
    } catch (_) {
      setState(() {
        lastTopicName = lastTopic;
      });
    }
  }

  Future<void> _calculateRealStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Calculate total words learned from user progress
      final progressRepo = UserProgressRepository();
      final userStats = await progressRepo.getUserStatistics();
      totalWordsLearned = userStats['totalLearnedWords'] ?? 0;
      
      // Use streak data from UserProgressRepository (consistent with ProfileScreen)
      streakDays = userStats['streakDays'] ?? 0;
      longestStreak = userStats['longestStreak'] ?? 0;
      
      // Calculate today's words learned
      todayWordsLearned = await _calculateTodayWordsLearned();
      
      // Save calculated values
      await prefs.setInt('total_words_learned', totalWordsLearned);
      await prefs.setInt('streak_days', streakDays);
      await prefs.setInt('longest_streak', longestStreak);
      await prefs.setInt('today_words_learned', todayWordsLearned);
      
      // Debug info
      print('📊 HomePage Stats:');
      print('  - Current Streak: $streakDays days');
      print('  - Longest Streak: $longestStreak days');
      print('  - Total Words Learned: $totalWordsLearned');
      print('  - Today Words Learned: $todayWordsLearned');
      
    } catch (e) {
      print('Error calculating statistics: $e');
      // Fallback to saved values or defaults
      final prefs = await SharedPreferences.getInstance();
      totalWordsLearned = prefs.getInt('total_words_learned') ?? 0;
      streakDays = prefs.getInt('streak_days') ?? 0;
      longestStreak = prefs.getInt('longest_streak') ?? 0;
      todayWordsLearned = prefs.getInt('today_words_learned') ?? 0;
    }
  }

  // Old streak calculation method - now using UserProgressRepository for consistency
  // Removed to avoid confusion and ensure single source of truth

  Future<int> _calculateTodayWordsLearned() async {
    final progressRepo = UserProgressRepository();
    return await progressRepo.getTodayWordsLearned();
  }

  Future<void> _loadWordOfTheDay() async {
    try {
      // 0) Prefer words that are due for review today (prioritize current topic)
      Word? selectedWord;
      String? selectedTopic;
      String? selectedSource;
      final progressRepo = UserProgressRepository();
      final dueWordProgress = await progressRepo.getWordsForReview();
      if (dueWordProgress.isNotEmpty) {
        // Sort by nextReview ascending (most overdue first)
        dueWordProgress.sort((a, b) {
          final aNext = a['nextReview'] != null ? DateTime.parse(a['nextReview']) : DateTime.now();
          final bNext = b['nextReview'] != null ? DateTime.parse(b['nextReview']) : DateTime.now();
          return aNext.compareTo(bNext);
        });
        // Prefer lastTopic if available
        Map<String, dynamic>? candidate = dueWordProgress.firstWhere(
          (wp) => lastTopic.isNotEmpty && (wp['topic'] == lastTopic),
          orElse: () => dueWordProgress.first,
        );
        final topic = (candidate['topic'] ?? '').toString();
        final wordEn = (candidate['word'] ?? '').toString();
        if (topic.isNotEmpty && wordEn.isNotEmpty) {
          final topicWords = await _wordRepository.getWordsByTopic(topic);
          for (final w in topicWords) {
            if (w.en.toLowerCase() == wordEn.toLowerCase()) {
              selectedWord = w;
              selectedTopic = topic;
              selectedSource = 'review';
              break;
            }
          }
        }
      }
      // 1) If none, try a difficult word from the current/last topic
      if (selectedWord == null && lastTopic.isNotEmpty) {
        final difficultInTopic = await _difficultWordsService.getDifficultWordsByTopic(lastTopic);
        if (difficultInTopic.isNotEmpty) {
          // Pick the most difficult (highest error rate)
          final hardest = difficultInTopic.first;
          final topicWords = await _wordRepository.getWordsByTopic(hardest.topic);
          Word? match;
          for (final w in topicWords) {
            if (w.en.toLowerCase() == hardest.word.toLowerCase()) {
              match = w;
              break;
            }
          }
          if (match != null || topicWords.isNotEmpty) {
            selectedWord = match ?? topicWords.first;
            selectedTopic = hardest.topic;
            selectedSource = 'difficult';
          }
        }
      }

      // 2) If none, try any difficult word across topics
      selectedWord ??= await () async {
        final allDifficult = await _difficultWordsService.getAllDifficultWords();
        if (allDifficult.isNotEmpty) {
          final hardest = allDifficult.first;
          final topicWords = await _wordRepository.getWordsByTopic(hardest.topic);
          Word? match;
          for (final w in topicWords) {
            if (w.en.toLowerCase() == hardest.word.toLowerCase()) {
              match = w;
              break;
            }
          }
          if (match != null || topicWords.isNotEmpty) {
            selectedTopic = hardest.topic;
            selectedSource = 'difficult';
          }
          return match ?? (topicWords.isNotEmpty ? topicWords.first : null);
        }
        return null;
      }();

      // 3) If still none, pick a word from the current/last topic
      if (selectedWord == null && lastTopic.isNotEmpty) {
        final topicWords = await _wordRepository.getWordsByTopic(lastTopic);
        if (topicWords.isNotEmpty) {
          topicWords.shuffle();
          selectedWord = topicWords.first;
          selectedTopic = lastTopic;
          selectedSource = 'topic';
        }
      }

      // 3.5) If still none, pick from the first topic (beginner)
      if (selectedWord == null) {
        final allTopics = await _topicService.getTopicsForDisplay();
        if (allTopics.isNotEmpty) {
          final firstTopicId = allTopics.first.essentials.id;
          final firstTopicWords = await _wordRepository.getWordsByTopic(firstTopicId);
          if (firstTopicWords.isNotEmpty) {
            firstTopicWords.shuffle();
            selectedWord = firstTopicWords.first;
            selectedTopic = firstTopicId;
            selectedSource = 'first_topic';
          }
        }
      }

      // 4) Final fallback: any random word
      selectedWord ??= await () async {
        final randomWords = await _wordRepository.getRandomWords(1);
        if (randomWords.isEmpty) {
          throw Exception('No words available');
        }
        selectedSource = 'random';
        return randomWords.first;
      }();
      
      wordOfTheDay = {
        'word': selectedWord.en,
        'pronunciation': selectedWord.pronunciation,
        'meaning': selectedWord.vi,
        'example': selectedWord.sentence,
        'exampleVi': selectedWord.sentenceVi,
        'topic': selectedTopic ?? selectedWord.topic,
        'source': selectedSource ?? 'topic',
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

  // Removed _initializeTopicGroupsWithRealData - replaced with simplified _createTopicGroupsFromVocabulary

  void _initializeBasicTopicGroups() {
    // Fallback basic structure if real data loading fails
    topicGroups = [
      {
        'id': 'basic',
        'name': 'Basic',
        'description': 'Từ vựng cơ bản hàng ngày',
        'targetWords': 500,
        'learnedWords': totalWordsLearned.clamp(0, 500),
        'color': Colors.green,
        'icon': Icons.star,
        'topics': ['schools', 'family', 'colors', 'numbers'],
        'level': 'basic',
      },
      {
        'id': 'intermediate',
        'name': 'Intermediate',
        'description': 'Từ vựng trung cấp',
        'targetWords': 300,
        'learnedWords': (totalWordsLearned - 500).clamp(0, 300),
        'color': Colors.purple,
        'icon': Icons.psychology,
        'topics': ['business', 'technology', 'travel'],
        'level': 'intermediate',
      },
      {
        'id': 'advanced',
        'name': 'Advanced',
        'description': 'Từ vựng nâng cao',
        'targetWords': 200,
        'learnedWords': (totalWordsLearned - 800).clamp(0, 200),
        'color': Colors.teal,
        'icon': Icons.work,
        'topics': ['science', 'literature', 'philosophy'],
        'level': 'advanced',
      },
    ];
    
    _determineActiveGroup();
  }

  void _determineActiveGroup() {
    if (topicGroups.isEmpty) {
      currentActiveGroup = "Basic";
      return;
    }
    
    // Find the first group that is not 100% complete
    for (var group in topicGroups) {
      final learnedWords = group['learnedWords'] as int;
      final targetWords = group['targetWords'] as int;
      
      if (targetWords == 0) continue;
      
      final progress = learnedWords / targetWords;
      if (progress < 1.0) {
        currentActiveGroup = group['name'];
        return;
      }
    }
    
    // If all groups are complete, default to the last group
    if (topicGroups.isNotEmpty) {
      currentActiveGroup = topicGroups.last['name'];
    }
  }

  Future<void> _loadTopics() async {
    try {
      print("Starting to load topics...");
      final loadedTopics = await _topicService.getTopicsForDisplay();
      print("Loaded ${loadedTopics.length} topics: ${loadedTopics.map((t) => t.id).toList()}");
      
      // Tạo topicGroups từ vocabulary data
      await _createTopicGroupsFromVocabulary();
      
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

  Future<void> _createTopicGroupsFromVocabulary() async {
    try {
      final allTopics = await _topicService.getTopicsForDisplay();
      // Progress data is now calculated within TopicService
      
      // Phân loại topics theo level từ vocabulary data (chỉ 3 level)
      final basicTopics = allTopics.where((topic) => topic.level == 'BASIC').toList();
      final intermediateTopics = allTopics.where((topic) => topic.level == 'INTERMEDIATE').toList();
      final advancedTopics = allTopics.where((topic) => topic.level == 'ADVANCED').toList();

      // Helper function để tính từ đã học từ topic model mới
      int calculateLearnedWordsFromTopics(List<Topic> topics) {
        return topics.fold<int>(0, (sum, topic) => sum + topic.learnedWords);
      }

      int calculateTargetWords(List<Topic> topics) {
        return topics.fold<int>(0, (sum, topic) => sum + topic.totalWords);
      }

      // Tạo chỉ 3 groups theo level thực tế
      List<Map<String, dynamic>> groups = [];

      // Basic Group
      if (basicTopics.isNotEmpty) {
        final learnedWords = calculateLearnedWordsFromTopics(basicTopics);
        groups.add({
          'id': 'basic',
          'name': 'Basic',
          'description': 'Từ vựng cơ bản hàng ngày',
          'targetWords': calculateTargetWords(basicTopics),
          'learnedWords': learnedWords,
          'color': Colors.green,
          'icon': Icons.star,
          'topics': basicTopics.map((t) => t.id).toList(),
          'level': 'basic',
          'topicObjects': basicTopics,
        });
      }

      // Intermediate Group
      if (intermediateTopics.isNotEmpty) {
        final learnedWords = calculateLearnedWordsFromTopics(intermediateTopics);
        groups.add({
          'id': 'intermediate',
          'name': 'Intermediate',
          'description': 'Từ vựng trung cấp',
          'targetWords': calculateTargetWords(intermediateTopics),
          'learnedWords': learnedWords,
          'color': Colors.purple,
          'icon': Icons.psychology,
          'topics': intermediateTopics.map((t) => t.id).toList(),
          'level': 'intermediate',
          'topicObjects': intermediateTopics,
        });
      }

      // Advanced Group
      if (advancedTopics.isNotEmpty) {
        final learnedWords = calculateLearnedWordsFromTopics(advancedTopics);
        groups.add({
          'id': 'advanced',
          'name': 'Advanced',
          'description': 'Từ vựng nâng cao',
          'targetWords': calculateTargetWords(advancedTopics),
          'learnedWords': learnedWords,
          'color': Colors.teal,
          'icon': Icons.work,
          'topics': advancedTopics.map((t) => t.id).toList(),
          'level': 'advanced',
          'topicObjects': advancedTopics,
        });
      }

      topicGroups = groups;
      
      // Determine current active group based on progress
      _determineActiveGroup();
      
      print('📊 Created ${groups.length} topic groups:');
      for (final group in groups) {
        print('  - ${group['name']}: ${group['learnedWords']}/${group['targetWords']} từ');
      }
      
    } catch (e) {
      print('Error creating topic groups: $e');
      _initializeBasicTopicGroups(); // Fallback
    }
  }

  // Removed helper methods - no longer needed with simplified 3-level structure

  Future<void> _loadReviewedWords() async {
    try {
      print("Loading reviewed words...");
      final progressRepo = UserProgressRepository();
      final allTopicsProgress = await progressRepo.getAllTopicsProgress();
      
      // Convert progress data to reviewed words format
      final loadedReviewedWords = <String, List<Word>>{};
      for (final entry in allTopicsProgress.entries) {
        final topic = entry.key;
        final progress = entry.value;
        final learnedCount = progress['learnedWords'] ?? 0;
        
        // Create dummy words list for compatibility (we only need the count)
        if (learnedCount > 0) {
          loadedReviewedWords[topic] = List.generate(learnedCount, (index) => 
            dWord(
              en: 'word_$index', 
              vi: 'word_$index', 
              topic: topic,
              pronunciation: '',
              sentence: '',
              sentenceVi: '',
              level: WordLevel.BASIC,
              type: WordType.noun,
              difficulty: 1,
              nextReview: DateTime.now(),
            )
          );
        }
      }
      
      print("Loaded reviewed words: ${loadedReviewedWords.keys.length} topics");
      
      setState(() {
        reviewedWordsByTopic = loadedReviewedWords;
      });
    } catch (e) {
      print("Error loading reviewed words: $e");
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
          Row(
            children: [
              // Current Streak
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
              
              const SizedBox(width: 12),
              
              // Longest Streak
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Kỷ lục: $longestStreak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    final groupColor = activeGroup['color'] as Color;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Compact progress circle
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(groupColor),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Progress info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeGroup['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$learnedWords/$targetWords từ đã học',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                // All groups overview in compact form
                _buildCompactGroupsOverview(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGroupsOverview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: topicGroups.asMap().entries.map((entry) {
        final index = entry.key;
        final group = entry.value;
        final progress = (group['targetWords'] as int) > 0 
            ? (group['learnedWords'] as int) / (group['targetWords'] as int)
            : 0.0;
        final isActive = group['name'] == currentActiveGroup;
        
        return Flexible(
          flex: 1,
          child: GestureDetector(
            onTap: () {
              setState(() {
                currentActiveGroup = group['name'];
              });
            },
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == topicGroups.length - 1 ? 0 : 4,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: isActive ? (group['color'] as Color).withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? (group['color'] as Color) : Colors.grey[300]!,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 16,
                    child: Text(
                      group['name'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? (group['color'] as Color) : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(group['color'] as Color),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 12,
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Removed _buildGroupsOverview - replaced with _buildCompactGroupsOverview

  // Removed _buildLevelSection - no longer needed with simplified structure

  Widget _buildDailyGoal() {
    if (isDashboardLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[100]!),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final progress = dailyGoal > 0 ? todayWordsLearned / dailyGoal : 0.0;
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
              fontSize: 11,
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
        onPressed: () async {
          final targetTopicId = lastTopic.isNotEmpty ? lastTopic : (await _getFirstTopicId()) ?? '';
          if (targetTopicId.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chưa có chủ đề để bắt đầu.')),
              );
            }
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicDetailScreen(topic: targetTopicId),
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
            Flexible(
              child: Text(
                (lastTopic.isNotEmpty || lastTopicName.isNotEmpty)
                    ? 'Tiếp tục học chủ đề ${(lastTopicName.isNotEmpty ? lastTopicName : lastTopic).toUpperCase()}'
                    : 'Bắt đầu học',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
              final reviewedCount = reviewedWordsByTopic[topic.id]?.length ?? 0;
              return _buildRecommendedTopicCard(topic, reviewedCount);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedTopicCard(Topic topic, int reviewedCount) {
    final topicData = _getTopicData(topic.id);
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
                            builder: (context) => TopicDetailScreen(topic: topic.id),
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
                  topic.name.toUpperCase(),
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
          
          // Source chip and quick link
          Builder(
            builder: (context) {
              final source = (wordOfTheDay['source'] ?? 'topic').toString();
              final topicId = (wordOfTheDay['topic'] ?? '').toString();
              String sourceLabel;
              switch (source) {
                case 'review':
                  sourceLabel = 'Đến hạn ôn tập';
                  break;
                case 'difficult':
                  sourceLabel = 'Từ khó';
                  break;
                case 'topic':
                  sourceLabel = 'Chủ đề đang học';
                  break;
                default:
                  sourceLabel = 'Ngẫu nhiên';
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple[100]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.purple),
                        const SizedBox(width: 6),
                        Text(
                          'Nguồn: $sourceLabel',
                          style: const TextStyle(fontSize: 12, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                  if (topicId.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TopicDetailScreen(topic: topicId),
                          ),
                        );
                      },
                      child: const Text('Mở chủ đề'),
                    ),
                ],
              );
            },
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
    // Fallback for unknown topics - should use topic model properties instead
    return {
      'totalWords': 20,
      'difficulty': 'Beginner',
      'icon': Icons.book,
      'color': Colors.blue,
      'estimatedTime': '10 min',
    };
  }

  // Removed _getGroupDisplayName - no longer needed with simplified group names

  // Utility methods for progress tracking
  Future<void> _addWordOfTheDayToReview() async {
    try {
      if (wordOfTheDay.isEmpty) return;
      
      // Find the word in repository and mark as reviewed
      final allWords = await _wordRepository.getAllWords();
      final wordToAdd = allWords.firstWhere(
        (word) => word.en.toLowerCase() == wordOfTheDay['word'].toString().toLowerCase(),
        orElse: () => allWords.first, // Fallback
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
    
    // Update today's word count via UserProgressRepository (centralized)
    final progressRepo = UserProgressRepository();
    await progressRepo.updateTodayWordsLearned(wordsLearned);
    
    // Mark today as learned
    await prefs.setBool('learned_$todayKey', true);
    
    // Update total words learned
    final totalWords = prefs.getInt('total_words_learned') ?? 0;
    final newTotalWords = totalWords + wordsLearned;
    await prefs.setInt('total_words_learned', newTotalWords);
    
    // Get updated today's count for achievements
    final newCount = await progressRepo.getTodayWordsLearned();
    
    // Check for achievements and trigger notifications
    await _checkAndTriggerAchievements(newTotalWords, newCount);
    
    // Update last active date and check streak
    final notificationManager = NotificationManager();
    await notificationManager.updateLastActiveDate();
    
    // Check for streak milestone
    final currentStreak = prefs.getInt('streak_days') ?? 0;
    if (currentStreak > 0 && (currentStreak == 7 || currentStreak == 30 || currentStreak == 100 || (currentStreak % 50 == 0 && currentStreak > 100))) {
      await notificationManager.showStreakMilestone(currentStreak);
    }
    
    // Refresh dashboard data
    await _loadDashboardData();
  }

  Future<void> _checkAndTriggerAchievements(int totalWords, int todayWords) async {
    final notificationManager = NotificationManager();
    
    // First word achievement
    if (totalWords == 1) {
      await notificationManager.showAchievement(
        title: 'Từ Đầu Tiên',
        description: 'Chào mừng bạn bắt đầu hành trình học từ vựng!',
        type: 'words',
        value: 1,
      );
    }
    
    // Word milestone achievements
    if (totalWords == 10) {
      await notificationManager.showAchievement(
        title: '10 Từ Đầu Tiên',
        description: 'Khởi đầu tuyệt vời! Tiếp tục xây dựng vốn từ vựng nhé!',
        type: 'words',
        value: 10,
      );
    } else if (totalWords == 50) {
      await notificationManager.showAchievement(
        title: '50 Từ Đã Thành Thạo',
        description: 'Bạn đang tiến bộ xuất sắc!',
        type: 'words',
        value: 50,
      );
    } else if (totalWords == 100) {
      await notificationManager.showAchievement(
        title: 'Câu Lạc Bộ Trăm Từ',
        description: '100 từ đã học! Bạn không thể cản được!',
        type: 'words',
        value: 100,
      );
    } else if (totalWords % 100 == 0 && totalWords > 100) {
      await notificationManager.showAchievement(
        title: 'Nhà Vô Địch $totalWords Từ',
        description: 'Sự tận tâm của bạn thật truyền cảm hứng!',
        type: 'words',
        value: totalWords,
      );
    }
    
    // Daily goal achievements
    final dailyGoal = await SharedPreferences.getInstance().then((prefs) => prefs.getInt('daily_goal') ?? 10);
    if (todayWords >= dailyGoal) {
      await notificationManager.showAchievement(
        title: 'Đạt Mục Tiêu Hàng Ngày',
        description: 'Bạn đã hoàn thành mục tiêu học tập hôm nay!',
        type: 'daily_goal',
        value: todayWords,
      );
    }
  }

  // Method to refresh dashboard when returning from other screens
  Future<void> refreshDashboard() async {
    await _loadDashboardData();
    await _loadReviewedWords();
  }
}
