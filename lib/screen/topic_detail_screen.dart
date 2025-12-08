import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/repository/word_repository.dart';
import 'package:bvo/repository/quiz_repository.dart';
import 'package:bvo/repository/user_progress_repository.dart';
import 'package:bvo/screen/new_pair_flashcard_screen.dart';
import 'package:bvo/main.dart';
import 'package:bvo/repository/topic_repository.dart';
import 'package:bvo/service/audio_service.dart';

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
  bool hasProgressChanged = false; // Track if progress changed
  final AudioService _audioService = AudioService();
  Set<String> _addedToQuizWords = {}; // Track words added to quiz
  String _topicTitle = '';

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
    // AudioService is singleton, no need to dispose
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

    // Resolve topic display name from repository
    try {
      final topic = await TopicRepository().getTopicById(widget.topic);
      _topicTitle = topic?.name ?? widget.topic;
    } catch (_) {
      _topicTitle = widget.topic;
    }
    
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
    return WillPopScope(
      onWillPop: () async {
        // Return result if progress has changed to trigger TopicScreen refresh
        if (hasProgressChanged) {
          Navigator.pop(context, 'progress_updated');
        } else {
          Navigator.pop(context);
        }
        return false; // Prevent default pop behavior
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_topicTitle.isEmpty ? widget.topic : _topicTitle),
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
        
        if (reviewCount == 0) {
          newWords++;
        } else if (reviewCount >= 10) {
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
                    builder: (context) => NewPairFlashcardScreen(
                      topic: widget.topic,
                    ),
                  ),
                );
                
                // Refresh data when returning from FlashCard
                if (result != null || mounted) {
                  await _refreshProgressData();
                  hasProgressChanged = true; // Mark that progress has changed
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
              label: const Text('Add all to Quiz'),
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
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _showWordDetails(word);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    
                    const SizedBox(height: 2),
                    
                    // English word with speaker button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            word.en,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
// Right side - Add to Quiz button (icon only)
              IconButton(
                onPressed: () => _addWordToQuiz(word),
                icon: const Icon(Icons.add_task),
                color: _addedToQuizWords.contains(word.en) ? Colors.white : Colors.green,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _addedToQuizWords.contains(word.en) 
                    ? Colors.purple 
                    : Colors.green.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _speakEnglish(word.en),
                          icon: const Icon(Icons.volume_up, size: 20),
                          color: Colors.blue,
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Vietnamese translation
                    Text(
                      word.vi,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 2),
                    
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
    final isLearned = progress?['isLearned'] ?? false;
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Level ${word.topic}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.purple[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                    
                    // Synonyms & Antonyms
                    if (word.synonyms.isNotEmpty || word.antonyms.isNotEmpty) ...[
                      Row(
                        children: [
                          if (word.synonyms.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Synonyms:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      word.synonyms.join(', '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (word.synonyms.isNotEmpty && word.antonyms.isNotEmpty)
                            const SizedBox(width: 8),
                          if (word.antonyms.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Antonyms:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      word.antonyms.join(', '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Memory aids
                    if (word.mnemonicTip?.isNotEmpty == true || word.culturalNote?.isNotEmpty == true) ...[
                      if (word.mnemonicTip?.isNotEmpty == true)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(left: BorderSide(width: 4, color: Colors.purple)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, 
                                       size: 16, color: Colors.purple[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Memory Tip:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                word.mnemonicTip!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (word.culturalNote?.isNotEmpty == true)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(left: BorderSide(width: 4, color: Colors.amber)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, 
                                       size: 16, color: Colors.amber[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cultural Note:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                word.culturalNote!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
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
                    
                    // Actions
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

  Future<void> _speakEnglish(String word) async {
    await _audioService.speakNormal(word);
  }

  Future<void> _speakEnglishSlow(String word) async {
    await _audioService.speak(text: word, speechRate: 0.2);
  }

  void _addWordToQuiz(Word word) async {
    try {
      final success = await QuizRepository().addWordToQuiz(word);
      
      if (success) {
        setState(() {
          _addedToQuizWords.add(word.en);
        });
      }
    } catch (e) {
      // Handle error silently or show minimal feedback
      print('Error adding word to quiz: $e');
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