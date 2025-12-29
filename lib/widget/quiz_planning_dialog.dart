import 'package:flutter/material.dart';
import '../model/word.dart';
import 'word_preview_card.dart';

class QuizPlanningDialog extends StatefulWidget {
  final List<Word> words;
  final String title;
  final Function(List<Word> selectedWords) onStartQuiz;

  const QuizPlanningDialog({
    Key? key,
    required this.words,
    required this.title,
    required this.onStartQuiz,
  }) : super(key: key);

  @override
  State<QuizPlanningDialog> createState() => _QuizPlanningDialogState();
}

class _QuizPlanningDialogState extends State<QuizPlanningDialog> {
  final Set<String> _removedWords = {}; // Track words removed from quiz by word key
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showWarning = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getWordKey(Word word) {
    return '${word.en}_${word.topic}';
  }

  bool _isRemoved(Word word) {
    return _removedWords.contains(_getWordKey(word));
  }

  void _removeWord(Word word) {
    setState(() {
      _removedWords.add(_getWordKey(word));
    });
  }

  List<Word> get _filteredWords {
    if (_searchQuery.isEmpty) {
      return widget.words;
    }
    return widget.words.where((word) {
      return word.en.toLowerCase().contains(_searchQuery) ||
          word.vi.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<Word> get _selectedWords {
    final availableWords = _filteredWords.where((word) {
      return !_isRemoved(word);
    }).toList();
    
    // Apply 20-word limit with smart selection
    if (availableWords.length <= 20) {
      return availableWords;
    }
    
    return _selectWordsForQuiz(availableWords, 20);
  }

  /// Smart selection algorithm: Priority 1 (New) → Priority 2 (Learning) → Priority 3 (Familiar)
  List<Word> _selectWordsForQuiz(List<Word> words, int limit) {
    // Priority 1: New words (reviewCount = 0)
    final newWords = words.where((w) => w.reviewCount == 0).toList();
    
    // Priority 2: Learning words (reviewCount 1-3)
    final learningWords = words.where((w) => w.reviewCount >= 1 && w.reviewCount < 4).toList();
    
    // Priority 3: Familiar words (reviewCount = 4)
    final familiarWords = words.where((w) => w.reviewCount == 4).toList();
    
    // Combine in priority order
    final selected = <Word>[];
    selected.addAll(newWords.take(limit));
    
    if (selected.length < limit) {
      final remaining = limit - selected.length;
      selected.addAll(learningWords.take(remaining));
    }
    
    if (selected.length < limit) {
      final remaining = limit - selected.length;
      selected.addAll(familiarWords.take(remaining));
    }
    
    // Shuffle for variety
    selected.shuffle();
    
    return selected;
  }

  int get _totalWords => widget.words.length;
  int get _selectedCount => _selectedWords.length;
  int get _removedCount => _removedWords.length;
  int get _availableCount {
    return _filteredWords.where((word) => !_isRemoved(word)).toList().length;
  }
  bool get _isAutoLimited => _availableCount > 20;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 700,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with compact stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.quiz,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Compact statistics in header
                            Row(
                              children: [
                                Text(
                                  '$_totalWords từ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sẽ quiz: $_selectedCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_removedCount > 0) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    'Đã xóa: $_removedCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Info icon for warning (if auto-limited)
                      if (_isAutoLimited)
                        IconButton(
                          icon: Icon(
                            _showWarning ? Icons.info : Icons.info_outline,
                            color: Colors.orange[200],
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _showWarning = !_showWarning;
                            });
                          },
                          tooltip: 'Thông tin giới hạn',
                        ),
                      // Search toggle button
                      IconButton(
                        icon: Icon(
                          _showSearch ? Icons.search_off : Icons.search,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchController.clear();
                            }
                          });
                        },
                        tooltip: 'Tìm kiếm',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),
                  // Warning message (collapsible)
                  if (_isAutoLimited && _showWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bạn đã chọn $_availableCount từ. Sẽ quiz 20 từ ưu tiên. Còn ${_availableCount - 20} từ sẽ quiz trong session tiếp theo.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Search bar (collapsible)
                  if (_showSearch)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm từ vựng...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(Icons.search, color: Colors.white, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Words list
            Expanded(
              child: _filteredWords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không tìm thấy từ vựng',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filteredWords.length,
                      itemBuilder: (context, index) {
                        final word = _filteredWords[index];
                        return WordPreviewCard(
                          word: word,
                          isRemoved: _isRemoved(word),
                          onRemove: () => _removeWord(word),
                        );
                      },
                    ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedCount == 0
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onStartQuiz(_selectedWords);
                            },
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text('Bắt đầu Quiz ($_selectedCount từ)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

