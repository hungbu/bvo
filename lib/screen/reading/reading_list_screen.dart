import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../model/reading.dart';
import '../../repository/reading_repository.dart';
import 'practice_screen.dart';
import 'import_reading_screen.dart';
import 'form_import_reading_screen.dart';
import 'edit_reading_screen.dart';
import 'listen_reading_dialog.dart';
import '../../widget/quiz_planning_dialog.dart';
import '../../repository/reading_quiz_repository.dart';
import '../quiz_game_screen.dart';

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

  Future<void> _listenReading(Reading reading) async {
    try {
      // Load questions for the reading
      final questions = await _repository.loadQuestionsForReading(reading.id);
      
      if (questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không có câu hỏi nào trong bài reading này'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show listen dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ListenReadingDialog(
            questions: questions,
            readingId: reading.id,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải câu hỏi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startReadingQuiz(Reading reading) async {
    try {
      // Load words from ReadingQuizRepository
      final quizRepository = ReadingQuizRepository();
      var words = await quizRepository.getReadingQuizWords(reading.id);
      
      // Nếu chưa có từ nào, tự động khởi tạo từ question 1
      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang tải từ vựng từ câu hỏi số 1...'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        
        final addedCount = await quizRepository.initializeFromQuestion1(reading.id);
        
        if (addedCount > 0) {
          // Reload words sau khi đã thêm
          words = await quizRepository.getReadingQuizWords(reading.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã thêm $addedCount từ vựng từ câu hỏi số 1 vào quiz'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không tìm thấy từ vựng trong câu hỏi số 1'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Get due words (words that need review)
      final dueWords = await quizRepository.getReadingDueWords(reading.id);
      final wordsToShow = dueWords.isNotEmpty ? dueWords : words;

      // Show quiz planning dialog directly
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => QuizPlanningDialog(
            words: wordsToShow,
            title: 'Quiz: ${reading.title}',
            onStartQuiz: (selectedWords) {
              if (selectedWords.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng chọn ít nhất một từ để quiz!'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizGameScreen(
                    words: selectedWords,
                    title: 'Quiz: ${reading.title}',
                    onWordProgressUpdate: (word, isCorrect) async {
                      await quizRepository.updateReadingWordProgress(
                        reading.id,
                        word,
                        isCorrect,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải quiz: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadReading(Reading reading) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải file...')),
        );
      }

      // Get download directory
      Directory? downloadDir;
      if (Platform.isAndroid) {
        // For Android, use external storage downloads
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          // Fallback to app documents directory
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isWindows) {
        // For Windows, use Downloads folder
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadDir = Directory(path.join(userProfile, 'Downloads'));
          if (!await downloadDir.exists()) {
            downloadDir = await getApplicationDocumentsDirectory();
          }
        } else {
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } else {
        // For iOS/Mac, use documents directory
        downloadDir = await getApplicationDocumentsDirectory();
      }

      // Sanitize filename
      final sanitizedTitle = reading.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();

      final fileName = '${sanitizedTitle}.txt';
      final filePath = path.join(downloadDir.path, fileName);

      // Get content and save
      final content = await _repository.getReadingContentText(reading.id);
      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tải file thành công!\n$filePath'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải file: $e'),
            backgroundColor: Colors.red,
          ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Reading',
            onSelected: (value) async {
              Widget? screen;
              if (value == 'form') {
                screen = const FormImportReadingScreen();
              } else if (value == 'text') {
                screen = const ImportReadingScreen();
              }
              
              if (screen != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => screen!),
                );
                if (result == true) {
                  await _loadReadings();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'form',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Nhập bằng Form'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'text',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 20),
                    SizedBox(width: 8),
                    Text('Nhập bằng Text'),
                  ],
                ),
              ),
            ],
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'listen',
                    child: Row(
                      children: [
                        Icon(Icons.headphones, size: 20),
                        SizedBox(width: 8),
                        Text('Nghe'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'quiz',
                    child: Row(
                      children: [
                        Icon(Icons.quiz, size: 20),
                        SizedBox(width: 8),
                        Text('Quiz'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Download'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'listen') {
                    await _listenReading(reading);
                  } else if (value == 'edit') {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditReadingScreen(reading: reading),
                      ),
                    );
                    if (result == true) {
                      await _loadReadings();
                    }
                  } else if (value == 'quiz') {
                    _startReadingQuiz(reading);
                  } else if (value == 'download') {
                    await _downloadReading(reading);
                  } else if (value == 'delete') {
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

