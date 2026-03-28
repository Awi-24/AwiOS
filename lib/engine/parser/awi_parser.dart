import '../path/awi_chapter_header.dart';
import '../../models/dialogue_node.dart';
import '../../models/choice.dart';
import '../../models/character.dart';

/// Parser para formato .awi – blocos [label], pares chave:valor.
/// Arquitetura: blocos → pares K:V → DialogueNodes + Characters.
class AwiParser {
  /// Lightweight parse: only extracts SETTINGS + THREADS. Use for story metadata discovery.
  AwiChapterHeader? parseHeaderOnly(String script) {
    final result = parseHeaderAndCharacters(script);
    return result.$1;
  }

  /// Parses SETTINGS, THREADS, and CHARACTERS for story/thread metadata and avatars.
  /// Returns (header, characters). Use for chat list avatar resolution.
  (AwiChapterHeader?, Map<String, Character>) parseHeaderAndCharacters(String script) {
    final blocks = _splitBlocks(script);
    AwiChapterHeader? header;
    final characters = <String, Character>{};

    for (final block in blocks) {
      if (block.name == 'SETTINGS') {
        header = AwiChapterHeader.parseFromLines(block.lines);
        continue;
      }
      if (block.name == 'THREADS' && header != null) {
        header = header.copyWithThreads(AwiChapterHeader.parseThreadsFromLines(block.lines));
        continue;
      }
      if (block.name == 'CHARACTERS') {
        for (final line in block.lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final isPlayer = trimmed.toUpperCase().startsWith('[PLAYER]');
          final content = isPlayer ? trimmed.substring(8).trim() : trimmed;
          final m = RegExp(r'^([A-Za-z0-9_]+):\s*(.+?)(?:\s*\(#([A-Fa-f0-9]{6})\))?(?:\s*\[(.+)\])?$').firstMatch(content);
          if (m != null) {
            final bracket = m.group(4)?.trim().toLowerCase();
            final bracketIsPlayer = bracket == 'player';
            final avatar = (bracket != null && !bracketIsPlayer) ? m.group(4)!.trim() : null;
            characters[m.group(1)!] = Character(
              id: m.group(1)!,
              name: m.group(2)!.trim(),
              bubbleColor: m.group(3) != null ? int.parse('FF${m.group(3)}', radix: 16) : 0xFF007AFF,
              avatar: avatar,
              isPlayer: isPlayer || bracketIsPlayer,
            );
          }
        }
      }
    }
    return (header, characters);
  }

