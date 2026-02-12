// ignore_for_file: avoid_print

/// Run: dart run tool/generate_stories_manifest.dart
///
/// naming convention: {story_id}_{chapter:02d}.awi
/// Legacy: {story_id}.awi (ch1), {story_id}_capN.awi (ch2, ch3...)
library;

import 'dart:convert';
import 'dart:io';

void main() {
  final scriptDir = Directory('assets/scripts');
  if (!scriptDir.existsSync()) {
    print('Directory assets/scripts/ not found.');
    exit(1);
  }

  final awiFiles = scriptDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.awi'))
      .where((f) => !f.path.endsWith('_manifest.json'))
      .map((f) => 'assets/scripts/${f.uri.pathSegments.last}')
      .toList();

  // Sort by story_id then chapter (chronological)
  awiFiles.sort((a, b) {
    final aParsed = _parseFilename(a);
    final bParsed = _parseFilename(b);
    final cmp = aParsed.storyId.compareTo(bParsed.storyId);
    if (cmp != 0) return cmp;
    return aParsed.chapter.compareTo(bParsed.chapter);
  });

  final manifest = {'scripts': awiFiles};
  final json = const JsonEncoder.withIndent('  ').convert(manifest);
  final outFile = File('assets/scripts/_manifest.json');
  outFile.writeAsStringSync(json);

  print('Generated ${outFile.path} with ${awiFiles.length} script(s):');
  for (final s in awiFiles) {
    final p = _parseFilename(s);
    print('  - $s (story: ${p.storyId}, ch: ${p.chapter})');
  }
}

({String storyId, int chapter}) _parseFilename(String path) {
  final name = path.split('/').last.toLowerCase();
  if (name.endsWith('.awi')) {
    final base = name.substring(0, name.length - 4);
    // Format: story_id_01.awi
    final m1 = RegExp(r'^(.+)_(\d{2})$').firstMatch(base);
    if (m1 != null) {
      return (storyId: m1.group(1)!, chapter: int.parse(m1.group(2)!, radix: 10));
    }
    // Legacy: story_id_capN.awi
    final m2 = RegExp(r'^(.+)_cap(\d+)$').firstMatch(base);
    if (m2 != null) {
      return (storyId: m2.group(1)!, chapter: int.parse(m2.group(2)!, radix: 10));
    }
    // Single chapter: story_id.awi
    return (storyId: base, chapter: 1);
  }
  return (storyId: path, chapter: 1);
}
