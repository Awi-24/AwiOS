import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de progresso por chat (última prévia, última interação, não lido).
class ChatProgressEntry {
  final String lastPreview;
  final DateTime lastOpenedAt;
  final bool hasInteracted;
  final bool hasUnread;

  const ChatProgressEntry({
    required this.lastPreview,
    required this.lastOpenedAt,
    this.hasInteracted = false,
    this.hasUnread = false,
  });

  Map<String, dynamic> toJson() => {
        'lastPreview': lastPreview,
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
        'hasInteracted': hasInteracted,
        'hasUnread': hasUnread,
      };

  factory ChatProgressEntry.fromJson(Map<String, dynamic> json) {
    return ChatProgressEntry(
      lastPreview: json['lastPreview'] as String? ?? '',
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? '') ?? DateTime.now(),
      hasInteracted: json['hasInteracted'] as bool? ?? false,
      hasUnread: json['hasUnread'] as bool? ?? false,
    );
  }
}

/// Persistência de progresso de chats (abertos, última prévia).
class ChatProgressNotifier extends Notifier<Map<String, ChatProgressEntry>> {
  static const _key = 'awios_chat_progress';

  @override
  Map<String, ChatProgressEntry> build() {
    Future.microtask(() => _load());
    return {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>?;
        if (decoded != null) {
          final map = <String, ChatProgressEntry>{};
          for (final e in decoded.entries) {
            if (e.value is Map) {
              map[e.key] = ChatProgressEntry.fromJson(Map<String, dynamic>.from(e.value as Map));
            }
          }
          state = map;
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(_key, encoded);
    } catch (_) {}
  }

  void markOpened(String chatId, {String? lastPreview}) {
    final now = DateTime.now();
    final existing = state[chatId];
    state = {
      ...state,
      chatId: ChatProgressEntry(
        lastPreview: lastPreview ?? existing?.lastPreview ?? '',
        lastOpenedAt: now,
        hasInteracted: existing?.hasInteracted ?? false,
        hasUnread: false,
      ),
    };
    _save();
  }

  void markInteracted(String chatId, String lastPreview) {
    final now = DateTime.now();
    state = {
      ...state,
      chatId: ChatProgressEntry(
        lastPreview: lastPreview,
        lastOpenedAt: now,
        hasInteracted: true,
        hasUnread: false,
      ),
    };
    _save();
  }

  void markUnread(String chatId, {String? lastPreview}) {
    final existing = state[chatId];
    state = {
      ...state,
      chatId: ChatProgressEntry(
        lastPreview: lastPreview ?? existing?.lastPreview ?? '',
        lastOpenedAt: existing?.lastOpenedAt ?? DateTime.now(),
        hasInteracted: existing?.hasInteracted ?? false,
        hasUnread: true,
      ),
    };
    _save();
  }

  int get unreadCount => state.values.where((e) => e.hasUnread).length;

  Future<void> resetAll() async {
    state = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  ChatProgressEntry? get(String chatId) => state[chatId];
}

final chatProgressProvider = NotifierProvider<ChatProgressNotifier, Map<String, ChatProgressEntry>>(
  ChatProgressNotifier.new,
);
