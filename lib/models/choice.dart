/// A single player choice – text, target label, optional condition and effects.
class Choice {
  final String text;
  final String nextNode;
  final String? condition;
  final List<String>? effects;

  const Choice({
    required this.text,
    required this.nextNode,
    this.condition,
    this.effects,
  });

  Choice copyWith({
    String? text,
    String? nextNode,
    String? condition,
    List<String>? effects,
  }) {
    return Choice(
      text: text ?? this.text,
      nextNode: nextNode ?? this.nextNode,
      condition: condition ?? this.condition,
      effects: effects ?? this.effects,
    );
  }
}
