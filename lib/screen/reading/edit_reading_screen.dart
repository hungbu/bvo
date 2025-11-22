import 'package:flutter/material.dart';
import '../../repository/reading_repository.dart';
import '../../model/practice_question.dart';
import '../../model/reading.dart';

class EditReadingScreen extends StatefulWidget {
  final Reading reading;

  const EditReadingScreen({
    Key? key,
    required this.reading,
  }) : super(key: key);

  @override
  State<EditReadingScreen> createState() => _EditReadingScreenState();
}

class _EditReadingScreenState extends State<EditReadingScreen> {
  final ReadingRepository _repository = ReadingRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  // List of questions
  final List<Map<String, dynamic>> _formQuestions = [];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.reading.title;
    _descriptionController.text = widget.reading.description ?? '';
    _loadQuestions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final questions = await _repository.loadQuestionsForReading(widget.reading.id);
      setState(() {
        // Convert PracticeQuestion to form format
        _formQuestions.clear();
        for (var q in questions) {
          _formQuestions.add({
            'type': q.type,
            'questionText': q.questionText,
            'correctAnswers': q.correctAnswers,
            'options': q.options,
            'blankPositions': q.blankPositions,
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải câu hỏi: $e')),
        );
      }
    }
  }

  // Convert form questions to PracticeQuestion list
  List<PracticeQuestion> _convertFormQuestionsToPracticeQuestions() {
    final List<PracticeQuestion> questions = [];
    for (int i = 0; i < _formQuestions.length; i++) {
      final q = _formQuestions[i];
      final questionId = '${widget.reading.id}_q$i';
      questions.add(PracticeQuestion(
        id: questionId,
        type: q['type'] as QuestionType,
        questionText: q['questionText'] as String,
        correctAnswers: q['correctAnswers'] as List<String>,
        options: q['options'] as List<String>,
        blankPositions: q['blankPositions'] as List<int>?,
      ));
    }
    return questions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa Reading'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveReading,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi'),
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

  Future<void> _saveReading() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề bài reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Update metadata
      await _repository.updateReadingMetadata(
        widget.reading.id,
        _titleController.text.trim(),
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      // Convert and update questions
      final questions = _convertFormQuestionsToPracticeQuestions();
      await _repository.updateReadingQuestions(widget.reading.id, questions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu thay đổi thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