  AwiParseResult parse(String script) {
    final characters = <String, Character>{};
    final nodes = <String, DialogueNode>{};
    int nodeCounter = 0;
    String nextId() => 'n${nodeCounter++}';

    final blocks = _splitBlocks(script);
    AwiChapterHeader? header;

    for (final block in blocks) {
      if (block.name == 'SETTINGS') {
        header = AwiChapterHeader.parseFromLines(block.lines);
        continue;
      }
      if (block.name == 'THREADS' && header != null) {
        header = header.copyWithThreads(AwiChapterHeader.parseThreadsFromLines(block.lines));
        continue;
      }
      if (block.name == 'CHARACTERS') {
        for (final line in block.lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final isPlayer = trimmed.toUpperCase().startsWith('[PLAYER]');
          final content = isPlayer ? trimmed.substring(8).trim() : trimmed;
          final m = RegExp(r'^([A-Za-z0-9_]+):\s*(.+?)(?:\s*\(#([A-Fa-f0-9]{6})\))?(?:\s*\[(.+)\])?$').firstMatch(content);
          if (m != null) {
            final bracket = m.group(4)?.trim().toLowerCase();
            // [player] in brackets = isPlayer; [path] = avatar
            final bracketIsPlayer = bracket == 'player';
            final avatar = (bracket != null && !bracketIsPlayer) ? m.group(4)!.trim() : null;
            characters[m.group(1)!] = Character(
              id: m.group(1)!,
              name: m.group(2)!.trim(),
              bubbleColor: m.group(3) != null ? int.parse('FF${m.group(3)}', radix: 16) : 0xFF007AFF,
              avatar: avatar,
              isPlayer: isPlayer || bracketIsPlayer,
            );
          }
        }
      }
    }

    DialogueNode? chainTail;
    for (final block in blocks) {
      if (block.name.startsWith('[') || !RegExp(r'^[a-zA-Z_]').hasMatch(block.name)) continue;
      if (block.name == 'SETTINGS' || block.name == 'CHARACTERS') continue;

      // Cada bloco [label] é independente. Nunca encadear ao bloco anterior.
      chainTail = null;

      final label = block.name;
      final data = _parseBlockData(block.lines);
      final type = data['type'] ?? 'chat';

      // finish-only blocks: type: finish or cmd. For type: chat + next_chapter, process dialogue first.
      if (type == 'finish' || data['cmd'] != null || (data['next_chapter'] != null && type != 'chat')) {
        final nextCh = data['next_chapter'] ?? _parseFinishChapterNext(data['cmd']);
        if (nextCh != null && nextCh.isNotEmpty) {
          final node = DialogueNode(
            id: nextId(),
            senderId: 'system',
            type: DialogueNodeType.system,
            metadata: {'finish_chapter': {'next': nextCh}},
          );
          _linkAndStore(nodes, label, node, chainTail);
        }
        chainTail = null;
        continue;
      }

      if (type == 'choice') {
        final choices = <Choice>[];
        for (final line in block.lines) {
          if (line.trim().startsWith('>')) {
            choices.add(_parseChoice(line.trim().substring(1).trim()));
          }
        }
        if (choices.isNotEmpty) {
          final node = DialogueNode(id: nextId(), senderId: 'system', type: DialogueNodeType.choice, choices: choices);
          _linkAndStore(nodes, label, node, chainTail);
          chainTail = null;
        }
      } else {
        String? lastNext;
        double lastDelay = 0;
        String? lastImage;
        String? lastVideo;
        String? lastTrigger;
        String? lastReturnTo;
        String? condition;
        String? firstDialogueId;
        final unlockGalleryPaths = <String>[];

        for (final line in block.lines) {
          final kv = _parseKeyValue(line.trim());
          if (kv == null) continue;
          final (k, v) = kv;
          if (k == 'type') continue;
          if (k == 'next_chapter') continue; // Handled after chat content
          if (k == 'next') { lastNext = v; continue; }
          if (k == 'delay') { lastDelay = double.tryParse(v) ?? 0; continue; }
          if (k == 'image') { lastImage = v; continue; }
          if (k == 'video') { lastVideo = v; continue; }
          if (k == 'trigger') { lastTrigger = v; continue; }
          if (k == 'return_to') { lastReturnTo = v; continue; }
          if (k == 'condition') { condition = v; continue; }
          if (k == 'unlock_gallery') {
            unlockGalleryPaths.add(v.startsWith('assets/') ? v : 'assets/$v');
            continue;
          }
          if (k == 'system' && v.isNotEmpty) {
            final parsed = _parseSystemCommand(v);
            if (parsed != null) {
              final node = DialogueNode(
                id: nextId(),
                senderId: 'system',
                type: DialogueNodeType.system,
                content: '',
                metadata: {'system_action': true, 'command': parsed.$1, 'params': parsed.$2},
                nextNode: null,
              );
              _linkAndStore(nodes, label, node, chainTail);
              chainTail = node;
            }
            continue;
          }
          if (k.length <= 3 && RegExp(r'^[A-Za-z0-9_]+$').hasMatch(k) && v.isNotEmpty) {
            final isUser = characters[k]?.isPlayer == true;
            final meta = <String, dynamic>{};
            if (lastImage != null) meta['image'] = lastImage;
            if (lastVideo != null) meta['video'] = lastVideo;
            if (lastTrigger != null) meta['trigger_thread'] = lastTrigger;
            final node = DialogueNode(
              id: nextId(),
              senderId: k,
              type: DialogueNodeType.text,
              content: v,
              delay: lastDelay,
              nextNode: null,
              metadata: meta.isEmpty ? null : meta,
              isUser: isUser,
            );
            firstDialogueId ??= node.id;
            _linkAndStore(nodes, label, node, chainTail);
            chainTail = node;
            lastDelay = 0;
            lastImage = null;
            lastVideo = null;
            lastTrigger = null;
            // lastReturnTo não é resetado – é diretiva de bloco
          }
        }
        final nextCh = data['next_chapter'];
        if (chainTail != null && nextCh != null && nextCh.isNotEmpty) {
          final finishNode = DialogueNode(
            id: nextId(),
            senderId: 'system',
            type: DialogueNodeType.system,
            metadata: {'finish_chapter': {'next': nextCh}},
          );
          _linkAndStore(nodes, label, finishNode, chainTail);
          chainTail = finishNode;
        }
          if (chainTail != null && lastNext != null && nextCh == null) {
          final tail = chainTail;
          final meta = Map<String, dynamic>.from(tail.metadata ?? {});
          if (lastImage != null) meta['image'] = lastImage;
          if (lastVideo != null) meta['video'] = lastVideo;
          if (lastTrigger != null) meta['trigger_thread'] = lastTrigger;
          final updated = tail.copyWith(nextNode: lastNext, metadata: meta.isEmpty ? null : meta);
          nodes[tail.id] = updated;
          if (nodes[label]?.id == tail.id) nodes[label] = updated;
        } else if (chainTail != null && (lastImage != null || lastVideo != null || lastTrigger != null)) {
          final tail = chainTail;
          final meta = Map<String, dynamic>.from(tail.metadata ?? {});
          if (lastImage != null) meta['image'] = lastImage;
          if (lastVideo != null) meta['video'] = lastVideo;
          if (lastTrigger != null) meta['trigger_thread'] = lastTrigger;
          final updated = tail.copyWith(metadata: meta);
          nodes[tail.id] = updated;
          if (nodes[label]?.id == tail.id) nodes[label] = updated;
        }
        if (lastReturnTo != null && chainTail != null) {
          DialogueNode? first = condition != null ? (firstDialogueId != null ? nodes[firstDialogueId] : null) : nodes[label];
          first ??= chainTail;
          DialogueNode? n = first;
          while (n != null) {
            final meta = Map<String, dynamic>.from(n.metadata ?? {});
            meta['return_to_thread'] = lastReturnTo;
            final updated = n.copyWith(metadata: meta);
            nodes[n.id] = updated;
            if (nodes[label]?.id == n.id) nodes[label] = updated;
            if (n.id == chainTail.id) break;
            n = n.nextNode != null ? nodes[n.nextNode!] : null;
          }
        }
        if (chainTail != null && unlockGalleryPaths.isNotEmpty) {
          final tail = nodes[chainTail.id] ?? chainTail;
          final effects = [...?tail.effects, ...unlockGalleryPaths.map((p) => 'UNLOCK_MEDIA: $p')];
          final updated = tail.copyWith(effects: effects);
          nodes[chainTail.id] = updated;
          if (nodes[label]?.id == chainTail.id) nodes[label] = updated;
        }
        if (condition != null) {
          final condNode = DialogueNode(
            id: nextId(),
            senderId: 'system',
            type: DialogueNodeType.system,
            condition: condition,
            nextNode: firstDialogueId ?? lastNext,
            metadata: lastNext != null ? {'branch_else': lastNext} : null,
          );
          _linkAndStore(nodes, label, condNode, null);
          nodes[label] = condNode; // condition must be entry point for path branching
          chainTail = null;
        }
      }
    }

    _resolveAllLabels(nodes);
    return AwiParseResult(nodes: nodes, characters: characters, header: header);
  }

