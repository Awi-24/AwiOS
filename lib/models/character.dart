/// Character model – represents a dialogue participant.
/// Used by the engine and UI for avatars, colors, and labels.
class Character {
  final String id;
  final String name;
  final String? avatar;
  final int bubbleColor;
  final int textColor;
  final bool isPlayer;

  const Character({
    required this.id,
    required this.name,
    this.avatar,
    this.bubbleColor = 0xFF007AFF,
    this.textColor = 0xFFFFFFFF,
    this.isPlayer = false,
  });

  Character copyWith({
    String? id,
    String? name,
    String? avatar,
    int? bubbleColor,
    int? textColor,
    bool? isPlayer,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      textColor: textColor ?? this.textColor,
      isPlayer: isPlayer ?? this.isPlayer,
    );
  }
}
