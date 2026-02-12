import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/save_data.dart';
import '../../models/game_state.dart';
import '../../models/dialogue_node.dart';
import '../progress/progress_manager.dart';

/// Saves and loads game state. Pure Dart – can use path_provider via injection.
abstract class SaveManager {
  Future<void> save(int slot, SaveData data);
  Future<SaveData?> load(int slot);
  Future<void> clearAll();
}

/// Save per chat (SharedPreferences). Key: awios_save_chat_{chatId}.
abstract class ChatSaveManager {
  Future<void> save(String chatId, SaveData data);
  Future<SaveData?> load(String chatId);
  Future<void> clearChat(String chatId);
  Future<void> clearAll();
}

/// Persists save per chat in SharedPreferences.
class SharedPreferencesChatSaveManager implements ChatSaveManager {
  static const _prefix = 'awios_save_chat_';

  @override
  Future<void> save(String chatId, SaveData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$chatId', jsonEncode(data.toJson()));
    } catch (_) {}
  }

  @override
  Future<SaveData?> load(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_prefix$chatId');
      if (json == null) return null;
      return SaveData.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearChat(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$chatId');
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

/// In-memory save manager for tests or default implementation.
class MemorySaveManager implements SaveManager {
  final Map<int, SaveData> _slots = {};

  @override
  Future<void> save(int slot, SaveData data) async {
    _slots[slot] = data;
  }

  @override
  Future<SaveData?> load(int slot) async {
    return _slots[slot];
  }

  @override
  Future<void> clearAll() async {
    _slots.clear();
  }
}

/// Builds [SaveData] from engine state and progress manager.
SaveData buildSaveData({
  required String? currentNodeId,
  required GameState state,
  required List<DialogueNode> history,
  required List<String> unlockedMedia,
  String? currentChapterId,
  ProgressManager? progressManager,
}) {
  final gf = progressManager?.globalFlags;
  final ch = progressManager?.chapterHistory;
  final choiceNodesJson = <String, Map<String, dynamic>>{};
  for (final n in history) {
    if (n.id.startsWith('choice_')) {
      choiceNodesJson[n.id] = n.toJson();
    }
  }
  return SaveData(
    currentNode: currentNodeId,
    currentChapterId: currentChapterId,
    variables: Map.from(state.variables),
    flags: state.flags.toList(),
    history: history.map((n) => n.id).toList(),
    unlockedMedia: List.from(unlockedMedia),
    globalFlagsJson: gf?.toJson() ?? {},
    chapterHistoryPaths: ch?.all ?? {},
    choiceNodesJson: choiceNodesJson,
    timestamp: DateTime.now(),
  );
}

/// Restores [GameState] from [SaveData].
void applySaveData(SaveData data, GameState state) {
  state.restore(data.variables, data.flags);
}

/// Restores [ProgressManager] from [SaveData].
void applySaveDataToProgress(SaveData data, ProgressManager progressManager) {
  progressManager.fromJson({
    'globalFlags': data.globalFlagsJson,
    'chapterHistory': data.chapterHistory.toJson(),
  });
}
