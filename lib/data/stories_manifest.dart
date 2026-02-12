import '../models/chat_entry.dart';

/// Pre-loaded at startup from _manifest.json (see main.dart).
/// Falls back to [kStoriesManifestFallback] when manifest doesn't exist.
List<ChatEntry>? gLoadedStories;

/// Fallback when _manifest.json doesn't exist or generation hasn't been run.
/// Run: dart run tool/generate_stories_manifest.dart
const List<ChatEntry> kStoriesManifestFallback = [
  ChatEntry(
    id: 'main',
    name: 'Interactive Guide',
    scriptPath: 'assets/scripts/main.awi',
    avatarPath: 'assets/images/tulip.png',
    lastPreview: 'Hello! I\'m your guide to the AwiOS Engine. Tap to start.',
    chapterId: 'main',
    chapterScripts: {
      'main': 'assets/scripts/main.awi',
    },
    threads: [
      ChatThreadDef(
        id: 'grupo',
        name: 'Guide',
        entryLabel: 'start',
        participantIds: ['A', 'P'],
        avatarPath: 'assets/images/tulip.png',
      ),
    ],
  ),
];
