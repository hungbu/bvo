import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dongsonword/model/word.dart';
import 'package:dongsonword/repository/word_repository.dart';
import 'package:dongsonword/repository/quiz_repository.dart';
import 'package:dongsonword/repository/user_progress_repository.dart';
import 'package:dongsonword/screen/flashcard_screen.dart';
import 'package:dongsonword/main.dart';

class TopicDetailScreen extends StatefulWidget {
  final String topic;
  const TopicDetailScreen({super.key, required this.topic});

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> with RouteAware {
  List<Word> words = [];
  Map<String, Map<String, dynamic>> wordsProgress = {};
  Map<String, dynamic> topicProgress = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    init();
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
    // Called when returning to this screen from FlashCard
    print('🔄 TopicDetailScreen: didPopNext - refreshing progress data');
    _refreshProgressData();
  }


  Future<void> init() async {
    setState(() => isLoading = true);
    
    // Load words and progress data (sorted by difficulty)
    words = await WordRepository().getWordsByTopicSortedByDifficulty(widget.topic);
    
    final progressRepo = UserProgressRepository();
    topicProgress = await progressRepo.getTopicProgress(widget.topic);
    
    // Load individual word progress
    final wordProgressList = await progressRepo.getTopicWordsWithProgress(widget.topic);
    wordsProgress = {};
    for (final wordProg in wordProgressList) {
      final wordEn = wordProg['word'] as String;
      wordsProgress[wordEn] = wordProg;
    }
    
    setState(() => isLoading = false);
  }

  /// Refresh progress data after returning from FlashCard
  Future<void> _refreshProgressData() async {
    print('🔄 Refreshing progress data for topic: ${widget.topic}');
    
    final progressRepo = UserProgressRepository();
    
    // Reload topic progress
    final updatedTopicProgress = await progressRepo.getTopicProgress(widget.topic);
    
    // Reload individual word progress
    final wordProgressList = await progressRepo.getTopicWordsWithProgress(widget.topic);
    final updatedWordsProgress = <String, Map<String, dynamic>>{};
    for (final wordProg in wordProgressList) {
      final wordEn = wordProg['word'] as String;
      updatedWordsProgress[wordEn] = wordProg;
    }
    
    if (mounted) {
      setState(() {
        topicProgress = updatedTopicProgress;
        wordsProgress = updatedWordsProgress;
      });
      
      print('✅ Progress data refreshed - Topic: ${updatedTopicProgress['learnedWords']} learned words');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Topic Header with Stats
              _buildTopicHeader(),
              
              // Action Buttons
              _buildActionButtons(),
              
              // Words List
              Expanded(child: _buildWordsList()),
            ],
          ),
    );
  }

  Widget _buildTopicHeader() {
    // Calculate stats from progress data
    int newWords = 0;
    int learningWords = 0;
    int masteredWords = 0;
    
    for (final word in words) {
      final progress = wordsProgress[word.en];
      if (progress != null) {
        final reviewCount = progress['reviewCount'] ?? 0;
        final isLearned = progress['isLearned'] ?? false;
        
        if (reviewCount == 0) {
          newWords++;
        } else if (isLearned) {
          masteredWords++;
        } else {
          learningWords++;
        }
      } else {
        newWords++; // No progress = new word
      }
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
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
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '${words.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Từ Vựng',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          _buildStatItem('Mới', newWords, Colors.blue),
          _buildStatItem('Đang Học', learningWords, Colors.orange),
          _buildStatItem('Đã Thành Thạo', masteredWords, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Update last topic before starting flashcard
                final progressRepo = UserProgressRepository();
                await progressRepo.setLastTopic(widget.topic);
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FlashCardScreen(
                      topic: widget.topic,
                      words: words,
                      startIndex: 0, // Start from beginning
                    ),
                  ),
                );
                
                // Refresh data when returning from FlashCard
                if (result != null || mounted) {
                  await _refreshProgressData();
                }
              },
              icon: const Icon(Icons.quiz, size: 18),
              label: const Text('FlashCard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _addAllWordsToQuiz(),
              icon: const Icon(Icons.add_task, size: 18),
              label: const Text('Thêm Tất Cả Vào Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsList() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        itemCount: words.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final word = words[index];
          return _buildWordCard(word, index + 1);
        },
      ),
    );
  }



  Widget _buildWordCard(Word word, int wordNumber) {
    // Get progress from UserProgressRepository
    final progress = wordsProgress[word.en];
    final reviewCount = progress?['reviewCount'] ?? 0;
    final isLearned = progress?['isLearned'] ?? false;
    final correctAnswers = progress?['correctAnswers'] ?? 0;
    final totalAttempts = progress?['totalAttempts'] ?? 0;
    
    // Calculate accuracy and progress
    final accuracy = totalAttempts > 0 ? (correctAnswers / totalAttempts) : 0.0;
    final progressValue = reviewCount > 0 ? (reviewCount / 10.0).clamp(0.0, 1.0) : 0.0;
    
    String difficultyLevel = reviewCount == 0 ? 'Mới' : 
                           !isLearned ? 'Đang Học' :
                           accuracy >= 0.8 ? 'Thành Thạo' : 'Quen Thuộc';
    
    Color difficultyColor = reviewCount == 0 ? Colors.blue :
                          !isLearned ? Colors.orange :
                          accuracy >= 0.8 ? Colors.purple : Colors.green;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // Có thể thêm hành động khi nhấn vào từ vựng
          _showWordDetails(word);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left side - Word info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with word number and difficulty level
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$wordNumber',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: difficultyColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            difficultyLevel,
                            style: TextStyle(
                              color: difficultyColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          CupertinoIcons.heart_fill,
                          size: 12,
                          color: difficultyColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "$reviewCount",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: difficultyColor,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // English word
                    Text(
                      word.en,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Vietnamese translation
                    Text(
                      word.vi,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Progress bar (compact)
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
                            minHeight: 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progressValue * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: difficultyColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Right side - Add to Quiz button (icon only)
              IconButton(
                onPressed: () => _addWordToQuiz(word),
                icon: const Icon(Icons.add_task),
                color: Colors.green,
                iconSize: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWordDetails(Word word) {
    // Get progress data for this word
    final progress = wordsProgress[word.en];
    final reviewCount = progress?['reviewCount'] ?? 0;
    final correctAnswers = progress?['correctAnswers'] ?? 0;
    final totalAttempts = progress?['totalAttempts'] ?? 0;
    final accuracy = totalAttempts > 0 ? (correctAnswers / totalAttempts * 100).toStringAsFixed(1) : '0.0';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text('Word Details'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'English: ${word.en}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vietnamese: ${word.vi}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Topic: ${word.topic}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Difficulty: ${word.difficulty}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Review Count: $reviewCount',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Accuracy: $accuracy%',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Attempts: $correctAnswers/$totalAttempts',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _addWordToQuiz(Word word) async {
    try {
      final success = await QuizRepository().addWordToQuiz(word);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm "${word.en}" vào danh sách ôn tập!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Xem danh sách',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to Quiz tab
                Navigator.of(context).popUntil((route) => route.isFirst);
                // You can add navigation to quiz tab here if needed
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Từ "${word.en}" đã có trong danh sách ôn tập!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addAllWordsToQuiz() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang thêm từ vào danh sách ôn tập...'),
              ],
            ),
          );
        },
      );

      final addedCount = await QuizRepository().addWordsToQuiz(words);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm $addedCount từ vào danh sách ôn tập!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Xem danh sách',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tất cả từ đã có trong danh sách ôn tập!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }



}