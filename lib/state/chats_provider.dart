import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_entry.dart';
import '../data/stories_manifest.dart';
import 'chat_progress_notifier.dart';
import 'unlocked_threads_notifier.dart';

/// Lista de chats com preview persistido. Expande threads quando desbloqueadas.
/// Uses [gLoadedStories] from manifest when available, else [kStoriesManifestFallback].
final chatsProvider = Provider<List<ChatEntry>>((ref) {
  final manifest = gLoadedStories ?? kStoriesManifestFallback;
  final progress = ref.watch(chatProgressProvider);
  final unlocked = ref.watch(unlockedThreadsProvider);
  final result = <ChatEntry>[];

  for (final chat in manifest) {
    if (chat.threads != null && chat.threads!.isNotEmpty) {
      final main = chat.threads!.first;
      final prog = progress[chat.id];
      result.add(ChatEntry(
        id: chat.id,
        name: main.name,
        scriptPath: chat.scriptPath,
        avatarPath: chat.avatarPath,
        lastPreview: prog?.lastPreview.isNotEmpty == true ? prog!.lastPreview : chat.lastPreview,
        chapterId: chat.chapterId,
        chapterScripts: chat.chapterScripts,
        threads: chat.threads,
        entryLabel: main.entryLabel,
      ));
      for (var i = 1; i < chat.threads!.length; i++) {
        final t = chat.threads![i];
        final threadKey = '${chat.id}_${t.id}';
        if (unlocked.contains(threadKey)) {
          final threadProg = progress[threadKey];
          result.add(ChatEntry(
            id: threadKey,
            name: t.name,
            scriptPath: chat.scriptPath,
            avatarPath: t.avatarPath ?? chat.avatarPath,
            lastPreview: threadProg?.lastPreview.isNotEmpty == true ? threadProg!.lastPreview : null,
            chapterId: chat.chapterId,
            chapterScripts: chat.chapterScripts,
            threads: chat.threads,
            threadId: t.id,
            entryLabel: t.entryLabel,
          ));
        }
      }
    } else {
      final prog = progress[chat.id];
      result.add(ChatEntry(
        id: chat.id,
        name: chat.name,
        scriptPath: chat.scriptPath,
        avatarPath: chat.avatarPath,
        lastPreview: prog?.lastPreview.isNotEmpty == true ? prog!.lastPreview : chat.lastPreview,
        chapterId: chat.chapterId,
        chapterScripts: chat.chapterScripts,
      ));
    }
  }
  return result;
});
