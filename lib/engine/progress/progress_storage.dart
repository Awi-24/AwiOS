import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/progress_data.dart';

/// Persistência de progresso global. Pode usar path_provider no Flutter.
/// Estrutura: storage/global_flags.json, storage/chapter_history.json
abstract class ProgressStorage {
  Future<void> saveGlobalFlags(GlobalFlags flags);
  Future<GlobalFlags> loadGlobalFlags();

  Future<void> saveChapterHistory(ChapterHistory history);
  Future<ChapterHistory> loadChapterHistory();
}

/// In-memory para testes ou quando storage não está disponível.
class MemoryProgressStorage implements ProgressStorage {
  GlobalFlags _flags = GlobalFlags();
  ChapterHistory _history = ChapterHistory();

  @override
  Future<void> saveGlobalFlags(GlobalFlags flags) async {
    _flags = flags.copy();
  }

  @override
  Future<GlobalFlags> loadGlobalFlags() async {
    return _flags.copy();
  }

  @override
  Future<void> saveChapterHistory(ChapterHistory history) async {
    _history = history.copy();
  }

  @override
  Future<ChapterHistory> loadChapterHistory() async {
    return _history.copy();
  }
}

const _kGlobalFlags = 'awios_progress_global_flags';
const _kChapterHistory = 'awios_progress_chapter_history';

/// Persiste em SharedPreferences (save_state.json conceitual).
class SharedPreferencesProgressStorage implements ProgressStorage {
  @override
  Future<void> saveGlobalFlags(GlobalFlags flags) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGlobalFlags, jsonEncode(flags.toJson()));
    } catch (_) {}
  }

  @override
  Future<GlobalFlags> loadGlobalFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kGlobalFlags);
      if (json != null) return GlobalFlags.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (_) {}
    return GlobalFlags();
  }

  @override
  Future<void> saveChapterHistory(ChapterHistory history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kChapterHistory, jsonEncode(history.toJson()));
    } catch (_) {}
  }

  @override
  Future<ChapterHistory> loadChapterHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kChapterHistory);
      if (json != null) return ChapterHistory.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (_) {}
    return ChapterHistory();
  }
}
