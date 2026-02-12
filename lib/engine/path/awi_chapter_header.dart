/// Thread definida no script (bloco THREADS). Referência para return_to e trigger.
class ScriptThreadDef {
  final String id;
  final String name;
  final String entryLabel;
  final String? characterId;
  /// IDs explícitos para grupos (ex: Y,P). Quando definido, usa em vez de [characterId].
  final List<String>? participantIds;

  const ScriptThreadDef({
    required this.id,
    required this.name,
    required this.entryLabel,
    this.characterId,
    this.participantIds,
  });
}

/// Story-level metadata (from first chapter's SETTINGS). Used for auto-discovery.
class StoryMeta {
  final String? storyId;
  final String? storyName;
  final String? avatar;
  final String? preview;

  const StoryMeta({
    this.storyId,
    this.storyName,
    this.avatar,
    this.preview,
  });
}

/// Cabeçalho de Inteligência (The Brain) – parsed from SETTINGS block.
/// Define regras de interconectividade entre capítulos.
class AwiChapterHeader {
  final String? id;
  final String? title;
  final String? dependency;
  final List<EntryPointRule> entryPoint;
  final String? pathLock;
  final String? nextChapter;
  final String? requiredFlag;
  /// Threads declaradas no script (bloco THREADS). return_to e trigger usam esses IDs.
  final List<ScriptThreadDef> threads;
  /// Story-level metadata for auto-discovery (story_name, avatar, preview).
  final StoryMeta? storyMeta;

  const AwiChapterHeader({
    this.id,
    this.title,
    this.dependency,
    this.entryPoint = const [],
    this.pathLock,
    this.nextChapter,
    this.requiredFlag,
    this.threads = const [],
    this.storyMeta,
  });

  /// Default start label when no entry_point matches.
  String get defaultStartLabel {
    final elseRule = entryPoint.where((r) => r.isElse).firstOrNull;
    return elseRule?.label ?? 'start';
  }

  /// Parse SETTINGS block lines into header.
  static AwiChapterHeader parseFromLines(List<String> lines) {
    String? id;
    String? title;
    String? dependency;
    final entryPointRules = <EntryPointRule>[];
    String? pathLock;
    String? nextChapter;
    String? requiredFlag;
    String? storyId;
    String? storyName;
    String? avatar;
    String? preview;

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final idx = line.indexOf(':');
      if (idx < 0) {
        i++;
        continue;
      }
      final key = line.substring(0, idx).trim();
      var value = line.substring(idx + 1).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }

      if (key == 'entry_point') {
        i++;
        while (i < lines.length) {
          final sub = lines[i].trim();
          if (sub.startsWith('-')) {
            final content = sub.substring(1).trim();
            if (content.startsWith('if:')) {
              final rest = content.substring(3).trim();
              final arrow = rest.indexOf('->');
              if (arrow >= 0) {
                entryPointRules.add(EntryPointRule(
                  condition: rest.substring(0, arrow).trim(),
                  label: rest.substring(arrow + 2).trim(),
                ));
              }
            } else if (content.startsWith('else:')) {
              entryPointRules.add(EntryPointRule(
                label: content.substring(5).trim(),
                isElse: true,
              ));
            }
          } else if (sub.isNotEmpty && !sub.startsWith('#')) {
            break;
          }
          i++;
        }
        continue;
      }

      switch (key) {
        case 'id':
          id = value;
          break;
        case 'title':
          title = value;
          break;
        case 'dependency':
          dependency = value;
          break;
        case 'path_lock':
          pathLock = value;
          break;
        case 'next_chapter':
          nextChapter = value;
          break;
        case 'required_flag':
          requiredFlag = value;
          break;
        case 'story_id':
          storyId = value;
          break;
        case 'story_name':
          storyName = value;
          break;
        case 'avatar':
          avatar = value;
          break;
        case 'preview':
          preview = value;
          break;
        case 'linear_path':
          break;
        default:
          break;
      }
      i++;
    }

    final storyMeta = (storyId != null || storyName != null || avatar != null || preview != null)
        ? StoryMeta(storyId: storyId, storyName: storyName, avatar: avatar, preview: preview)
        : null;

    return AwiChapterHeader(
      id: id,
      title: title,
      dependency: dependency,
      entryPoint: entryPointRules,
      pathLock: pathLock,
      nextChapter: nextChapter,
      requiredFlag: requiredFlag,
      storyMeta: storyMeta,
    );
  }

  /// Cria header com threads (chamado pelo parser ao encontrar bloco THREADS).
  AwiChapterHeader copyWithThreads(List<ScriptThreadDef> threads) {
    return AwiChapterHeader(
      id: id,
      title: title,
      dependency: dependency,
      entryPoint: entryPoint,
      pathLock: pathLock,
      nextChapter: nextChapter,
      requiredFlag: requiredFlag,
      threads: threads,
      storyMeta: storyMeta,
    );
  }

  /// Parse THREADS block lines. Formato: id: nome | entry | character_id ou participant_ids
  /// Se 3ª parte tem vírgula (ex: Y,P) = participantIds. Se letra única (ex: S) = characterId.
  static List<ScriptThreadDef> parseThreadsFromLines(List<String> lines) {
    final result = <ScriptThreadDef>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final colon = t.indexOf(':');
      if (colon < 0) continue;
      final id = t.substring(0, colon).trim();
      final rest = t.substring(colon + 1).trim();
      if (id.isEmpty) continue;
      final parts = rest.split('|').map((s) => s.trim()).toList();
      final name = parts.isNotEmpty ? parts[0] : id;
      final entry = parts.length > 1 ? parts[1] : 'start';
      final extra = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
      String? characterId;
      List<String>? participantIds;
      if (extra != null) {
        if (extra.contains(',')) {
          participantIds = extra.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        } else {
          characterId = extra;
        }
      }
      result.add(ScriptThreadDef(id: id, name: name, entryLabel: entry, characterId: characterId, participantIds: participantIds));
    }
    return result;
  }
}

/// Regra de ponto de entrada: condição -> label.
class EntryPointRule {
  final String? condition;
  final String label;
  final bool isElse;

  const EntryPointRule({
    this.condition,
    required this.label,
    this.isElse = false,
  });
}
