import '../../models/dialogue_node.dart';
import '../../models/character.dart';
import '../../models/choice.dart';
import 'script_tokenizer.dart';

/// Parses .awn script into a directed graph of DialogueNodes.
/// Each label maps to its first node; nodes are linked by nextNode (id or label).
class ScriptParser {
  final ScriptTokenizer _tokenizer = ScriptTokenizer();

  /// Parse script and return map: nodeId -> DialogueNode.
  /// [definedCharacters]: mapa de personagens (ex: do bloco CHARACTERS). Se o remetente
  /// tem isPlayer, o DialogueNode é criado com isUser = true.
  Map<String, DialogueNode> parse(String script, {Map<String, Character>? definedCharacters}) {
    return _parse(
      tokens: _tokenizer.tokenize(script),
      counter: [0],
      characters: definedCharacters ?? {},
    );
  }

  Map<String, DialogueNode> _parse({
    required List<ScriptToken> tokens,
    required List<int> counter,
    Map<String, Character> characters = const {},
  }) {
    final nodes = <String, DialogueNode>{};
    String nextId() => 'n${counter[0]++}';

    // Current block's chain: last node we added (we'll link the next node to it)
    DialogueNode? chainTail;
    String? currentLabel;

    int i = 0;
    while (i < tokens.length) {
      final t = tokens[i];
      if (t.type == TokenType.label) {
        currentLabel = t.raw.split(RegExp(r'\s')).first;
        chainTail = null;
        i++;
        continue;
      }
      if (t.type == TokenType.comment || t.type == TokenType.empty) { i++; continue; }
      if (t.type == TokenType.end) { chainTail = null; i++; continue; }

      if (t.type == TokenType.speaker) {
        final colonIdx = t.raw.indexOf(':');
        final speaker = t.raw.substring(0, colonIdx).trim();
        final content = t.raw.substring(colonIdx + 1).trim();
        double delay = 0;
        if (i + 1 < tokens.length && tokens[i + 1].type == TokenType.delay) {
          delay = double.tryParse(tokens[i + 1].raw) ?? 0;
          i++;
        }
        final isUser = characters[speaker]?.isPlayer == true; // definedCharacters repassado
        final id = nextId();
        final node = DialogueNode(
          id: id,
          senderId: speaker,
          type: DialogueNodeType.text,
          content: content,
          delay: delay,
          nextNode: null,
          isUser: isUser,
        );
        _linkAndStore(nodes, currentLabel ?? 'start', node, chainTail);
        chainTail = node;
        i++;
        continue;
      }

      if (t.type == TokenType.choice) {
        final choices = <Choice>[];
        while (i < tokens.length && tokens[i].type == TokenType.choice) {
          choices.add(_parseChoice(tokens[i].raw));
          i++;
        }
        if (choices.isEmpty) continue;
        final id = nextId();
        final node = DialogueNode(
          id: id,
          senderId: 'system',
          type: DialogueNodeType.choice,
          content: '',
          choices: choices,
        );
        _linkAndStore(nodes, currentLabel ?? 'start', node, chainTail);
        chainTail = null;
        continue;
      }

      if (t.type == TokenType.ifLine) {
        final cond = t.raw;
        final thenBlock = <ScriptToken>[];
        List<ScriptToken>? elseBlock;
        i++;
        int depth = 1;
        while (i < tokens.length) {
          if (tokens[i].type == TokenType.elseLine && depth == 1) {
            elseBlock = [];
            i++;
            continue;
          }
          if (tokens[i].type == TokenType.endif) {
            depth--;
            if (depth == 0) { i++; break; }
          }
          if (tokens[i].type == TokenType.ifLine) depth++;
          if (depth == 1 && elseBlock == null) thenBlock.add(tokens[i]);
          if (depth == 1 && elseBlock != null) elseBlock.add(tokens[i]);
          i++;
        }
        final thenSub = thenBlock.isEmpty ? '' : '@_then\n${_tokensToScript(thenBlock)}';
        final elseSub = elseBlock != null && elseBlock.isNotEmpty ? '@_else\n${_tokensToScript(elseBlock)}' : null;
        final thenNodes = thenSub.isEmpty ? <String, DialogueNode>{} : _parse(tokens: _tokenizer.tokenize(thenSub), counter: counter, characters: characters);
        final elseNodes = elseSub != null && elseSub.isNotEmpty ? _parse(tokens: _tokenizer.tokenize(elseSub), counter: counter, characters: characters) : <String, DialogueNode>{};
        final thenStart = thenNodes['_then']?.id ?? thenNodes.values.firstOrNull?.id;
        final elseStart = elseNodes['_else']?.id ?? elseNodes.values.firstOrNull?.id;
        final id = nextId();
        final node = DialogueNode(
          id: id,
          senderId: 'system',
          type: DialogueNodeType.system,
          content: '',
          condition: cond,
          nextNode: thenStart,
          metadata: {'branch_else': elseStart},
        );
        _linkAndStore(nodes, currentLabel ?? 'start', node, chainTail);
        for (final e in thenNodes.entries) {
          nodes[e.key] = e.value;
        }
        for (final e in elseNodes.entries) {
          nodes[e.key] = e.value;
        }
        chainTail = null;
        continue;
      }
      i++;
    }

    _resolveAllLabels(nodes);
    return nodes;
  }

  /// Link new node to chain. Store in nodes. Set label entry if this is the first in block.
  void _linkAndStore(Map<String, DialogueNode> nodes, String label, DialogueNode node, DialogueNode? chainTail) {
    if (chainTail != null) {
      final linked = chainTail.copyWith(nextNode: node.id);
      nodes[chainTail.id] = linked;
      if (nodes[label]?.id == chainTail.id) nodes[label] = linked;
    }
    nodes[node.id] = node;
    if (nodes[label] == null) nodes[label] = node;
  }

  String _tokensToScript(List<ScriptToken> list) => list.map((t) => t.raw).join('\n');

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
      effects = rest.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      final arrow = text.indexOf('->');
      if (arrow >= 0) {
        nextNode = text.substring(arrow + 2).trim();
        text = text.substring(0, arrow).trim();
      }
    }
    return Choice(text: text, nextNode: nextNode, effects: effects);
  }

  /// Resolve label strings to node ids. When nextNode is a label (e.g. 'good_path'),
  /// replace it with the id of that label's first node.
  void _resolveAllLabels(Map<String, DialogueNode> nodes) {
    for (final e in nodes.entries.toList()) {
      final n = e.value;
      if (n.nextNode == null || n.nextNode!.isEmpty) continue;
      final target = nodes[n.nextNode!];
      if (target != null && target.id != n.nextNode) {
        nodes[e.key] = n.copyWith(nextNode: target.id);
      }
    }
  }
}
