class Reading {
  final String id;
  final String title;
  final String? description;
  final String source; // 'api', 'assets', 'import'
  final String? filePath; // For assets or imported files
  final String? apiUrl; // For API source
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int questionCount;

  Reading({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    this.filePath,
    this.apiUrl,
    required this.createdAt,
    this.updatedAt,
    this.questionCount = 0,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'source': source,
      'filePath': filePath,
      'apiUrl': apiUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'questionCount': questionCount,
    };
  }

  // Create from JSON
  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      source: json['source'] as String,
      filePath: json['filePath'] as String?,
      apiUrl: json['apiUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      questionCount: json['questionCount'] as int? ?? 0,
    );
  }

  // Create a copy with updated fields
  Reading copyWith({
    String? id,
    String? title,
    String? description,
    String? source,
    String? filePath,
    String? apiUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? questionCount,
  }) {
    return Reading(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
      apiUrl: apiUrl ?? this.apiUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      questionCount: questionCount ?? this.questionCount,
    );
  }
}

