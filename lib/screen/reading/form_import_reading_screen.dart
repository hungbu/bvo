import 'package:flutter/material.dart';
import '../../repository/reading_repository.dart';
import '../../model/practice_question.dart';

class FormImportReadingScreen extends StatefulWidget {
  const FormImportReadingScreen({Key? key}) : super(key: key);

  @override
  State<FormImportReadingScreen> createState() => _FormImportReadingScreenState();
}

class _FormImportReadingScreenState extends State<FormImportReadingScreen> {
  final ReadingRepository _repository = ReadingRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isImporting = false;

  // List of questions being built via form
  final List<Map<String, dynamic>> _formQuestions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Convert form questions to text format
  String _convertFormQuestionsToText() {
    final buffer = StringBuffer();
    for (var q in _formQuestions) {
      final type = q['type'] as QuestionType;
      final questionText = q['questionText'] as String;
      final correctAnswers = q['correctAnswers'] as List<String>;
      final options = q['options'] as List<String>;

      buffer.writeln('[q] $questionText');
      
      if (type == QuestionType.answerText) {
        buffer.writeln('[a][${correctAnswers.join(',')}][(texteditor)]');
      } else if (type == QuestionType.fillToSentence) {
        buffer.writeln('[a][${correctAnswers.join(',')}][${options.join(', ')}]');
      } else if (type == QuestionType.chooseMulti) {
        buffer.writeln('[a][${correctAnswers.join(',')}][${options.join(', ')}]');
      } else {
        buffer.writeln('[a][${correctAnswers.first}][${options.join(', ')}]');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập Reading bằng Form'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isImporting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Title and description inputs
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề bài reading *',
                          hintText: 'Nhập tiêu đề',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả (tùy chọn)',
                          hintText: 'Nhập mô tả',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _formQuestions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _formQuestions.length) {
                        return _buildAddQuestionButton();
                      }
                      return _buildQuestionCard(index);
                    },
                  ),
                ),
                if (_formQuestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _importFromForm,
                        icon: const Icon(Icons.save),
                        label: const Text('Import Reading'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAddQuestionButton() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showAddQuestionDialog(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add_circle_outline, size: 32),
              SizedBox(width: 12),
              Text(
                'Thêm câu hỏi mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _formQuestions[index];
    final type = question['type'] as QuestionType;
    final questionText = question['questionText'] as String;
    
    String typeName = '';
    switch (type) {
      case QuestionType.fillToSentence:
        typeName = 'Điền từ vào chỗ trống';
        break;
      case QuestionType.chooseOne:
        typeName = 'Chọn 1 đáp án đúng';
        break;
      case QuestionType.chooseMulti:
        typeName = 'Chọn nhiều đáp án đúng';
        break;
      case QuestionType.answerText:
        typeName = 'Trả lời bằng văn bản';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu hỏi ${index + 1}: $typeName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        questionText,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditQuestionDialog(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _formQuestions.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    _showQuestionDialog(null);
  }

  void _showEditQuestionDialog(int index) {
    _showQuestionDialog(index);
  }

  void _showQuestionDialog(int? index) {
    final isEditing = index != null;
    final questionIndex = index;
    final existingQuestion = isEditing && questionIndex != null ? _formQuestions[questionIndex] : null;

    QuestionType selectedType = existingQuestion?['type'] ?? QuestionType.chooseOne;
    final questionTextController = TextEditingController(
      text: existingQuestion?['questionText'] ?? '',
    );
    final correctAnswerController = TextEditingController(
      text: existingQuestion?['correctAnswers']?.join(', ') ?? '',
    );
    final optionsController = TextEditingController(
      text: existingQuestion?['options']?.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Sửa câu hỏi' : 'Thêm câu hỏi mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question type selector
                const Text('Loại câu hỏi:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<QuestionType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: QuestionType.values.map((type) {
                    String label = '';
                    switch (type) {
                      case QuestionType.fillToSentence:
                        label = '1. Điền từ vào chỗ trống';
                        break;
                      case QuestionType.chooseOne:
                        label = '2. Chọn 1 đáp án đúng';
                        break;
                      case QuestionType.chooseMulti:
                        label = '3. Chọn nhiều đáp án đúng';
                        break;
                      case QuestionType.answerText:
                        label = '4. Trả lời bằng văn bản';
                        break;
                    }
                    return DropdownMenuItem(value: type, child: Text(label));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Question text
                TextField(
                  controller: questionTextController,
                  decoration: InputDecoration(
                    labelText: selectedType == QuestionType.fillToSentence
                        ? 'Câu văn (dùng (1), (2)... để đánh dấu chỗ trống)'
                        : 'Nội dung câu hỏi',
                    hintText: selectedType == QuestionType.fillToSentence
                        ? 'Ví dụ: This is (1) example (2) sentence.'
                        : 'Nhập câu hỏi',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Correct answer(s)
                TextField(
                  controller: correctAnswerController,
                  decoration: InputDecoration(
                    labelText: selectedType == QuestionType.chooseMulti
                        ? 'Đáp án đúng (phân cách bằng dấu phẩy)'
                        : 'Đáp án đúng',
                    hintText: selectedType == QuestionType.chooseMulti
                        ? 'Ví dụ: answer1, answer2'
                        : 'Nhập đáp án đúng',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Options (not for answerText type)
                if (selectedType != QuestionType.answerText) ...[
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Các lựa chọn (phân cách bằng dấu phẩy)',
                      hintText: 'Ví dụ: option1, option2, option3',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Info for fillToSentence
                if (selectedType == QuestionType.fillToSentence) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vị trí chỗ trống sẽ được tự động phát hiện từ (1), (2)... trong câu văn',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final questionText = questionTextController.text.trim();
                final correctAnswers = correctAnswerController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final options = optionsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                if (questionText.isEmpty || correctAnswers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
                  );
                  return;
                }

                if (selectedType != QuestionType.answerText && options.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập các lựa chọn')),
                  );
                  return;
                }

                // Auto-detect blank positions for fillToSentence
                List<int>? blankPositions;
                if (selectedType == QuestionType.fillToSentence) {
                  final matches = RegExp(r'\((\d+)\)').allMatches(questionText);
                  blankPositions = matches.map((m) => int.parse(m.group(1)!)).toList();
                  
                  if (blankPositions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng đánh dấu chỗ trống bằng (1), (2)... trong câu văn')),
                    );
                    return;
                  }
                }

                final questionData = {
                  'type': selectedType,
                  'questionText': questionText,
                  'correctAnswers': correctAnswers,
                  'options': options,
                  'blankPositions': blankPositions,
                };

                setState(() {
                  if (isEditing && questionIndex != null) {
                    _formQuestions[questionIndex] = questionData;
                  } else {
                    _formQuestions.add(questionData);
                  }
                });

                Navigator.pop(context);
              },
              child: Text(isEditing ? 'Lưu' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromForm() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề bài reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất một câu hỏi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Convert form questions to text format
    final content = _convertFormQuestionsToText();
    
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
}

