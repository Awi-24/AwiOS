import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_manifest.dart';
import 'game_notifier.dart' show progressProvider;

/// Quando definido, o ChatApp abre automaticamente este chat no capítulo indicado.
class PendingChapterStartNotifier extends Notifier<({String chatId, String chapterId, String scriptPath})?> {
  @override
  ({String chatId, String chapterId, String scriptPath})? build() => null;

  void setPending({required String chatId, required String chapterId, required String scriptPath}) {
    state = (chatId: chatId, chapterId: chapterId, scriptPath: scriptPath);
  }

  void clear() {
    state = null;
  }
}

final pendingChapterStartProvider = NotifierProvider<PendingChapterStartNotifier, ({String chatId, String chapterId, String scriptPath})?>(PendingChapterStartNotifier.new);

/// Capítulo disponível para seleção (iniciar com vars padrão).
class SelectableChapter {
  final String chapterId;
  final String storyId;
  final String name;
  final String scriptPath;
  final bool isCompleted;

  const SelectableChapter({
    required this.chapterId,
    required this.storyId,
    required this.name,
    required this.scriptPath,
    this.isCompleted = false,
  });
}

/// Lista de capítulos que o usuário pode iniciar.
/// Capítulos concluídos aparecem com badge; todos podem ser iniciados com vars padrão.
final selectableChaptersProvider = Provider<List<SelectableChapter>>((ref) {
  final stories = gLoadedStories ?? kStoriesManifestFallback;
  final progress = ref.watch(progressProvider);
  final chapterHistory = progress.chapterHistory.all;
  final result = <SelectableChapter>[];

  for (final story in stories) {
    if (story.chapterScripts == null) continue;
    for (final entry in story.chapterScripts!.entries) {
      final chapterId = entry.key;
      final scriptPath = entry.value;
      final isCompleted = chapterHistory.containsKey(chapterId);
      final name = _formatChapterName(chapterId);
      result.add(SelectableChapter(
        chapterId: chapterId,
        storyId: story.id,
        name: name,
        scriptPath: scriptPath,
        isCompleted: isCompleted,
      ));
    }
  }
  result.sort((a, b) => a.chapterId.compareTo(b.chapterId));
  return result;
});

String _formatChapterName(String chapterId) {
  final cap = RegExp(r'_cap(\d+)$').firstMatch(chapterId);
  if (cap != null) return 'Chapter ${cap.group(1)}';
  final num = RegExp(r'_(\d{2})$').firstMatch(chapterId);
  if (num != null) return 'Chapter ${int.parse(num.group(1)!)}';
  return chapterId.replaceAll('_', ' ').replaceAllMapped(
        RegExp(r'\b\w'),
        (m) => m.group(0)!.toUpperCase(),
      );
}
