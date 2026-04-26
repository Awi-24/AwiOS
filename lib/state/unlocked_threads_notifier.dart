import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Threads desbloqueados por trigger no script. Ex: ana_mike_mike
class UnlockedThreadsNotifier extends Notifier<Set<String>> {
  static const _key = 'awios_unlocked_threads';

  @override
  Set<String> build() {
    Future.microtask(() => _load());
    return {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>?;
        if (list != null) {
          state = list.map((e) => e.toString()).toSet();
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toList()));
    } catch (_) {}
  }

  void unlock(String baseChatId, String threadId) {
    final key = '${baseChatId}_$threadId';
    if (state.contains(key)) return;
    state = {...state, key};
    _save();
  }

  bool isUnlocked(String baseChatId, String threadId) {
    return state.contains('${baseChatId}_$threadId');
  }

  Future<void> resetAll() async {
    state = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

final unlockedThreadsProvider =
    NotifierProvider<UnlockedThreadsNotifier, Set<String>>(UnlockedThreadsNotifier.new);