  List<_Block> _splitBlocks(String script) {
    final blocks = <_Block>[];
    String currentName = '';
    final currentLines = <String>[];

    for (final line in script.split('\n')) {
      final t = line.trim();
      if (t.startsWith('#')) continue;
      if (t == 'SETTINGS' || t == 'CHARACTERS' || t == 'THREADS') {
        if (currentName.isNotEmpty) blocks.add(_Block(currentName, List.from(currentLines)));
        currentName = t;
        currentLines.clear();
        continue;
      }
      // Só considera bloco quando a linha é EXATAMENTE [label] (evita "[Player] M: ..." virar bloco)
      if (RegExp(r'^\[\w+\]$').hasMatch(t)) {
        if (currentName.isNotEmpty) blocks.add(_Block(currentName, List.from(currentLines)));
        currentName = t.substring(1, t.length - 1).trim();
        currentLines.clear();
        continue;
      }
      if (currentName.isNotEmpty) currentLines.add(line);
    }
    if (currentName.isNotEmpty) blocks.add(_Block(currentName, List.from(currentLines)));
    return blocks;
  }

  Map<String, String> _parseBlockData(List<String> lines) {
    final data = <String, String>{};
    for (final line in lines) {
      final kv = _parseKeyValue(line.trim());
      if (kv != null) data[kv.$1] = kv.$2;
    }
    return data;
  }

