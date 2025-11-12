import 'package:flutter/material.dart';
import '../../model/reading.dart';
import '../../repository/reading_repository.dart';
import 'practice_screen.dart';
import 'import_reading_screen.dart';

class ReadingListScreen extends StatefulWidget {
  const ReadingListScreen({Key? key}) : super(key: key);

  @override
  State<ReadingListScreen> createState() => _ReadingListScreenState();
}

class _ReadingListScreenState extends State<ReadingListScreen> {
  final ReadingRepository _repository = ReadingRepository();
  List<Reading> _readings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final readings = await _repository.loadAllReadings();
      setState(() {
        _readings = readings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách bài reading: $e')),
        );
      }
    }
  }

  Future<void> _deleteReading(Reading reading) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài reading'),
        content: Text('Bạn có chắc muốn xóa "${reading.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteReading(reading.id);
      await _loadReadings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài reading')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Practice'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Reading',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportReadingScreen(),
                ),
              );
              if (result == true) {
                await _loadReadings();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _readings.isEmpty
              ? _buildEmptyState()
              : _buildReadingList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có bài reading nào',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút Import để thêm bài reading',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingList() {
    return RefreshIndicator(
      onRefresh: _loadReadings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _readings.length,
        itemBuilder: (context, index) {
          final reading = _readings[index];
          return _buildReadingItem(reading);
        },
      ),
    );
  }

  Widget _buildReadingItem(Reading reading) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PracticeScreen(readingId: reading.id),
            ),
          ).then((_) => _loadReadings());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (reading.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        reading.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.quiz,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${reading.questionCount} câu hỏi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getSourceColor(reading.source).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getSourceLabel(reading.source),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getSourceColor(reading.source),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteReading(reading);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'api':
        return Colors.blue;
      case 'assets':
        return Colors.green;
      case 'import':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'api':
        return 'API';
      case 'assets':
        return 'Assets';
      case 'import':
        return 'Import';
      default:
        return source;
    }
  }
}

