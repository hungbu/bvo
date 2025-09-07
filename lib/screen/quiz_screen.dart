import 'package:flutter/material.dart';
import '../model/word.dart';
import '../repository/quiz_repository.dart';
import 'quiz_game_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({Key? key}) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Word> quizWords = [];
  List<Word> dueWords = [];
  Map<String, dynamic> quizStats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    try {
      setState(() => isLoading = true);
      
      final quizRepository = QuizRepository();
      final loadedWords = await quizRepository.getQuizWords();
      final loadedDueWords = await quizRepository.getDueWords();
      final stats = await quizRepository.getQuizStats();
      
      setState(() {
        quizWords = loadedWords;
        dueWords = loadedDueWords;
        quizStats = stats;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading quiz data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(top: 16),
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
        child: RefreshIndicator(
          onRefresh: _loadQuizData,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : quizWords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có từ nào để ôn tập',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hãy thêm từ vào danh sách ôn tập từ các chủ đề',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to Topics tab - this will need to be handled by parent
                            },
                            icon: const Icon(Icons.topic),
                            label: const Text('Xem chủ đề'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        // Quiz Statistics Card
                        _buildQuizStatsCard(),
                        
                        const SizedBox(height: 12),
                        
                        // Due Words Section
                        if (dueWords.isNotEmpty) ...[
                          _buildSectionHeader('Từ cần ôn tập ngay (${dueWords.length})', Icons.schedule),
                          const SizedBox(height: 6),
                          _buildQuizButton(),
                          const SizedBox(height: 12),
                        ],
                        
                        // All Quiz Words Section
                        _buildSectionHeader('Tất cả từ ôn tập (${quizWords.length})', Icons.list),
                        const SizedBox(height: 6),
                        
                        // Words List
                        ...quizWords.asMap().entries.map((entry) {
                          final index = entry.key;
                          final word = entry.value;
                          return _buildQuizWordCard(word, index + 1);
                        }).toList(),
                        
                        const SizedBox(height: 80), // Bottom padding
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildQuizStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          _buildStatItem('Tổng từ', '${quizStats['totalWords'] ?? 0}', Icons.book),
          _buildStatItem('Cần ôn', '${quizStats['dueWords'] ?? 0}', Icons.schedule),
          _buildStatItem('Độ chính xác', '${(quizStats['accuracy'] ?? 0.0).toStringAsFixed(1)}%', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: dueWords.isNotEmpty ? () => _startQuiz() : null,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: Text('Bắt đầu Quiz (${dueWords.length} từ)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildQuizWordCard(Word word, int index) {
    // Calculate progress and status
    double progress = word.totalAttempts > 0 ? (word.correctAnswers / word.totalAttempts) : 0.0;
    String status = word.reviewCount == 0 ? 'Mới' : 
                   word.reviewCount < 3 ? 'Đang học' :
                   word.reviewCount < 7 ? 'Quen thuộc' : 'Thành thạo';
    
    Color statusColor = word.reviewCount == 0 ? Colors.blue :
                       word.reviewCount < 3 ? Colors.orange :
                       word.reviewCount < 7 ? Colors.green : Colors.purple;

    bool isDue = dueWords.contains(word);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isDue ? BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left side - Word info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$index',
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
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        if (isDue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Cần ôn',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
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
                    
                    // Vietnamese translation and topic
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            word.vi,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Text(
                            word.topic,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Progress bar with stats
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            minHeight: 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${word.correctAnswers}/${word.totalAttempts}',
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Right side - Delete button
              IconButton(
                onPressed: () => _removeWordFromQuiz(word),
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                iconSize: 18,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
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

  void _startQuiz() {
    if (dueWords.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizGameScreen(
          words: dueWords,
          title: 'Quiz ôn tập',
        ),
      ),
    ).then((_) {
      // Refresh data when returning from quiz
      _loadQuizData();
    });
  }

  void _removeWordFromQuiz(Word word) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa từ khỏi danh sách ôn tập'),
          content: Text('Bạn có chắc muốn xóa từ "${word.en}" khỏi danh sách ôn tập?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final success = await QuizRepository().removeWordFromQuiz(word);
        if (success) {
          await _loadQuizData(); // Refresh data
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa "${word.en}" khỏi danh sách ôn tập'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
