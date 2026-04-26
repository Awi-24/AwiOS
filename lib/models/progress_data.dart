// Persistent progress data – script (estático) vs progresso (dinâmico).
// Armazena o que o jogador fez para o motor "analisar o passado e decidir o futuro".

/// Histórico de capítulos: qual path foi tomado em cada um.
/// Ex: {"chapter_01": "path_trabalho", "chapter_02": "node_recebe_recompensa"}
class ChapterHistory {
  final Map<String, String> _paths = {};

  ChapterHistory([Map<String, String>? initial]) {
    if (initial != null) _paths.addAll(initial);
  }

  String? getPath(String chapterId) => _paths[chapterId];

  void recordPath(String chapterId, String pathOrNodeId) {
    _paths[chapterId] = pathOrNodeId;
  }

  Map<String, String> get all => Map.unmodifiable(_paths);

  ChapterHistory copy() => ChapterHistory(Map.from(_paths));

  Map<String, dynamic> toJson() => {'paths': Map.from(_paths)};

  factory ChapterHistory.fromJson(Map<String, dynamic> json) {
    final paths = json['paths'] as Map?;
    return ChapterHistory(
      paths != null ? Map<String, String>.from(paths) : null,
    );
  }
}

/// Flags globais persistem entre capítulos (afeição, pontos, etc.)
class GlobalFlags {
  final Map<String, dynamic> _data = {};

  GlobalFlags([Map<String, dynamic>? initial]) {
    if (initial != null) _data.addAll(initial);
  }

  dynamic get(String key, [dynamic defaultValue]) {
    if (_data.containsKey(key)) return _data[key];
    return defaultValue;
  }

  void set(String key, dynamic value) {
    _data[key] = value;
  }

  void add(String key, num delta) {
    final current = _data[key];
    final num currentNum = current is num ? current : 0;
    _data[key] = currentNum + delta;
  }

  bool hasFlag(String flag) => _data[flag] == true;

  void setFlag(String flag, bool value) {
    _data[flag] = value;
  }

  Map<String, dynamic> get all => Map.unmodifiable(_data);

  GlobalFlags copy() => GlobalFlags(Map.from(_data));

  Map<String, dynamic> toJson() => Map.from(_data);

  factory GlobalFlags.fromJson(Map<String, dynamic> json) {
    return GlobalFlags(Map<String, dynamic>.from(json));
  }
}
