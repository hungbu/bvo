import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:bvo/model/word.dart';
import 'package:bvo/service/vocabulary_data_loader.dart';
import 'package:bvo/screen/flashcard_screen.dart';
import 'package:bvo/repository/user_progress_repository.dart';
import 'package:bvo/repository/quiz_repository.dart';

class TopicLevelScreen extends StatefulWidget {
  const TopicLevelScreen({super.key});

  @override
  State<TopicLevelScreen> createState() => _TopicLevelScreenState();
}

class _TopicLevelScreenState extends State<TopicLevelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VocabularyDataLoader _dataLoader = VocabularyDataLoader();
  final UserProgressRepository _progressRepository = UserProgressRepository();
  final FlutterTts _flutterTts = FlutterTts();
  Set<String> _addedToQuizWords = {}; // Track words added to quiz
  Set<String> _masteredWords = {}; // Track words marked as mastered
  
  List<Word> _basicWords = [];
  List<Word> _intermediateWords = [];
  List<Word> _advancedWords = [];
  
  bool _isLoading = true;
  int _refreshKey = 0; // Key to force FutureBuilder rebuild
  
  // Statistics for each level
  Map<String, int> _learnedCount = {
    'BASIC': 0,
    'INTERMEDIATE': 0,
    'ADVANCED': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load words for each level
      _basicWords = await _dataLoader.getBasicWords();
      _intermediateWords = await _dataLoader.getIntermediateWords();
      _advancedWords = await _dataLoader.getAdvancedWords();

      // Calculate learned count for each level
      await _calculateLearnedCount();

      print('📚 Loaded Basic: ${_basicWords.length}, Intermediate: ${_intermediateWords.length}, Advanced: ${_advancedWords.length}');
    } catch (e) {
      print('❌ Error loading words: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateLearnedCount() async {
    try {
      int basicLearned = 0;
      int intermediateLearned = 0;
      int advancedLearned = 0;

      // Check progress for basic words
      for (final word in _basicWords) {
        final progress = await _progressRepository.getWordProgress(word.topic, word.en);
        final reviewCount = progress['reviewCount'] ?? 0;
        if (reviewCount >= 5) {
          basicLearned++;
        }
      }

      // Check progress for intermediate words
      for (final word in _intermediateWords) {
        final progress = await _progressRepository.getWordProgress(word.topic, word.en);
        final reviewCount = progress['reviewCount'] ?? 0;
        if (reviewCount >= 5) {
          intermediateLearned++;
        }
      }

      // Check progress for advanced words
      for (final word in _advancedWords) {
        final progress = await _progressRepository.getWordProgress(word.topic, word.en);
        final reviewCount = progress['reviewCount'] ?? 0;
        if (reviewCount >= 5) {
          advancedLearned++;
        }
      }

      setState(() {
        _learnedCount = {
          'BASIC': basicLearned,
          'INTERMEDIATE': intermediateLearned,
          'ADVANCED': advancedLearned,
        };
      });
    } catch (e) {
      print('❌ Error calculating learned count: $e');
    }
  }

  /// Refresh data after returning from flashcard session
  Future<void> _refreshData() async {
    print('🔄 Refreshing TopicLevelScreen data...');
    
    // Recalculate learned count
    await _calculateLearnedCount();
    
    // Increment refresh key to force FutureBuilder rebuild
    setState(() {
      _refreshKey++;
    });
    
    print('✅ TopicLevelScreen refreshed (refreshKey: $_refreshKey)');
  }

  List<Word> _getCurrentLevelWords() {
    switch (_tabController.index) {
      case 0:
        return _basicWords;
      case 1:
        return _intermediateWords;
      case 2:
        return _advancedWords;
      default:
        return _basicWords;
    }
  }

  String _getCurrentLevelName() {
    switch (_tabController.index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Intermediate';
      case 2:
        return 'Advanced';
      default:
        return 'Basic';
    }
  }

  Future<void> _startFlashcard() async {
    final allWords = _getCurrentLevelWords();
    
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có từ nào để học ở level này!')),
      );
      return;
    }

    print('🎯 TopicLevelScreen: Total words in level: ${allWords.length}');
    
    // Filter out mastered words (reviewCount >= 5 = đã thuộc)
    final List<Word> wordsToLearn = [];
    final List<String> masteredWords = [];
    
    for (final word in allWords) {
      final progress = await _progressRepository.getWordProgress(word.topic, word.en);
      final reviewCount = progress['reviewCount'] ?? 0;
      
      if (reviewCount < 5) {
        wordsToLearn.add(word);
      } else {
        masteredWords.add('${word.en} (${word.topic})');
        print('  ✅ MASTERED (filtered out): "${word.en}" from topic "${word.topic}" - reviewCount=$reviewCount');
      }
    }

    print('🎯 TopicLevelScreen: Words to learn: ${wordsToLearn.length}');
    print('🎯 TopicLevelScreen: Mastered words (filtered out): ${masteredWords.length}');
    
    // Debug: Check first 10 words in wordsToLearn to see if any mastered word slipped through
    if (wordsToLearn.isNotEmpty) {
      print('🎯 First 10 words going to FlashCard:');
      for (int i = 0; i < wordsToLearn.length && i < 10; i++) {
        final word = wordsToLearn[i];
        final progress = await _progressRepository.getWordProgress(word.topic, word.en);
        final rc = progress['reviewCount'] ?? 0;
        print('  [$i] "${word.en}" (${word.topic}) - reviewCount=$rc ${rc >= 5 ? "⚠️ SHOULD BE FILTERED!" : "✓"}');
      }
    }

    if (wordsToLearn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tất cả từ ở level này đã được thuộc rồi! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashCardScreen(
          words: wordsToLearn,
          topic: '${_getCurrentLevelName()} Level',
          startIndex: 0,
        ),
      ),
    ).then((_) {
      // Refresh statistics and UI after learning
      _refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // TabBar as a custom header
        Container(
          color: Theme.of(context).primaryColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            tabs: [
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Basic'),
                    const SizedBox(height: 2),
                    Text(
                      '${_basicWords.length} từ',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Intermediate'),
                    const SizedBox(height: 2),
                    Text(
                      '${_intermediateWords.length} từ',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Advanced'),
                    const SizedBox(height: 2),
                    Text(
                      '${_advancedWords.length} từ',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWordList(_basicWords, 'BASIC'),
              _buildWordList(_intermediateWords, 'INTERMEDIATE'),
              _buildWordList(_advancedWords, 'ADVANCED'),
            ],
          ),
        ),
        // Flashcard button at bottom
        _buildFlashcardButton(),
      ],
    );
  }

  Widget _buildWordList(List<Word> words, String level) {
    if (words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không có từ nào ở level này',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final learnedCount = _learnedCount[level] ?? 0;
    final totalWords = words.length;
    final progress = totalWords > 0 ? learnedCount / totalWords : 0.0;

    return Column(
      children: [
        // Progress summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiến độ học',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$learnedCount / $totalWords',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Word list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              return _buildWordCard(word, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(Word word, int index) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('word_${word.en}_${word.topic}_$_refreshKey'), // Force rebuild when refreshKey changes
      future: _progressRepository.getWordProgress(word.topic, word.en),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        final reviewCount = progress?['reviewCount'] ?? 0;
        final isLearned = reviewCount >= 5;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isLearned 
                  ? Colors.green[400] 
                  : Theme.of(context).primaryColor.withOpacity(0.2),
              child: isLearned
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(
              word.en,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  word.vi,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                if (word.pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '/${word.pronunciation}/',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 2),
                Text(
                  '$reviewCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            onTap: () => _showWordDetails(word),
          ),
        );
      },
    );
  }

  Widget _buildFlashcardButton() {
    final allWords = _getCurrentLevelWords();
    
    return FutureBuilder<int>(
      key: ValueKey('flashcard_button_$_refreshKey'), // Force rebuild when refreshKey changes
      future: _getNonMasteredWordCount(allWords),
      builder: (context, snapshot) {
        final nonMasteredCount = snapshot.data ?? 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (nonMasteredCount == 0 || isLoading) ? null : _startFlashcard,
                icon: const Icon(Icons.style, size: 24),
                label: Text(
                  isLoading 
                    ? 'Đang tải...'
                    : nonMasteredCount == 0
                      ? 'Tất cả từ đã thuộc! 🎉'
                      : 'Bắt đầu Flashcard ($nonMasteredCount từ)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Count words that are not mastered (reviewCount < 5) for flashcard button
  Future<int> _getNonMasteredWordCount(List<Word> words) async {
    if (words.isEmpty) return 0;
    
    int count = 0;
    for (final word in words) {
      final progress = await _progressRepository.getWordProgress(word.topic, word.en);
      final reviewCount = progress['reviewCount'] ?? 0;
      if (reviewCount < 5) {
        count++;
      }
    }
    return count;
  }

  // ==================== WORD DETAIL DIALOG ====================
  
  void _showWordDetails(Word word) async {
    // Get progress data for this word
    final progress = await _progressRepository.getWordProgress(word.topic, word.en);
    final reviewCount = progress['reviewCount'] ?? 0;
    final correctAnswers = progress['correctAnswers'] ?? 0;
    final totalAttempts = progress['totalAttempts'] ?? 0;
    final isLearned = reviewCount >= 5; // Đã thuộc khi reviewCount >= 5
    final accuracy = totalAttempts > 0 ? (correctAnswers / totalAttempts * 100).toStringAsFixed(1) : '0.0';
    
    // Calculate progress level
    String progressLevel = reviewCount == 0 ? 'New' : 
                          !isLearned ? 'Learning' :
                          double.parse(accuracy) >= 80 ? 'Mastered' : 'Familiar';
    
    Color progressColor = reviewCount == 0 ? Colors.blue :
                         !isLearned ? Colors.orange :
                         double.parse(accuracy) >= 80 ? Colors.purple : Colors.green;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Colors.white,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with word and pronunciation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.en,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              if (word.pronunciation.isNotEmpty)
                                Text(
                                  '/${word.pronunciation}/',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              Text(
                                word.type.toString().split('.').last.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () => _speakEnglish(word.en),
                              icon: const Icon(Icons.volume_up),
                              color: Colors.blue,
                              iconSize: 24,
                              tooltip: 'Normal Speed',
                            ),
                            IconButton(
                              onPressed: () => _speakEnglishSlow(word.en),
                              icon: const Icon(Icons.slow_motion_video),
                              color: Colors.green,
                              iconSize: 24,
                              tooltip: 'Slow Speed',
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Vietnamese Translation
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(width: 4, color: Colors.blue)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vietnamese Meaning:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            word.vi,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Example Sentences
                    if (word.sentence.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(left: BorderSide(width: 4, color: Colors.green)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Example Sentence:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _speakEnglish(word.sentence),
                                  icon: const Icon(Icons.volume_up, size: 16),
                                  color: Colors.green,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              word.sentence,
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.black87,
                              ),
                            ),
                            if (word.sentenceVi.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                word.sentenceVi,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Progress status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: progressColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                progressLevel == 'New' ? Icons.fiber_new :
                                progressLevel == 'Learning' ? Icons.school :
                                progressLevel == 'Mastered' ? Icons.star :
                                Icons.thumb_up,
                                color: progressColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Status: $progressLevel',
                                style: TextStyle(
                                  color: progressColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStat('Reviews', reviewCount.toString()),
                              _buildQuickStat('Accuracy', '$accuracy%'),
                              _buildQuickStat('Level', word.difficulty.toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Actions - Row 1: Add to Quiz + Mark as Mastered
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _addWordToQuiz(word);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: _addedToQuizWords.contains(word.en) 
                                ? Colors.purple : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_addedToQuizWords.contains(word.en) 
                                  ? Icons.check : Icons.add_task, size: 18),
                                const SizedBox(width: 8),
                                Text(_addedToQuizWords.contains(word.en) 
                                  ? 'Added' : 'Add to Quiz'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: reviewCount >= 5 || _masteredWords.contains(word.en)
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  _markWordAsMastered(word);
                                },
                            style: TextButton.styleFrom(
                              backgroundColor: reviewCount >= 5 || _masteredWords.contains(word.en)
                                ? Colors.grey[300]
                                : Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  reviewCount >= 5 || _masteredWords.contains(word.en)
                                    ? Icons.check_circle 
                                    : Icons.task_alt,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  reviewCount >= 5 || _masteredWords.contains(word.en)
                                    ? 'Mastered'
                                    : 'Đã thuộc',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Actions - Row 2: Close
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _speakEnglish(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(text);
  }

  Future<void> _speakEnglishSlow(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.2); // Very slow speed
    await _flutterTts.speak(text);
  }

  Future<void> _addWordToQuiz(Word word) async {
    try {
      final quizRepository = QuizRepository();
      await quizRepository.addWordToQuiz(word);
      
      setState(() {
        _addedToQuizWords.add(word.en);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${word.en}" to quiz!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error adding word to quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add word to quiz'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markWordAsMastered(Word word) async {
    try {
      // Get current progress
      final currentProgress = await _progressRepository.getWordProgress(word.topic, word.en);
      
      // Update to mastered status (reviewCount = 5)
      currentProgress['reviewCount'] = 5;
      currentProgress['isLearned'] = true;
      currentProgress['lastReviewed'] = DateTime.now().toIso8601String();
      
      // Save updated progress
      await _progressRepository.saveWordProgress(word.topic, word.en, currentProgress);
      
      setState(() {
        _masteredWords.add(word.en);
      });
      
      // Reload statistics to update the learned count
      await _calculateLearnedCount();
      
      // Increment refresh key to force FutureBuilder rebuild
      setState(() {
        _refreshKey++;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Marked "${word.en}" as mastered!'),
            backgroundColor: Theme.of(context).primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking word as mastered: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark word as mastered'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

