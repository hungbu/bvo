// topic model
class Topic {
  final String id;
  final String topic;
  Topic({required this.topic, required this.id}); // Change to String id

  // Convert a Topic to a Map (for Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
    };
  }

  // Create a Topic from a Map (from Firestore)
  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(id: json['id'], topic: json['topic']);
  }
}