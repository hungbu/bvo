import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _loadedFileName;

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
    try {
      // Show file picker to select txt files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        dialogTitle: 'Chọn file txt để import',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        
        if (await file.exists()) {
          final content = await file.readAsString();
          setState(() {
            _contentController.text = content;
            _loadedFileName = result.files.single.name;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã tải file: ${result.files.single.name}'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File không tồn tại')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải file: $e')),
        );
      }
    }
  }

  String? _validateFileContent(String content) {
    if (content.trim().isEmpty) {
      return 'Nội dung file không được để trống';
    }

    // Check if content has at least one question format [q]
    if (!content.contains('[q]')) {
      return 'File không chứa câu hỏi nào. Vui lòng kiểm tra format [q]';
    }

    // Check if content has at least one answer format [a]
    if (!content.contains('[a]')) {
      return 'File không chứa đáp án nào. Vui lòng kiểm tra format [a]';
    }

    // Try to parse questions to validate format
    final tempReadingId = 'temp_validation';
    final questions = _repository.parseQuestionsFromText(content, tempReadingId);
    
    if (questions.isEmpty) {
      return 'Không thể parse câu hỏi từ file. Vui lòng kiểm tra lại format theo hướng dẫn bên dưới';
    }

    return null; // No error
  }

  Future<void> _importReading() async {
    // Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề bài reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate content
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung bài reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate file content format
    final validationError = _validateFileContent(content);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      await _repository.importReadingFromText(
        title: _titleController.text.trim(),
        content: content,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import bài reading thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi import: $e'),
            backgroundColor: Colors.red,
          ),
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
                  
                  // Show loaded file name
                  if (_loadedFileName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'File đã tải: $_loadedFileName',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Content input
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung bài reading *',
                      hintText: 'Paste nội dung bài reading theo format ở dưới',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 15,
                  ),
                  const SizedBox(height: 24),
                  
                  // Import button - only show if file is loaded
                  if (_loadedFileName != null) ...[
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
                    const SizedBox(height: 24),
                  ],
                  
                  // Question formats section - moved to bottom
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Các Format Câu Hỏi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  ..._questionFormats.map((format) => _buildFormatCard(format)),
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

