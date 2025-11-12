import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../repository/reading_repository.dart';

class ImportReadingScreen extends StatefulWidget {
  const ImportReadingScreen({Key? key}) : super(key: key);

  @override
  State<ImportReadingScreen> createState() => _ImportReadingScreenState();
}

class _ImportReadingScreenState extends State<ImportReadingScreen> {
  final ReadingRepository _repository = ReadingRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isImporting = false;

  // 4 format câu hỏi
  final List<Map<String, String>> _questionFormats = [
    {
      'title': '1. Fill to sentence',
      'description': 'Điền từ vào chỗ trống trong câu',
      'format': '[q] sentence (1) content, sentence (2) ...\n[a][right-answer][item1, item2, ...]',
    },
    {
      'title': '2. Choose 1 right answer',
      'description': 'Chọn 1 đáp án đúng',
      'format': '[q] question text\n[a][right-answer][item1, item2, ...]',
    },
    {
      'title': '3. Choose multiple right answers',
      'description': 'Chọn nhiều đáp án đúng',
      'format': '[q] question text\n[a][answer1,answer2][item1, item2, ...]',
    },
    {
      'title': '4. Answer text',
      'description': 'Trả lời bằng văn bản',
      'format': '[q] question text\n[a][right-answer][(texteditor)]',
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFromFile() async {
    final TextEditingController pathController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load from File'),
        content: TextField(
          controller: pathController,
          decoration: const InputDecoration(
            hintText: 'Enter file path or paste content',
            labelText: 'File Path',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, pathController.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        final file = File(result);
        if (await file.exists()) {
          final content = await file.readAsString();
          _contentController.text = content;
        } else {
          // Treat as text content directly
          _contentController.text = result;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading file: $e')),
          );
        }
      }
    }
  }

  Future<void> _importReading() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề bài reading')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung bài reading')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      await _repository.importReadingFromText(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import bài reading thành công!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi import: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Reading'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isImporting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title input
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề bài reading *',
                      hintText: 'Nhập tiêu đề',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description input
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả (tùy chọn)',
                      hintText: 'Nhập mô tả',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  
                  // Question formats section
                  const Text(
                    'Các Format Câu Hỏi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  ..._questionFormats.map((format) => _buildFormatCard(format)),
                  
                  const SizedBox(height: 24),
                  
                  // Load from file button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadFromFile,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Load from File'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Content input
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung bài reading *',
                      hintText: 'Paste nội dung bài reading theo format ở trên',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 15,
                  ),
                  const SizedBox(height: 24),
                  
                  // Import button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _importReading,
                      icon: const Icon(Icons.add),
                      label: const Text('Import Reading'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFormatCard(Map<String, String> format) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        format['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        format['description']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy format',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: format['format']!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã copy format!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                format['format']!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

