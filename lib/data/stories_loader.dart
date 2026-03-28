import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/path/awi_chapter_header.dart';
import '../engine/parser/awi_parser.dart';
import '../models/chat_entry.dart';
import '../models/character.dart';

/// Naming convention: {story_id}_{chapter:02d}.awi or legacy {story_id}_capN.awi
({String storyId, int chapter}) _parseFilename(String path) {
  final name = path.split('/').last.toLowerCase();
  if (name.endsWith('.awi')) {
    final base = name.substring(0, name.length - 4);
    final m1 = RegExp(r'^(.+)_(\d{2})$').firstMatch(base);
    if (m1 != null) {
      return (storyId: m1.group(1)!, chapter: int.parse(m1.group(2)!, radix: 10));
    }
    final m2 = RegExp(r'^(.+)_cap(\d+)$').firstMatch(base);
    if (m2 != null) {
      return (storyId: m2.group(1)!, chapter: int.parse(m2.group(2)!, radix: 10));
    }
    return (storyId: base, chapter: 1);
  }
  return (storyId: path, chapter: 1);
}

/// Loads stories from _manifest.json + parses each .awi header. Returns null on failure.
/// Uses [bundle] when provided (e.g. SecureAssetBundle for release); otherwise rootBundle.
Future<List<ChatEntry>?> loadStoriesFromManifest({AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  try {
    final json = await b.loadString('assets/scripts/_manifest.json');
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final scripts = (decoded['scripts'] as List<dynamic>).cast<String>();
    if (scripts.isEmpty) return null;

    final parser = AwiParser();
    final byStory = <String, List<({String path, int chapter, AwiChapterHeader header, Map<String, Character> characters})>>{};

    for (final path in scripts) {
      final parsed = _parseFilename(path);
      final content = await b.loadString(path);
      final (header, characters) = parser.parseHeaderAndCharacters(content);
      if (header == null || header.id == null) continue;

      byStory.putIfAbsent(parsed.storyId, () => []).add((
        path: path,
        chapter: parsed.chapter,
        header: header,
        characters: characters,
      ));
    }

    for (final list in byStory.values) {
      list.sort((a, b) => a.chapter.compareTo(b.chapter));
    }

    final entries = <ChatEntry>[];
    for (final entry in byStory.entries) {
      final storyId = entry.key;
      final chapters = entry.value;
      if (chapters.isEmpty) continue;

      final first = chapters.first;
      final header = first.header;
      final characters = first.characters;
      final meta = header.storyMeta;

      final storyName = meta?.storyName ?? _idToDisplayName(storyId);
      final storyAvatar = meta?.avatar;
      final preview = meta?.preview;

      final firstPath = first.path;
      final chapterScripts = <String, String>{};
      final allThreads = <String, (String name, String entryLabel, String? characterId, List<String>? participantIds)>{};
      for (final ch in chapters) {
        if (ch.header.id != null) {
          chapterScripts[ch.header.id!] = ch.path;
        }
        for (final t in ch.header.threads) {
          allThreads.putIfAbsent(t.id, () => (t.name, t.entryLabel, t.characterId, t.participantIds));
        }
      }

      String? threadAvatar(String? characterId, List<String>? participantIds) {
        if (characterId != null) {
          final c = characters[characterId];
          if (c?.avatar != null) return c!.avatar;
        }
        if (participantIds != null && participantIds.isNotEmpty) {
          for (final pid in participantIds) {
            final c = characters[pid];
            if (c != null && !c.isPlayer && c.avatar != null) return c.avatar;
          }
        }
        return storyAvatar;
      }

      final threads = allThreads.entries.map((e) {
        final t = e.value;
        final avatar = threadAvatar(t.$3, t.$4);
        if (t.$4 != null && t.$4!.isNotEmpty) {
          return ChatThreadDef(
            id: e.key,
            name: t.$1,
            entryLabel: t.$2,
            characterId: t.$3,
            participantIds: t.$4,
            avatarPath: avatar,
          );
        }
        return ChatThreadDef(
          id: e.key,
          name: t.$1,
          entryLabel: t.$2,
          characterId: t.$3,
          avatarPath: avatar,
          participantIds: t.$3 != null ? [t.$3!, 'P'] : null,
        );
      }).toList();

      final mainThread = threads.isNotEmpty ? threads.first : null;
      final mainAvatar = mainThread?.avatarPath ?? storyAvatar;

      entries.add(ChatEntry(
        id: storyId,
        name: mainThread?.name ?? storyName,
        scriptPath: firstPath,
        avatarPath: mainAvatar,
        lastPreview: preview,
        chapterId: storyId,
        chapterScripts: chapterScripts,
        threads: threads.isNotEmpty ? threads : null,
        entryLabel: mainThread?.entryLabel ?? 'start',
      ));
    }

    entries.sort((a, b) => a.id.compareTo(b.id));
    return entries;
  } catch (_) {
    return null;
  }
}

String _idToDisplayName(String id) {
  return id
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());
}
