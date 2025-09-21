import 'package:flutter/material.dart';
import 'package:bvo/service/difficult_words_service.dart';
import 'package:bvo/screen/flashcard_screen.dart';
import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';

class TargetedReviewScreen extends StatefulWidget {
  const TargetedReviewScreen({Key? key}) : super(key: key);

  @override
  State<TargetedReviewScreen> createState() => _TargetedReviewScreenState();
}

class _TargetedReviewScreenState extends State<TargetedReviewScreen> {
  final DifficultWordsService _difficultWordsService = DifficultWordsService();
  final WordRepository _wordRepository = WordRepository();
  
  List<DifficultWordData> _difficultWords = [];
  Map<String, TopicDifficultStats> _topicStats = {};
  bool _isLoading = true;
  String _selectedTopic = 'all';
  double _minErrorRate = 0.3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final difficultWords = await _difficultWordsService.getAllDifficultWords();
      final topicStats = await _difficultWordsService.getDifficultStatsByTopic();

      setState(() {
        _difficultWords = difficultWords;
        _topicStats = topicStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<DifficultWordData> get _filteredWords {
    var filtered = _difficultWords.where((word) => word.errorRate >= _minErrorRate);
    
    if (_selectedTopic != 'all') {
      filtered = filtered.where((word) => word.topic == _selectedTopic);
    }
    
    return filtered.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn tập từ khó'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic filter
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: 8),
              const Text('Chủ đề:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedTopic,
                  isExpanded: true,
                  onChanged: (value) {
                    setState(() {
                      _selectedTopic = value!;
                    });
                  },
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Tất cả chủ đề')),
                    ..._topicStats.keys.map((topic) => DropdownMenuItem(
                      value: topic,
                      child: Text(topic),
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Error rate filter
          Row(
            children: [
              const Icon(Icons.tune, size: 20),
              const SizedBox(width: 8),
              const Text('Tỷ lệ sai tối thiểu:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _minErrorRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(_minErrorRate * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() {
                      _minErrorRate = value;
                    });
                  },
                ),
              ),
              Text('${(_minErrorRate * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final filteredWords = _filteredWords;
    
    if (filteredWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Không có từ nào cần ôn tập!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thử giảm tỷ lệ sai hoặc chọn chủ đề khác.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tìm thấy ${filteredWords.length} từ cần ôn tập',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _startReviewSession(filteredWords),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu ôn tập'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Words list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredWords.length,
            itemBuilder: (context, index) {
              final word = filteredWords[index];
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    word.word,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${word.topic} • ${word.difficultyLevel}'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: 1 - word.errorRate,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          word.errorRate > 0.7 ? Colors.red :
                          word.errorRate > 0.5 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
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
                  onTap: () => _reviewSingleWord(word),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _startReviewSession(List<DifficultWordData> difficultWords) async {
    if (difficultWords.isEmpty) return;

    try {
      // Lấy danh sách Word objects từ repository
      List<Word> wordsToReview = [];
      
      for (var difficultWord in difficultWords) {
        final words = await _wordRepository.getWordsByTopic(difficultWord.topic);
        final matchingWord = words.firstWhere(
          (w) => w.en.toLowerCase() == difficultWord.word.toLowerCase(),
          orElse: () => Word(
            en: difficultWord.word,
            vi: 'Cần cập nhật',
            pronunciation: '',
            sentence: '',
            sentenceVi: '',
            topic: difficultWord.topic,
            level: WordLevel.BASIC,
            type: WordType.noun,
            difficulty: 3,
            reviewCount: 0,
            nextReview: DateTime.now(),
          ),
        );
        wordsToReview.add(matchingWord);
      }

      if (wordsToReview.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashCardScreen(
              words: wordsToReview,
              topic: 'Ôn tập từ khó',
              startIndex: 0,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải từ vựng: $e')),
      );
    }
  }

  Future<void> _reviewSingleWord(DifficultWordData difficultWord) async {
    try {
      final words = await _wordRepository.getWordsByTopic(difficultWord.topic);
      final matchingWord = words.firstWhere(
        (w) => w.en.toLowerCase() == difficultWord.word.toLowerCase(),
        orElse: () => Word(
          en: difficultWord.word,
          vi: 'Cần cập nhật',
          pronunciation: '',
          sentence: '',
          sentenceVi: '',
          topic: difficultWord.topic,
          level: WordLevel.BASIC,
          type: WordType.noun,
          difficulty: 3,
          reviewCount: 0,
          nextReview: DateTime.now(),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashCardScreen(
            words: [matchingWord],
            topic: 'Ôn tập: ${difficultWord.word}',
            startIndex: 0,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải từ vựng: $e')),
      );
    }
  }
}
