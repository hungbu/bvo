import 'package:flutter/material.dart';
import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/service/difficult_words_service.dart';
import 'package:bvo/screen/flashcard_screen.dart';
import 'package:bvo/screen/quiz_game_screen.dart';

class SmartReviewScreen extends StatefulWidget {
  const SmartReviewScreen({super.key});

  @override
  State<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends State<SmartReviewScreen> {
  final DifficultWordsService _difficultWordsService = DifficultWordsService();
  final WordRepository _wordRepository = WordRepository();
  
  List<Word> difficultWords = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDifficultWords();
  }

  Future<void> _loadDifficultWords() async {
    try {
      setState(() => isLoading = true);
      
      // Get all difficult words
      final difficultWordsData = await _difficultWordsService.getAllDifficultWords();
      
      // Convert DifficultWordData to Word objects
      final words = <Word>[];
      for (final difficultWord in difficultWordsData) {
        final topicWords = await _wordRepository.getWordsByTopic(difficultWord.topic);
        final word = topicWords.firstWhere(
          (w) => w.en.toLowerCase() == difficultWord.word.toLowerCase(),
          orElse: () => topicWords.first,
        );
        words.add(word);
      }
      
      setState(() {
        difficultWords = words;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading difficult words: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ôn tập thông minh',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : difficultWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không có từ nào cần ôn tập',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tuyệt vời! Bạn đã thuộc tất cả các từ.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header with action buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: difficultWords.isEmpty
                                  ? null
                                  : () => _startFlashcard(),
                              icon: const Icon(Icons.style),
                              label: const Text('Flashcard'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: difficultWords.isEmpty
                                  ? null
                                  : () => _startQuiz(),
                              icon: const Icon(Icons.quiz),
                              label: const Text('Quiz'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Words list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: difficultWords.length,
                        itemBuilder: (context, index) {
                          final word = difficultWords[index];
                          return _buildWordCard(word, index);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildWordCard(Word word, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Index badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple[400],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Word info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.en,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.pronunciation,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.vi,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startFlashcard() async {
    if (difficultWords.isEmpty) return;
    
    // Group words by topic (use first topic as default)
    final topic = difficultWords.first.topic;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashCardScreen(
          words: difficultWords,
          topic: topic,
          startIndex: 0,
        ),
      ),
    );
  }

  Future<void> _startQuiz() async {
    if (difficultWords.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizGameScreen(
          words: difficultWords,
          title: 'Quiz từ hay quên',
        ),
      ),
    );
  }
}

