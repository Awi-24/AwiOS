/// Comentário em um post do InstaHub.
class InstaHubComment {
  final String id;
  final String author;
  final String text;
  final Set<String> likedBy;
  final DateTime createdAt;

  InstaHubComment({
    required this.id,
    required this.author,
    required this.text,
    this.likedBy = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get likeCount => likedBy.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'likedBy': likedBy.toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory InstaHubComment.fromJson(Map<String, dynamic> json) {
    return InstaHubComment(
      id: json['id'] as String? ?? '',
      author: json['author'] as String? ?? 'You',
      text: json['text'] as String? ?? '',
      likedBy: (json['likedBy'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  InstaHubComment copyWith({
    String? id,
    String? author,
    String? text,
    Set<String>? likedBy,
    DateTime? createdAt,
  }) {
    return InstaHubComment(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
