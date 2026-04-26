import 'progress_data.dart';

/// Save slot data – serializable for persistence.
class SaveData {
  final String? currentNode;
  final String? currentChapterId;
  final Map<String, dynamic> variables;
  final List<String> flags;
  final List<String> history;
  final List<String> unlockedMedia;
  final Map<String, dynamic> globalFlagsJson;
  final Map<String, String> chapterHistoryPaths;
  final Map<String, Map<String, dynamic>> choiceNodesJson;
  final DateTime timestamp;

  const SaveData({
    this.currentNode,
    this.currentChapterId,
    this.variables = const {},
    this.flags = const [],
    this.history = const [],
    this.unlockedMedia = const [],
    this.globalFlagsJson = const {},
    this.chapterHistoryPaths = const {},
    this.choiceNodesJson = const {},
    required this.timestamp,
  });

  GlobalFlags get globalFlags => GlobalFlags.fromJson(Map.from(globalFlagsJson));
  ChapterHistory get chapterHistory => ChapterHistory(chapterHistoryPaths.isEmpty ? null : Map.from(chapterHistoryPaths));

  Map<String, dynamic> toJson() => {
        'currentNode': currentNode,
        'currentChapterId': currentChapterId,
        'variables': variables,
        'flags': flags,
        'history': history,
        'unlockedMedia': unlockedMedia,
        'globalFlags': globalFlagsJson,
        'chapterHistory': {'paths': chapterHistoryPaths},
        'choiceNodes': choiceNodesJson,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SaveData.fromJson(Map<String, dynamic> json) {
    final gf = json['globalFlags'] as Map?;
    final ch = json['chapterHistory'] as Map?;
    final paths = ch?['paths'] as Map?;
    final choiceNodes = json['choiceNodes'] as Map?;
    final choiceNodesMap = <String, Map<String, dynamic>>{};
    if (choiceNodes != null) {
      for (final e in choiceNodes.entries) {
        if (e.value is Map) {
          choiceNodesMap[e.key.toString()] = Map<String, dynamic>.from(e.value as Map);
        }
      }
    }
    return SaveData(
      currentNode: json['currentNode'] as String?,
      currentChapterId: json['currentChapterId'] as String?,
      variables: Map<String, dynamic>.from(json['variables'] as Map? ?? {}),
      flags: List<String>.from(json['flags'] as List? ?? []),
      history: List<String>.from(json['history'] as List? ?? []),
      unlockedMedia: List<String>.from(json['unlockedMedia'] as List? ?? []),
      globalFlagsJson: gf != null ? Map<String, dynamic>.from(gf) : {},
      chapterHistoryPaths: paths != null ? Map<String, String>.from(paths) : {},
      choiceNodesJson: choiceNodesMap,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
