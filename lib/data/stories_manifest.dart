import '../models/chat_entry.dart';

/// Pre-loaded at startup from _manifest.json (see main.dart).
/// Falls back to [kStoriesManifestFallback] when manifest doesn't exist.
List<ChatEntry>? gLoadedStories;

/// Fallback when _manifest.json doesn't exist or generation hasn't been run.
/// Run: dart run tool/generate_stories_manifest.dart
const List<ChatEntry> kStoriesManifestFallback = [
  ChatEntry(
    id: 'ntr_story',
    name: 'Noite de Festa',
    scriptPath: 'assets/scripts/ntr_story_01.awi',
    avatarPath: 'assets/images/avatar/mark_avatar.png',
    lastPreview: "Coming home after the party. Mark is still up.",
    chapterId: 'ntr_story',
    chapterScripts: {
      'ntr_story_01': 'assets/scripts/ntr_story_01.awi',
    },
    threads: [
      ChatThreadDef(
        id: 'mark',
        name: 'Mark 💙',
        entryLabel: 'start',
        participantIds: ['P', 'M'],
        avatarPath: 'assets/images/avatar/mark_avatar.png',
      ),
      ChatThreadDef(
        id: 'liam',
        name: 'Liam',
        entryLabel: 'liam_locked',
        characterId: 'L',
        avatarPath: 'assets/images/avatar/liam_avatar.png',
      ),
    ],
  ),
];
