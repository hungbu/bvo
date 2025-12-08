import 'package:flutter/material.dart';
import '../../model/word.dart';
import '../../repository/dictionary_words_repository.dart';
import '../../repository/quiz_repository.dart';
import '../../service/audio_service.dart';
import '../../service/dialog_manager.dart';

class WordSearchDialog extends StatefulWidget {
  const WordSearchDialog({Key? key}) : super(key: key);

  @override
  State<WordSearchDialog> createState() => _WordSearchDialogState();
}

class _WordSearchDialogState extends State<WordSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryWordsRepository _repository = DictionaryWordsRepository();
  final AudioService _audioService = AudioService();
  
  List<Word> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // AudioService is singleton, no need to dispose
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchQuery = '';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _searchQuery = query;
      });
    }

    try {
      print('🔍 Searching for: "$query"');
      
      // Check database first
      final wordCount = await _repository.getWordCount();
      print('📊 Database word count: $wordCount');
      
      if (!mounted) return; // Widget disposed, exit early
      
      if (wordCount == 0) {
        print('⚠️ Database is empty!');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
        return;
      }
      
      final results = await _repository.searchWord(query);
      print('✅ Found ${results.length} results');
      
      if (!mounted) return; // Widget disposed, exit early
      
      if (results.isEmpty) {
        print('⚠️ No results found. Trying fuzzy search...');
        // Try fuzzy search as fallback
        final fuzzyResults = await _repository.fuzzySearch(query);
        print('🔍 Fuzzy search found ${fuzzyResults.length} results');
        
        if (mounted) {
          setState(() {
            _searchResults = fuzzyResults;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error searching: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _showWordDetail(Word word) async {
    final dialogManager = DialogManager();
    if (!dialogManager.canOpenWordDetailDialog()) {
      return; // Dialog is already open, ignore this request
    }

    await showDialog(
      context: context,
      builder: (context) => WordDetailDialog(word: word),
    );
    // Dialog closed, flag is reset in dispose()
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm từ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                _performSearch(value);
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // Results
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
                          child: Text(
                            'Không tìm thấy từ nào',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nhập từ để tìm kiếm',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final word = _searchResults[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      word.en,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (word.pronunciation.isNotEmpty)
                                          Text(
                                            '/${word.pronunciation}/',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          word.vi,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      onPressed: () async {
                                        await _audioService.speakNormal(word.en);
                                      },
                                    ),
                                    onTap: () {
                                      _showWordDetail(word);
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class WordDetailDialog extends StatefulWidget {
  final Word word;

  const WordDetailDialog({Key? key, required this.word}) : super(key: key);

  @override
  State<WordDetailDialog> createState() => _WordDetailDialogState();
}

class _WordDetailDialogState extends State<WordDetailDialog> {
  final AudioService _audioService = AudioService();
  final QuizRepository _quizRepository = QuizRepository();
  final DialogManager _dialogManager = DialogManager();
  bool _isInQuiz = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _dialogManager.setWordDetailDialogOpen(true);
    _checkIfInQuiz();
  }

  @override
  void dispose() {
    _dialogManager.setWordDetailDialogOpen(false);
    // AudioService is singleton, no need to dispose
    super.dispose();
  }

  Future<void> _speakNormal() async {
    await _audioService.speakNormal(widget.word.en);
  }

  Future<void> _speakSlowly() async {
    await _audioService.speakSlowly(widget.word.en);
  }

  Future<void> _checkIfInQuiz() async {
    try {
      final quizWords = await _quizRepository.getQuizWords();
      if (mounted) {
        setState(() {
          _isInQuiz = quizWords.any(
            (w) => w.en == widget.word.en && w.topic == widget.word.topic,
          );
          _isChecking = false;
        });
      }
    } catch (e) {
      print('Error checking quiz: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _addToQuiz() async {
    try {
      final success = await _quizRepository.addWordToQuiz(widget.word);
      if (success && mounted) {
        setState(() {
          _isInQuiz = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm từ vào quiz!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Từ này đã có trong quiz'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFromQuiz() async {
    try {
      final success = await _quizRepository.removeWordFromQuiz(widget.word);
      if (success && mounted) {
        setState(() {
          _isInQuiz = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa từ khỏi quiz'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with word and pronunciation
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.en,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (word.pronunciation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '/${word.pronunciation}/',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Audio controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 32),
                        tooltip: 'Phát âm bình thường',
                        onPressed: () async {
                          await _speakNormal();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.hearing, size: 32),
                        tooltip: 'Phát âm chậm',
                        onPressed: () async {
                          await _speakSlowly();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // Vietnamese meaning
              if (word.vi.isNotEmpty) ...[
                const Text(
                  'Nghĩa:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  word.vi,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
              ],
              
              // Example sentence
              if (word.sentence.isNotEmpty) ...[
                const Text(
                  'Ví dụ:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  word.sentence,
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (word.sentenceVi.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    word.sentenceVi,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              
              // Word info
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (word.type != WordType.noun)
                    Chip(
                      label: Text('${word.type.toString().split('.').last}'),
                      backgroundColor: Colors.blue[100],
                    ),
                  Chip(
                    label: Text('${word.level.toString().split('.').last}'),
                    backgroundColor: Colors.green[100],
                  ),
                  if (word.topic.isNotEmpty)
                    Chip(
                      label: Text(word.topic),
                      backgroundColor: Colors.orange[100],
                    ),
                ],
              ),
              
              // Synonyms
              if (word.synonyms.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Từ đồng nghĩa:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: word.synonyms.map((syn) => Chip(
                    label: Text(syn),
                    backgroundColor: Colors.purple[100],
                  )).toList(),
                ),
              ],
              
              // Mnemonic tip
              if (word.mnemonicTip != null && word.mnemonicTip!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.yellow[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          word.mnemonicTip!,
                          style: TextStyle(color: Colors.yellow[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Add to Quiz button
              if (_isChecking)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(_isInQuiz ? Icons.check_circle : Icons.add),
                    label: Text(_isInQuiz ? 'Đã có trong Quiz' : 'Thêm vào Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isInQuiz ? Colors.green : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isInQuiz ? _removeFromQuiz : _addToQuiz,
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

