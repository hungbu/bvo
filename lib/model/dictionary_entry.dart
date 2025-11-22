class DictionaryEntry {
  final int idx;
  final String word;
  final String detail;

  DictionaryEntry({
    required this.idx,
    required this.word,
    required this.detail,
  });

  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      idx: map['idx'] as int,
      word: map['word'] as String,
      detail: map['detail'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idx': idx,
      'word': word,
      'detail': detail,
    };
  }

  /// Parse HTML detail to extract clean text
  String get cleanDetail {
    // Remove HTML tags and decode entities
    String text = detail
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('<br />', '\n')
        .replaceAll('<br>', '\n')
        .trim();
    
    return text;
  }

  /// Extract pronunciation from detail
  String? get pronunciation {
    final match = RegExp(r'/\s*([^/]+)\s*/').firstMatch(detail);
    return match?.group(1);
  }

  /// Extract Vietnamese meaning
  String? get vietnameseMeaning {
    // Try to extract Vietnamese text after the pronunciation
    final lines = cleanDetail.split('\n');
    for (final line in lines) {
      if (line.contains('danh từ') || 
          line.contains('động từ') || 
          line.contains('tính từ') ||
          line.contains('trạng từ') ||
          line.contains('-')) {
        return line.trim();
      }
    }
    return null;
  }
}

