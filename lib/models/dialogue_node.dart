import 'choice.dart';

/// Type of dialogue node (message, media, choice, system).
enum DialogueNodeType {
  text,
  image,
  audio,
  system,
  choice,
}

/// A single node in the dialogue graph (one message, one choice block, etc.).
/// Engine and parser work with this; UI only displays.
class DialogueNode {
  final String id;
  final String senderId;
  final DialogueNodeType type;
  final String content;
  final double delay;
  final String? condition;
  final List<String>? effects;
  final String? nextNode;
  final List<Choice>? choices;
  final Map<String, dynamic>? metadata;
  /// True se a mensagem é do jogador (personagem com [Player] em CHARACTERS).
  /// UI usa para renderizar bolha à direita (Alignment.centerRight).
  final bool isUser;

  const DialogueNode({
    required this.id,
    required this.senderId,
    this.type = DialogueNodeType.text,
    this.content = '',
    this.delay = 0,
    this.condition,
    this.effects,
    this.nextNode,
    this.choices,
    this.metadata,
    this.isUser = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'type': type.name,
        'content': content,
        'isUser': isUser,
      };

  static DialogueNode fromJson(Map<String, dynamic> json) {
    return DialogueNode(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      type: DialogueNodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DialogueNodeType.text,
      ),
      content: json['content'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
    );
  }

  DialogueNode copyWith({
    String? id,
    String? senderId,
    DialogueNodeType? type,
    String? content,
    double? delay,
    String? condition,
    List<String>? effects,
    String? nextNode,
    List<Choice>? choices,
    Map<String, dynamic>? metadata,
    bool? isUser,
  }) {
    return DialogueNode(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      delay: delay ?? this.delay,
      condition: condition ?? this.condition,
      effects: effects ?? this.effects,
      nextNode: nextNode ?? this.nextNode,
      choices: choices ?? this.choices,
      metadata: metadata ?? this.metadata,
      isUser: isUser ?? this.isUser,
    );
  }
}
