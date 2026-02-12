import '../../models/game_state.dart';

/// Applies effect strings to [GameState].
/// Supports: trust += 1, coins -= 5, met_alice = true
/// Pure Dart – no Flutter.
class EffectApplier {
  void apply(String effect, GameState state) {
    final s = effect.trim();
    if (s.isEmpty) return;

    // var += n or var -= n
    final plusMatch = RegExp(r'^(\w+)\s*\+\=\s*(.+)$').firstMatch(s);
    if (plusMatch != null) {
      final key = plusMatch.group(1)!;
      final delta = _parseNum(plusMatch.group(2)!, state);
      state.add(key, delta);
      return;
    }
    final minusMatch = RegExp(r'^(\w+)\s*\-\=\s*(.+)$').firstMatch(s);
    if (minusMatch != null) {
      final key = minusMatch.group(1)!;
      final delta = _parseNum(minusMatch.group(2)!, state);
      state.add(key, -delta);
      return;
    }

    // key = value (boolean, number, or string)
    final assignMatch = RegExp(r'^(\w+)\s*=\s*(.+)$').firstMatch(s);
    if (assignMatch != null) {
      final key = assignMatch.group(1)!;
      final value = assignMatch.group(2)!.trim().toLowerCase();
      if (value == 'true') {
        state.set(key, true);
        state.setFlag(key, true);
      } else if (value == 'false') {
        state.set(key, false);
        state.setFlag(key, false);
      } else {
        final n = num.tryParse(value);
        state.set(key, n ?? value);
      }
      return;
    }

    // Fallback: treat as flag set
    state.setFlag(s, true);
  }

  num _parseNum(String expr, GameState state) {
    final t = expr.trim();
    final n = num.tryParse(t);
    if (n != null) return n;
    final v = state.get(t);
    if (v is num) return v;
    return 0;
  }

  void applyAll(List<String> effects, GameState state) {
    for (final e in effects) {
      apply(e, state);
    }
  }
}
