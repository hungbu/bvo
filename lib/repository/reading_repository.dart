import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../model/reading.dart';
import '../model/practice_question.dart';

class ReadingRepository {
  static const String _readingsKey = 'readings_list';
  static const String _readingQuestionsKey = 'reading_questions_';
  
  /// Load all readings
  Future<List<Reading>> loadAllReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final readingsJson = prefs.getString(_readingsKey);
    
    if (readingsJson == null) {
      // Load from assets if no saved readings
      return await _loadReadingsFromAssets();
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(readingsJson);
      final List<Reading> readings = decoded.map((json) => Reading.fromJson(json)).toList();
      
      // Also load from assets and merge
      final assetsReadings = await _loadReadingsFromAssets();
      final existingIds = readings.map((r) => r.id).toSet();
      final newAssetsReadings = assetsReadings.where((r) => !existingIds.contains(r.id)).toList();
      
      if (newAssetsReadings.isNotEmpty) {
        final allReadings = [...readings, ...newAssetsReadings];
        await saveAllReadings(allReadings);
        return allReadings;
      }
      
      return readings;
    } catch (e) {
      print('Error loading readings: $e');
      return await _loadReadingsFromAssets();
    }
  }
  
  /// Save all readings
  Future<void> saveAllReadings(List<Reading> readings) async {
    final prefs = await SharedPreferences.getInstance();
    final readingsJson = readings.map((r) => r.toJson()).toList();
    await prefs.setString(_readingsKey, jsonEncode(readingsJson));
  }
  
  /// Add a new reading
  Future<void> addReading(Reading reading) async {
    final readings = await loadAllReadings();
    readings.add(reading);
    await saveAllReadings(readings);
  }
  
  /// Update a reading
  Future<void> updateReading(Reading reading) async {
    final readings = await loadAllReadings();
    final index = readings.indexWhere((r) => r.id == reading.id);
    if (index != -1) {
      readings[index] = reading.copyWith(updatedAt: DateTime.now());
      await saveAllReadings(readings);
    }
  }
  
  /// Delete a reading
  Future<void> deleteReading(String readingId) async {
    final readings = await loadAllReadings();
    readings.removeWhere((r) => r.id == readingId);
    await saveAllReadings(readings);
    
    // Also delete questions for this reading
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_readingQuestionsKey$readingId');
  }
  
  /// Load readings from assets
  Future<List<Reading>> _loadReadingsFromAssets() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);
      
      final readingFiles = manifestMap.keys
          .where((key) => key.startsWith('assets/data/reading/') && key.endsWith('.txt'))
          .toList();
      
      final List<Reading> readings = [];
      for (final filePath in readingFiles) {
        try {
          final fileName = filePath.split('/').last.replaceAll('.txt', '');
          final reading = Reading(
            id: 'assets_$fileName',
            title: fileName.replaceAll('_', ' ').split(' ').map((w) => 
              w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)
            ).join(' '),
            source: 'assets',
            filePath: filePath,
            createdAt: DateTime.now(),
            questionCount: await _countQuestionsInFile(filePath),
          );
          readings.add(reading);
        } catch (e) {
          print('Error loading reading from $filePath: $e');
        }
      }
      
      return readings;
    } catch (e) {
      print('Error loading readings from assets: $e');
      return [];
    }
  }
  
  /// Count questions in a file
  Future<int> _countQuestionsInFile(String filePath) async {
    try {
      final content = await rootBundle.loadString(filePath);
      final questionMatches = RegExp(r'\[q\]').allMatches(content);
      return questionMatches.length;
    } catch (e) {
      return 0;
    }
  }
  
  /// Load questions for a reading
  Future<List<PracticeQuestion>> loadQuestionsForReading(String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    final questionsJson = prefs.getString('$_readingQuestionsKey$readingId');
    
    if (questionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(questionsJson);
        return decoded.map((json) => PracticeQuestion.fromJson(json)).toList();
      } catch (e) {
        print('Error loading questions for reading $readingId: $e');
      }
    }
    
    // Try to load from reading source
    final readings = await loadAllReadings();
    final reading = readings.firstWhere((r) => r.id == readingId, orElse: () => Reading(
      id: '',
      title: '',
      source: '',
      createdAt: DateTime.now(),
    ));
    
    if (reading.source == 'assets' && reading.filePath != null) {
      return await _loadQuestionsFromAssets(reading.filePath!, readingId);
    } else if (reading.source == 'import' && reading.filePath != null) {
      return await _loadQuestionsFromFile(reading.filePath!, readingId);
    } else if (reading.source == 'api' && reading.apiUrl != null) {
      return await _loadQuestionsFromApi(reading.apiUrl!, readingId);
    }
    
    return [];
  }
  
  /// Load questions from assets
  Future<List<PracticeQuestion>> _loadQuestionsFromAssets(String filePath, String readingId) async {
    try {
      final content = await rootBundle.loadString(filePath);
      return _parseQuestionsFromText(content, readingId);
    } catch (e) {
      print('Error loading questions from assets $filePath: $e');
      return [];
    }
  }
  
  /// Load questions from file
  Future<List<PracticeQuestion>> _loadQuestionsFromFile(String filePath, String readingId) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final questions = _parseQuestionsFromText(content, readingId);
        // Save to SharedPreferences for faster access
        await _saveQuestionsForReading(readingId, questions);
        return questions;
      }
    } catch (e) {
      print('Error loading questions from file $filePath: $e');
    }
    return [];
  }
  
  /// Load questions from API
  Future<List<PracticeQuestion>> _loadQuestionsFromApi(String apiUrl, String readingId) async {
    try {
      // TODO: Implement API call
      // For now, return empty list
      print('API loading not implemented yet for $apiUrl');
      return [];
    } catch (e) {
      print('Error loading questions from API $apiUrl: $e');
      return [];
    }
  }
  
  /// Parse questions from text content (public method for validation)
  List<PracticeQuestion> parseQuestionsFromText(String content, String readingId) {
    return _parseQuestionsFromText(content, readingId);
  }

  /// Parse questions from text content
  List<PracticeQuestion> _parseQuestionsFromText(String content, String readingId) {
    final List<PracticeQuestion> questions = [];
    final lines = content.split('\n');
    
    String currentQuestion = '';
    int questionIndex = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.startsWith('[q]')) {
        // If we have a previous question, parse it
        if (currentQuestion.isNotEmpty) {
          final questionId = '${readingId}_q${questionIndex}';
          final question = PracticeQuestion.parseFromText(currentQuestion, questionId);
          if (question != null) {
            questions.add(question);
            questionIndex++;
          }
        }
        currentQuestion = line;
      } else if (line.startsWith('[a]')) {
        currentQuestion += '\n' + line;
      } else if (currentQuestion.isNotEmpty && line.isNotEmpty) {
        currentQuestion += '\n' + line;
      }
    }
    
    // Don't forget the last question
    if (currentQuestion.isNotEmpty) {
      final questionId = '${readingId}_q${questionIndex}';
      final question = PracticeQuestion.parseFromText(currentQuestion, questionId);
      if (question != null) {
        questions.add(question);
      }
    }
    
    return questions;
  }
  
  /// Save questions for a reading
  Future<void> _saveQuestionsForReading(String readingId, List<PracticeQuestion> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final questionsJson = questions.map((q) => q.toJson()).toList();
    await prefs.setString('$_readingQuestionsKey$readingId', jsonEncode(questionsJson));
    
    // Update question count in reading
    final readings = await loadAllReadings();
    final readingIndex = readings.indexWhere((r) => r.id == readingId);
    if (readingIndex != -1) {
      readings[readingIndex] = readings[readingIndex].copyWith(
        questionCount: questions.length,
        updatedAt: DateTime.now(),
      );
      await saveAllReadings(readings);
    }
  }
  
  /// Save reading content to file
  Future<String> _saveReadingToFile(String title, String content) async {
    try {
      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      
      // Create assets/data/reading directory structure
      final readingDir = Directory(path.join(directory.path, 'assets', 'data', 'reading'));
      if (!await readingDir.exists()) {
        await readingDir.create(recursive: true);
      }
      
      // Generate filename from title (sanitize for filesystem)
      final sanitizedTitle = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
          .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
          .replaceAll(RegExp(r'_+'), '_') // Replace multiple underscores with single
          .trim();
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${sanitizedTitle}_$timestamp.txt';
      final filePath = path.join(readingDir.path, fileName);
      
      // Write content to file
      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);
      
      // Return the file path (relative to documents directory for storage)
      return filePath;
    } catch (e) {
      print('Error saving reading to file: $e');
      rethrow;
    }
  }
  
  /// Import reading from text content
  Future<Reading> importReadingFromText({
    required String title,
    required String content,
    String? description,
  }) async {
    final readingId = 'import_${DateTime.now().millisecondsSinceEpoch}';
    final questions = _parseQuestionsFromText(content, readingId);
    
    // Save content to file
    String? filePath;
    try {
      filePath = await _saveReadingToFile(title, content);
    } catch (e) {
      print('Warning: Could not save reading to file: $e');
      // Continue without file path - reading will still be saved in SharedPreferences
    }
    
    // Save questions
    final prefs = await SharedPreferences.getInstance();
    final questionsJson = questions.map((q) => q.toJson()).toList();
    await prefs.setString('$_readingQuestionsKey$readingId', jsonEncode(questionsJson));
    
    // Create and save reading
    final reading = Reading(
      id: readingId,
      title: title,
      description: description,
      source: 'import',
      filePath: filePath, // Set file path if saved successfully
      createdAt: DateTime.now(),
      questionCount: questions.length,
    );
    
    await addReading(reading);
    return reading;
  }

  /// Export questions to text format
  String exportQuestionsToText(List<PracticeQuestion> questions) {
    final buffer = StringBuffer();
    for (var question in questions) {
      buffer.writeln('[q] ${question.questionText}');
      
      if (question.type == QuestionType.answerText) {
        buffer.writeln('[a][${question.correctAnswers.join(',')}][(texteditor)]');
      } else if (question.type == QuestionType.fillToSentence) {
        buffer.writeln('[a][${question.correctAnswers.join(',')}][${question.options.join(', ')}]');
      } else if (question.type == QuestionType.chooseMulti) {
        buffer.writeln('[a][${question.correctAnswers.join(',')}][${question.options.join(', ')}]');
      } else {
        buffer.writeln('[a][${question.correctAnswers.first}][${question.options.join(', ')}]');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Get reading content in text format
  Future<String> getReadingContentText(String readingId) async {
    final questions = await loadQuestionsForReading(readingId);
    return exportQuestionsToText(questions);
  }

  /// Download reading to file
  Future<String> downloadReading(String readingId, String title) async {
    try {
      final content = await getReadingContentText(readingId);
      final filePath = await _saveReadingToFile(title, content);
      return filePath;
    } catch (e) {
      print('Error downloading reading: $e');
      rethrow;
    }
  }

  /// Update reading with new questions
  Future<void> updateReadingQuestions(String readingId, List<PracticeQuestion> questions) async {
    // Save questions
    await _saveQuestionsForReading(readingId, questions);
    
    // Update reading metadata
    final readings = await loadAllReadings();
    final readingIndex = readings.indexWhere((r) => r.id == readingId);
    if (readingIndex != -1) {
      final reading = readings[readingIndex];
      
      // Update file if exists
      String? filePath = reading.filePath;
      if (reading.source == 'import' && filePath != null) {
        try {
          final content = exportQuestionsToText(questions);
          final file = File(filePath);
          await file.writeAsString(content, encoding: utf8);
        } catch (e) {
          print('Warning: Could not update reading file: $e');
        }
      }
      
      readings[readingIndex] = reading.copyWith(
        questionCount: questions.length,
        updatedAt: DateTime.now(),
      );
      await saveAllReadings(readings);
    }
  }

  /// Update reading title and description
  Future<void> updateReadingMetadata(String readingId, String title, String? description) async {
    final readings = await loadAllReadings();
    final readingIndex = readings.indexWhere((r) => r.id == readingId);
    if (readingIndex != -1) {
      readings[readingIndex] = readings[readingIndex].copyWith(
        title: title,
        description: description,
        updatedAt: DateTime.now(),
      );
      await saveAllReadings(readings);
    }
  }
}

