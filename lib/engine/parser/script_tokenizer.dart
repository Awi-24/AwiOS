/// Token types for .awn script.
enum TokenType {
  label,      // @start
  speaker,    // Alice:
  content,    // line of dialogue
  choice,     // > option
  delay,      // delay: 1.2
  ifLine,     // @if
  elseLine,   // @else
  endif,      // @endif
  end,        // @end
  comment,    // #
  empty,
}

/// Single token from script.
class ScriptToken {
  final TokenType type;
  final String raw;
  final int line;

  const ScriptToken({required this.type, required this.raw, this.line = 0});
}

/// Tokenizes .awn script into a list of tokens.
/// Pure Dart.
class ScriptTokenizer {
  List<ScriptToken> tokenize(String script) {
    final tokens = <ScriptToken>[];
    final lines = script.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        tokens.add(ScriptToken(type: TokenType.empty, raw: line, line: i + 1));
        continue;
      }
      if (trimmed.startsWith('#')) {
        tokens.add(ScriptToken(type: TokenType.comment, raw: trimmed, line: i + 1));
        continue;
      }
      if (trimmed.startsWith('@')) {
        if (trimmed == '@end') {
          tokens.add(ScriptToken(type: TokenType.end, raw: trimmed, line: i + 1));
        } else if (trimmed.startsWith('@if ')) {
          tokens.add(ScriptToken(type: TokenType.ifLine, raw: trimmed.substring(4).trim(), line: i + 1));
        } else if (trimmed == '@else') {
          tokens.add(ScriptToken(type: TokenType.elseLine, raw: trimmed, line: i + 1));
        } else if (trimmed == '@endif') {
          tokens.add(ScriptToken(type: TokenType.endif, raw: trimmed, line: i + 1));
        } else {
          tokens.add(ScriptToken(type: TokenType.label, raw: trimmed.substring(1).trim(), line: i + 1));
        }
        continue;
      }
      if (RegExp(r'^delay\s*:', caseSensitive: false).hasMatch(trimmed)) {
        tokens.add(ScriptToken(type: TokenType.delay, raw: trimmed.replaceFirst(RegExp(r'^delay\s*:\s*', caseSensitive: false), '').trim(), line: i + 1));
        continue;
      }
      if (trimmed.startsWith('>')) {
        tokens.add(ScriptToken(type: TokenType.choice, raw: trimmed.substring(1).trim(), line: i + 1));
        continue;
      }
      if (RegExp(r'^[A-Za-z0-9_]+\s*:').hasMatch(trimmed)) {
        tokens.add(ScriptToken(type: TokenType.speaker, raw: trimmed, line: i + 1));
        continue;
      }
      tokens.add(ScriptToken(type: TokenType.content, raw: trimmed, line: i + 1));
    }
    return tokens;
  }
}
