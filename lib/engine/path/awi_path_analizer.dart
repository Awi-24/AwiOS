import '../../models/game_state.dart';
import '../evaluator/condition_evaluator.dart';
import '../progress/progress_manager.dart';
import 'awi_chapter_header.dart';

/// O cérebro que conecta um arquivo .awi ao outro.
/// Leitura preguiçosa: SETTINGS + CHARACTERS apenas.
/// Snapshot de Estado: compara GameState com dependency.
/// Path Tracking: consulta global_flags e chapter history – sem re-ler o arquivo.
class AwiPathAnalizer {
  final ConditionEvaluator _evaluator = ConditionEvaluator();

  /// Parse lazy do SETTINGS – retorna o cabeçalho sem carregar o resto.
  AwiChapterHeader parseHeader(String script) {
    final lines = script.split('\n');
    String? currentBlock;
    final settingsLines = <String>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('#')) continue;
      if (t == 'SETTINGS') {
        currentBlock = 'SETTINGS';
        continue;
      }
      if (t == 'CHARACTERS') {
        currentBlock = 'CHARACTERS';
        continue;
      }
      if (t.startsWith('[') && t.endsWith(']')) {
        currentBlock = null;
        continue;
      }
      if (currentBlock == 'SETTINGS' && t.isNotEmpty) {
        settingsLines.add(line);
      }
    }

    return AwiChapterHeader.parseFromLines(settingsLines);
  }

  /// Estado de avaliação: globalFlags + chapter paths + session state.
  /// Suporta `global.romance_points`, `chapter_01.path` e `history.chapter_01`.
  GameState _buildEvalState(ProgressManager progress, GameState? sessionState) {
    final merged = <String, dynamic>{};
    for (final e in progress.globalFlags.all.entries) {
      merged[e.key] = e.value;
      merged['global.${e.key}'] = e.value;
    }
    for (final e in progress.chapterHistory.all.entries) {
      merged['${e.key}.path'] = e.value;
      merged['history.${e.key}'] = e.value; // Sintaxe: history.chapter_01 == 'path_trabalho'
    }
    if (sessionState != null) merged.addAll(sessionState.variables);
    final state = GameState();
    state.restore(merged, []);
    return state;
  }

  /// Verifica se o capítulo pode ser iniciado (dependency + required_flag).
  bool canStartChapter(
    AwiChapterHeader header,
    ProgressManager progress, {
    GameState? sessionState,
  }) {
    final state = _buildEvalState(progress, sessionState);

    if (header.requiredFlag != null && header.requiredFlag!.isNotEmpty) {
      if (!_evaluator.evaluate(header.requiredFlag!, state)) {
        return false;
      }
    }

    if (header.dependency == null || header.dependency!.trim().isEmpty) {
      return true;
    }
    return _evaluator.evaluate(header.dependency!, state);
  }

  /// Resolve o nó de entrada com base em entry_point e estado.
  String resolveStartNode(
    AwiChapterHeader header,
    ProgressManager progress, {
    GameState? sessionState,
    String defaultStart = 'start',
  }) {
    if (header.entryPoint.isEmpty) return defaultStart;

    final state = _buildEvalState(progress, sessionState);

    for (final rule in header.entryPoint) {
      if (rule.isElse) return rule.label;
      if (rule.condition != null &&
          rule.condition!.isNotEmpty &&
          _evaluator.evaluate(rule.condition!, state)) {
        return rule.label;
      }
    }

    return defaultStart;
  }
}
