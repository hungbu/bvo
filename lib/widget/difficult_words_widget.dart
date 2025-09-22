import 'package:flutter/material.dart';
import 'package:bvo/service/difficult_words_service.dart';
import 'package:bvo/screen/targeted_review_screen.dart';
import 'package:bvo/screen/reminder_settings_screen.dart';

class DifficultWordsWidget extends StatefulWidget {
  const DifficultWordsWidget({Key? key}) : super(key: key);

  @override
  State<DifficultWordsWidget> createState() => _DifficultWordsWidgetState();
}

class _DifficultWordsWidgetState extends State<DifficultWordsWidget> {
  final DifficultWordsService _difficultWordsService = DifficultWordsService();
  List<DifficultWordData> _topDifficultWords = [];
  Map<String, TopicDifficultStats> _topicStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDifficultWords();
  }

  Future<void> _loadDifficultWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final topWords = await _difficultWordsService.getTopDifficultWords(10);
      final stats = await _difficultWordsService.getDifficultStatsByTopic();

      setState(() {
        _topDifficultWords = topWords;
        _topicStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading difficult words: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Column(
      children: [
        // Top từ khó nhất
        _buildTopDifficultWordsCard(),
        const SizedBox(height: 16),
        // Thống kê theo topic
        _buildTopicStatsCard(),
        const SizedBox(height: 16),
        // Đề xuất ôn tập
        _buildReviewSuggestionsCard(),
      ],
    );
  }

  Widget _buildTopDifficultWordsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Từ khó nhất của bạn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_topDifficultWords.isEmpty)
              const Text(
                'Chưa có dữ liệu từ khó. Hãy học flashcard để thu thập dữ liệu!',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              Column(
                children: _topDifficultWords.take(5).map((word) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: word.difficultyColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.word,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${word.topic} • ${word.difficultyLevel}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(word.errorRate * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: word.difficultyColor,
                              ),
                            ),
                            Text(
                              '${word.incorrectCount}/${word.totalAttempts}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (_topDifficultWords.length > 5)
              TextButton(
                onPressed: () => _showAllDifficultWords(),
                child: Text('Xem tất cả ${_topDifficultWords.length} từ khó'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicStatsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Thống kê theo chủ đề',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_topicStats.isEmpty)
              const Text(
                'Chưa có dữ liệu thống kê theo chủ đề.',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              Column(
                children: _topicStats.entries.map((entry) {
                  final stats = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                stats.topic,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${(stats.averageErrorRate * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getErrorRateColor(stats.averageErrorRate),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatChip('All', '${stats.totalDifficultWords}', Colors.grey),
                              const SizedBox(width: 8),
                              _buildStatChip('Rất khó', '${stats.highErrorWords}', Colors.red),
                              const SizedBox(width: 8),
                              _buildStatChip('Khó', '${stats.mediumErrorWords}', Colors.orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSuggestionsCard() {
    final wordsNeedingReview = _topDifficultWords.where((w) => w.errorRate > 0.3).length;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Đề xuất ôn tập',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (wordsNeedingReview == 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tuyệt vời! Bạn không có từ nào cần ôn tập đặc biệt.',
                        style: TextStyle(color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bạn có $wordsNeedingReview từ cần ôn tập để cải thiện.',
                            style: TextStyle(color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startTargetedReview(),
                          icon: const Icon(Icons.school),
                          label: const Text('Ôn tập từ khó'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _configureReminders(),
                          icon: const Icon(Icons.notifications),
                          label: const Text('Cài đặt nhắc nhở'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getErrorRateColor(double errorRate) {
    if (errorRate > 0.7) return Colors.red;
    if (errorRate > 0.5) return Colors.orange;
    if (errorRate > 0.3) return Colors.yellow[700]!;
    return Colors.green;
  }

  void _showAllDifficultWords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllDifficultWordsScreen(words: _topDifficultWords),
      ),
    );
  }

  void _startTargetedReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TargetedReviewScreen(),
      ),
    );
  }

  void _configureReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReminderSettingsScreen(),
      ),
    );
  }
}

class AllDifficultWordsScreen extends StatelessWidget {
  final List<DifficultWordData> words;

  const AllDifficultWordsScreen({Key? key, required this.words}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tất cả từ khó'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: word.difficultyColor,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                word.word,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${word.topic} • ${word.difficultyLevel}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(word.errorRate * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: word.difficultyColor,
                    ),
                  ),
                  Text(
                    '${word.incorrectCount}/${word.totalAttempts}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
