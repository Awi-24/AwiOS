import '../../models/game_state.dart';

/// Evaluates condition strings against [GameState].
/// Supports: trust > 5, met_alice == true, score >= 10 && trust > 3
/// Pure Dart – no Flutter.
class ConditionEvaluator {
  bool evaluate(String condition, GameState state) {
    final s = condition.trim();
    if (s.isEmpty) return true;

    // Split by && and ||
    final orParts = _splitTopLevel(s, '||');
    if (orParts.length > 1) {
      return orParts.any((part) => evaluate(part.trim(), state));
    }
    final andParts = _splitTopLevel(s, '&&');
    if (andParts.length > 1) {
      return andParts.every((part) => evaluate(part.trim(), state));
    }

    final expr = s.trim();
    if (expr.startsWith('!')) {
      return !evaluate(expr.substring(1).trim(), state);
    }
    if (expr.startsWith('not ')) {
      return !evaluate(expr.substring(4).trim(), state);
    }

    return _evalComparison(expr, state);
  }

  List<String> _splitTopLevel(String s, String op) {
    final list = <String>[];
    int depth = 0;
    int start = 0;
    for (int i = 0; i <= s.length - op.length; i++) {
      if (s.substring(i, i + op.length) == op && depth == 0) {
        list.add(s.substring(start, i));
        start = i + op.length;
        i += op.length - 1;
      } else if (s[i] == '(') {
        depth++;
      } else if (s[i] == ')') {
        depth--;
      }
    }
    list.add(s.substring(start));
    return list;
  }

  bool _evalComparison(String expr, GameState state) {
    final ops = ['>=', '<=', '==', '!=', '>', '<'];
    for (final op in ops) {
      final i = expr.indexOf(op);
      if (i > 0) {
        final left = expr.substring(0, i).trim();
        final right = expr.substring(i + op.length).trim();
        final l = _value(left, state);
        final r = _value(right, state);
        switch (op) {
          case '>=':
            return (_num(l) >= _num(r));
          case '<=':
            return (_num(l) <= _num(r));
          case '==':
            return _eq(l, r);
          case '!=':
            return !_eq(l, r);
          case '>':
            return (_num(l) > _num(r));
          case '<':
            return (_num(l) < _num(r));
        }
      }
    }
    return _truth(state.get(expr, false));
  }

  dynamic _value(String token, GameState state) {
    final t = token.trim();
    if (t == 'true') return true;
    if (t == 'false') return false;
    if (t.startsWith('"') && t.endsWith('"')) return t.substring(1, t.length - 1);
    final num? n = num.tryParse(t);
    if (n != null) return n;
    final v = state.get(t);
    if (v != null) return v;
    if (state.hasFlag(t)) return true;
    return null;
  }

  num _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    if (v == true) return 1;
    if (v == false) return 0;
    return 0;
  }

  bool _eq(dynamic a, dynamic b) {
    if (a == b) return true;
    return _num(a) == _num(b);
  }

  bool _truth(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    return true;
  }
}