  (String, String)? _parseKeyValue(String line) {
    final idx = line.indexOf(':');
    if (idx < 0) return null;
    return (line.substring(0, idx).trim(), line.substring(idx + 1).trim());
  }

  /// Parse system: command(param="val", ...). Retorna (command, params) ou null.
  (String, Map<String, String>)? _parseSystemCommand(String raw) {
    final trimmed = raw.trim();
    final openParen = trimmed.indexOf('(');
    if (openParen < 0) return null;
    final cmd = trimmed.substring(0, openParen).trim();
    if (cmd.isEmpty) return null;
    final rest = trimmed.substring(openParen + 1);
    final closeParen = rest.lastIndexOf(')');
    if (closeParen < 0) return null;
    final paramsStr = rest.substring(0, closeParen);
    final params = <String, String>{};
    for (final part in paramsStr.split(',')) {
      final t = part.trim();
      final eq = t.indexOf('=');
      if (eq > 0) {
        final key = t.substring(0, eq).trim();
        var val = t.substring(eq + 1).trim();
        if (val.startsWith('"') && val.endsWith('"')) val = val.substring(1, val.length - 1);
        if (val.startsWith("'") && val.endsWith("'")) val = val.substring(1, val.length - 1);
        params[key] = val;
      }
    }
    return (cmd, params);
  }

  /// Extrai next= do cmd finish_chapter(result="X", next="Y").
  String? _parseFinishChapterNext(String? cmd) {
    if (cmd == null || cmd.isEmpty) return null;
    var m = RegExp(r'next\s*=\s*"([^"]+)"').firstMatch(cmd);
    m ??= RegExp(r"next\s*=\s*'([^']+)'").firstMatch(cmd);
    return m?.group(1)?.trim();
  }

  Choice _parseChoice(String raw) {
    final brace = raw.indexOf('{');
    String text = raw.trim();
    String nextNode = 'next';
    List<String>? effects;
    if (brace >= 0) {
      text = raw.substring(0, brace).trim();
      final rest = raw.substring(brace + 1, raw.lastIndexOf('}')).trim();
      final arrow = text.indexOf('->');
      if (arrow >= 0) {
        nextNode = text.substring(arrow + 2).trim();
        text = text.substring(0, arrow).trim();
      }
      effects = rest.split(',').map((e) {
        final s = e.trim();
        if (s.contains('+') && !s.contains('+=')) return s.replaceFirst(RegExp(r'\s*\+\s*'), ' += ');
        if (s.contains(':') && !s.contains('=')) return s.replaceFirst(':', ' = ');
        return s;
      }).where((e) => e.isNotEmpty).toList();
    } else {
      final arrow = text.indexOf('->');
      if (arrow >= 0) {
        nextNode = text.substring(arrow + 2).trim();
        text = text.substring(0, arrow).trim();
      }
    }
    return Choice(text: text, nextNode: nextNode, effects: effects);
  }

  void _linkAndStore(Map<String, DialogueNode> nodes, String label, DialogueNode node, DialogueNode? chainTail) {
    if (chainTail != null) {
      final linked = chainTail.copyWith(nextNode: node.id);
      nodes[chainTail.id] = linked;
      if (nodes[label]?.id == chainTail.id) nodes[label] = linked;
    }
    nodes[node.id] = node;
    if (nodes[label] == null) nodes[label] = node;
  }

  void _resolveAllLabels(Map<String, DialogueNode> nodes) {
    for (final e in nodes.entries.toList()) {
      final n = e.value;
      if (n.nextNode == null || n.nextNode!.isEmpty) continue;
      var target = nodes[n.nextNode!];
      if (target == null) {
        for (final entry in nodes.entries) {
          if (entry.key == n.nextNode) {
            target = entry.value;
            break;
          }
        }
      }
      if (target != null && target.id != n.nextNode) {
        nodes[e.key] = n.copyWith(nextNode: target.id);
      }
    }
  }
}

class _Block {
  final String name;
  final List<String> lines;
  _Block(this.name, this.lines);
}

class AwiParseResult {
  final Map<String, DialogueNode> nodes;
  final Map<String, Character> characters;
  final AwiChapterHeader? header;

  AwiParseResult({required this.nodes, required this.characters, this.header});
}
