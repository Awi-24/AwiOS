import '../../models/dialogue_node.dart';
import '../../models/character.dart';
import 'script_parser.dart';

/// Parser para formato .awn (legado). Formato diferente de .awi.
/// .awi: blocos [label], SETTINGS, system:, threads, eventos OS.
/// .awn: @labels, sem SETTINGS, sem system:.
/// Usado apenas quando o script não é detectado como .awi.
class AwnParser {
  final ScriptParser _inner = ScriptParser();

  Map<String, DialogueNode> parse(String script, {Map<String, Character>? definedCharacters}) {
    return _inner.parse(script, definedCharacters: definedCharacters ?? {});
  }
}
