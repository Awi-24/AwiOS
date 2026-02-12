import '../../models/progress_data.dart';
import 'progress_storage.dart';

/// Gerenciador de progresso global – o "Caderno de Notas" do jogo.
/// Persiste flags e histórico de capítulos para o motor "analisar o passado e decidir o futuro".
///
/// Uso:
/// - Ao terminar um capítulo: [recordChapterPath]
/// - Ao iniciar um capítulo: [getStartNodeForChapter] ou [mergeIntoGameState]
/// - Ao aplicar efeitos: [applyEffects] atualiza global_flags
class ProgressManager {
  final ProgressStorage _storage;
  GlobalFlags _globalFlags;
  ChapterHistory _chapterHistory;

  ProgressManager({ProgressStorage? storage})
      : _storage = storage ?? MemoryProgressStorage(),
        _globalFlags = GlobalFlags(),
        _chapterHistory = ChapterHistory();

  GlobalFlags get globalFlags => _globalFlags;
  ChapterHistory get chapterHistory => _chapterHistory;

  /// Carrega dados persistentes (chamar no início do app).
  Future<void> load() async {
    _globalFlags = await _storage.loadGlobalFlags();
    _chapterHistory = await _storage.loadChapterHistory();
  }

  /// Salva progresso (chamar após mudanças significativas).
  Future<void> save() async {
    await _storage.saveGlobalFlags(_globalFlags);
    await _storage.saveChapterHistory(_chapterHistory);
  }

  /// Registra qual path foi tomado ao terminar um capítulo.
  void recordChapterPath(String chapterId, String pathOrNodeId) {
    _chapterHistory.recordPath(chapterId, pathOrNodeId);
    save(); // Persiste imediatamente
  }

  /// Retorna o path tomado em um capítulo, ou null.
  String? getChapterPath(String chapterId) {
    return _chapterHistory.getPath(chapterId);
  }

  /// Reseta todo o progresso (flags globais e histórico de capítulos).
  void reset() {
    _globalFlags = GlobalFlags();
    _chapterHistory = ChapterHistory();
  }

  /// Reseta e persiste imediatamente (para limpeza completa).
  Future<void> resetAndPersist() async {
    reset();
    await save();
  }

  /// Lógica de Bridge: decide o nó inicial do capítulo baseado no passado.
  ///
  /// [chapterId] – ID do capítulo atual
  /// [defaultStart] – nó padrão (ex: 'start')
  /// [bridgeRules] – mapa: path_anterior -> nó_inicial.
  ///   Ex: {'chapter_01': {'path_trabalho': 'node_recompensa', 'path_preguica': 'node_bronca'}}
  ///
  /// Retorna o nó inicial adequado ou [defaultStart].
  String resolveStartNode({
    required String chapterId,
    required String defaultStart,
    Map<String, Map<String, String>>? bridgeRules,
    String? dependencyChapterId,
  }) {
    if (bridgeRules == null || dependencyChapterId == null) {
      return defaultStart;
    }
    final depPath = _chapterHistory.getPath(dependencyChapterId);
    if (depPath == null) return defaultStart;

    final rules = bridgeRules[dependencyChapterId];
    if (rules == null) return defaultStart;

    return rules[depPath] ?? defaultStart;
  }

  /// Aplica efeitos no global state (ex: trust += 1, task_done = true).
  void applyToGlobalFlags(List<String> effects) {
    for (final e in effects) {
      final s = e.trim();
      if (s.isEmpty) continue;
      if (RegExp(r'\+\s*=').hasMatch(s)) {
        final parts = s.split(RegExp(r'\+\s*='));
        if (parts.length == 2) {
          final key = parts[0].trim();
          final val = num.tryParse(parts[1].trim());
          if (val != null) _globalFlags.add(key, val);
        }
      } else if (RegExp(r'\-\s*=').hasMatch(s)) {
        final parts = s.split(RegExp(r'\-\s*='));
        if (parts.length == 2) {
          final key = parts[0].trim();
          final val = num.tryParse(parts[1].trim());
          if (val != null) _globalFlags.add(key, -val);
        }
      } else if (RegExp(r'\s*=\s*').hasMatch(s)) {
        final idx = s.indexOf('=');
        final key = s.substring(0, idx).trim();
        final val = s.substring(idx + 1).trim().toLowerCase();
        final numVal = num.tryParse(val);
        _globalFlags.set(key, numVal ?? (val == 'true' ? true : val == 'false' ? false : val));
      }
    }
  }

  /// Mescla flags globais no GameState da sessão (para condições e efeitos).
  void mergeIntoGameState(Map<String, dynamic> target) {
    target.addAll(_globalFlags.all);
  }

  /// Snapshot para save slot (inclui progresso global).
  Map<String, dynamic> toJson() => {
        'globalFlags': _globalFlags.toJson(),
        'chapterHistory': _chapterHistory.toJson(),
      };

  /// Restaura a partir de save slot.
  void fromJson(Map<String, dynamic> json) {
    final flags = json['globalFlags'] as Map?;
    final history = json['chapterHistory'] as Map?;
    if (flags != null) _globalFlags = GlobalFlags.fromJson(Map<String, dynamic>.from(flags));
    if (history != null) _chapterHistory = ChapterHistory.fromJson(Map<String, dynamic>.from(history));
  }
}
