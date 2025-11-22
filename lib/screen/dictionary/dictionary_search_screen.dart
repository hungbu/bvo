import 'package:flutter/material.dart';
import '../../repository/dictionary_repository.dart';
import '../../model/dictionary_entry.dart';

class DictionarySearchScreen extends StatefulWidget {
  const DictionarySearchScreen({Key? key}) : super(key: key);

  @override
  State<DictionarySearchScreen> createState() => _DictionarySearchScreenState();
}

class _DictionarySearchScreenState extends State<DictionarySearchScreen> {
  final DictionaryRepository _repository = DictionaryRepository();
  final TextEditingController _searchController = TextEditingController();
  List<DictionaryEntry> _results = [];
  bool _isSearching = false;
  DictionaryEntry? _selectedEntry;
  int? _wordCount;

  @override
  void initState() {
    super.initState();
    _loadWordCount();
  }

  Future<void> _loadWordCount() async {
    try {
      final count = await _repository.getWordCount();
      setState(() {
        _wordCount = count;
      });
    } catch (e) {
      print('Error loading word count: $e');
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _selectedEntry = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _repository.searchWord(query);
      setState(() {
        _results = results;
        _selectedEntry = results.isNotEmpty ? results.first : null;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tìm kiếm: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ Điển'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Nhập từ cần tra...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    _search(value);
                  },
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                ),
                if (_wordCount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tổng số từ: $_wordCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _selectedEntry == null && _results.isEmpty
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
                              'Nhập từ để tra cứu',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Row(
      children: [
        // Word list
        Container(
          width: 250,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final entry = _results[index];
              final isSelected = _selectedEntry?.word == entry.word;
              
              return ListTile(
                title: Text(
                  entry.word,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                onTap: () {
                  setState(() {
                    _selectedEntry = entry;
                  });
                },
              );
            },
          ),
        ),

        // Word detail
        Expanded(
          child: _selectedEntry == null
              ? const Center(child: Text('Chọn một từ để xem chi tiết'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Word title
                      Text(
                        _selectedEntry!.word,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Pronunciation
                      if (_selectedEntry!.pronunciation != null) ...[
                        Text(
                          '/${_selectedEntry!.pronunciation}/',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Detail
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedEntry!.cleanDetail,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

