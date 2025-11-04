enum QuestionType {
  fillToSentence, // Fill to sentence with index positions
  chooseOne, // Choose 1 right answer from list
  chooseMulti, // Choose multiple right answers
  answerText, // Free text answer
}

class PracticeQuestion {
  final String id;
  final QuestionType type;
  final String questionText;
  final List<String> correctAnswers; // For multi-select, can have multiple correct answers
  final List<String> options; // Options for choosing (for types 1, 2, 3)
  final List<int>? blankPositions; // For fill to sentence: positions where blanks should be

  PracticeQuestion({
    required this.id,
    required this.type,
    required this.questionText,
    required this.correctAnswers,
    this.options = const [],
    this.blankPositions,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'questionText': questionText,
      'correctAnswers': correctAnswers,
      'options': options,
      'blankPositions': blankPositions,
    };
  }

  // Create from JSON
  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    return PracticeQuestion(
      id: json['id'] as String,
      type: QuestionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestionType.chooseOne,
      ),
      questionText: json['questionText'] as String,
      correctAnswers: List<String>.from(json['correctAnswers'] as List),
      options: List<String>.from(json['options'] as List? ?? []),
      blankPositions: json['blankPositions'] != null
          ? List<int>.from(json['blankPositions'] as List)
          : null,
    );
  }

  // Parse question from text format
  static PracticeQuestion? parseFromText(String text, String id) {
    try {
      // Remove leading/trailing whitespace
      text = text.trim();
      
      // Extract question part [q]... and answer part [a]...
      // Use [\s\S]*? to match any character including newlines
      final questionMatch = RegExp(r'\[q\]([\s\S]*?)(\[a\]|$)', dotAll: true).firstMatch(text);
      final answerMatch = RegExp(r'\[a\]([\s\S]*?)$', dotAll: true).firstMatch(text);
      
      if (questionMatch == null || answerMatch == null) {
        print('Failed to parse: questionMatch=${questionMatch != null}, answerMatch=${answerMatch != null}');
        print('Text: $text');
        return null;
      }
      
      String questionText = questionMatch.group(1)?.trim() ?? '';
      String answerPart = answerMatch.group(1)?.trim() ?? '';
      
      // Parse answer part: [right-answer][items...] or [right-answer][(texteditor)]
      final answerPattern = RegExp(r'\[([^\]]+)\]\[([^\]]+)\]');
      final answerMatch2 = answerPattern.firstMatch(answerPart);
      
      if (answerMatch2 == null) {
        print('Failed to match answer pattern. answerPart: "$answerPart"');
        return null;
      }
      
      String rightAnswer = answerMatch2.group(1)?.trim() ?? '';
      String itemsPart = answerMatch2.group(2)?.trim() ?? '';
      
      // Determine question type
      QuestionType type;
      List<String> options = [];
      List<int>? blankPositions;
      
      // Check if it's text editor type
      if (itemsPart == '(texteditor)') {
        type = QuestionType.answerText;
      }
      // Check if it's fill to sentence (has (1), (2), etc. in question)
      else if (RegExp(r'\(\d+\)').hasMatch(questionText)) {
        type = QuestionType.fillToSentence;
        // Extract blank positions
        final blankMatches = RegExp(r'\((\d+)\)').allMatches(questionText);
        blankPositions = blankMatches.map((m) => int.parse(m.group(1)!)).toList();
        // Parse options
        options = itemsPart.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      // Check if right answer contains comma (multiple correct answers)
      else if (rightAnswer.contains(',')) {
        type = QuestionType.chooseMulti;
        options = itemsPart.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      else {
        type = QuestionType.chooseOne;
        options = itemsPart.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      
      // Parse correct answers
      List<String> correctAnswers = rightAnswer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      return PracticeQuestion(
        id: id,
        type: type,
        questionText: questionText,
        correctAnswers: correctAnswers,
        options: options,
        blankPositions: blankPositions,
      );
    } catch (e) {
      print('Error parsing question: $e');
      return null;
    }
  }
}

