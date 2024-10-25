// create word class

class Word {
  String en;
  String vi;
  String sentence;
  String topic;
  String pronunciation;
  int reviewCount;
  DateTime nextReview;

  Word({
    required this.en,
    required this.vi,
    required this.sentence,
    required this.topic,
    required this.pronunciation,
    this.reviewCount = 0,
    DateTime? nextReview,
  }) : nextReview = nextReview ?? DateTime.now();

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      en: json['en'],
      vi: json['vi'],
      sentence: json['sentence'],
      topic: json['topic'],
      pronunciation: json['pronunciation'],
      reviewCount: json['reviewCount'] ?? 0,
      nextReview: json['nextReview'] != null
          ? DateTime.parse(json['nextReview'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['en'] = en;
    data['vi'] = vi;
    data['sentence'] = sentence;
    data['topic'] = topic;
    data['pronunciation'] = pronunciation;
    data['reviewCount'] = reviewCount;
    data['nextReview'] =
        nextReview.toIso8601String(); // Convert DateTime to String
    return data;
  }
}
