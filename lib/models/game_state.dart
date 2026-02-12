/// Global game state: variables, flags, inventory.
/// Pure Dart – no Flutter. Engine and evaluator use this.
class GameState {
  final Map<String, dynamic> _variables = {};
  final Set<String> _flags = {};
  final List<String> _inventory = [];

  GameState();

  /// Get variable (number or string). Returns [defaultValue] if missing.
  dynamic get(String key, [dynamic defaultValue]) {
    if (_variables.containsKey(key)) return _variables[key];
    return defaultValue;
  }

  /// Set variable.
  void set(String key, dynamic value) {
    _variables[key] = value;
  }

  /// Add to numeric variable (e.g. trust += 1).
  void add(String key, num delta) {
    final current = _variables[key];
    final num currentNum = current is num ? current : 0;
    _variables[key] = currentNum + delta;
  }

  /// Toggle boolean flag.
  void toggle(String flag) {
    if (_flags.contains(flag)) {
      _flags.remove(flag);
    } else {
      _flags.add(flag);
    }
  }

  bool hasFlag(String flag) => _flags.contains(flag);
  void setFlag(String flag, bool value) {
    if (value) {
      _flags.add(flag);
    } else {
      _flags.remove(flag);
    }
  }

  List<String> get inventory => List.unmodifiable(_inventory);
  void addToInventory(String item) => _inventory.add(item);
  void removeFromInventory(String item) => _inventory.remove(item);

  Map<String, dynamic> get variables => Map.unmodifiable(_variables);
  Set<String> get flags => Set.unmodifiable(_flags);

  /// Snapshot for save (deep copy of primitives).
  GameState copy() {
    final g = GameState();
    g._variables.addAll(Map.from(_variables));
    g._flags.addAll(_flags);
    g._inventory.addAll(_inventory);
    return g;
  }

  /// Replace state with saved variables and flags (for load).
  void restore(Map<String, dynamic> variables, List<String> flags) {
    _variables.clear();
    _variables.addAll(variables);
    _flags.clear();
    _flags.addAll(flags);
  }
}
