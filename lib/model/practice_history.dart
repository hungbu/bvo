import 'dart:convert';

/// Model for practice session history
class PracticeHistory {
  final String id;
  final String readingId;
  final DateTime completedAt;
  final int totalQuestions;
  final int correctAnswers;
  final double accuracy; // 0.0 to 1.0
  final Map<String, List<String>> userAnswers; // questionId -> answers
  final Map<String, bool> questionResults; // questionId -> isCorrect

  PracticeHistory({
    required this.id,
    required this.readingId,
    required this.completedAt,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.accuracy,
    required this.userAnswers,
    required this.questionResults,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'readingId': readingId,
      'completedAt': completedAt.toIso8601String(),
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'accuracy': accuracy,
      'userAnswers': userAnswers.map((k, v) => MapEntry(k, v)),
      'questionResults': questionResults,
    };
  }

  factory PracticeHistory.fromJson(Map<String, dynamic> json) {
    return PracticeHistory(
      id: json['id'] as String,
      readingId: json['readingId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      userAnswers: Map<String, List<String>>.from(
        (json['userAnswers'] as Map).map(
          (k, v) => MapEntry(k as String, List<String>.from(v as List)),
        ),
      ),
      questionResults: Map<String, bool>.from(
        (json['questionResults'] as Map).map(
          (k, v) => MapEntry(k as String, v as bool),
        ),
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory PracticeHistory.fromJsonString(String jsonString) =>
      PracticeHistory.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}

