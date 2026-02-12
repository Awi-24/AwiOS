import 'dart:async';

import '../../models/dialogue_node.dart';
import '../../models/choice.dart';
import '../../models/game_state.dart';
import '../../models/character.dart';
import '../parser/awi_parser.dart';
import '../parser/awn_parser.dart';
import '../path/awi_path_analizer.dart';
import '../path/awi_chapter_header.dart';
import '../evaluator/condition_evaluator.dart';
import '../evaluator/effect_applier.dart';
import '../../models/save_data.dart';
import '../../core/system_bus.dart';
import '../../core/system_command_registry.dart';
import '../../core/awi_engine_context.dart';
import '../../core/effect_registry.dart';
import '../progress/progress_manager.dart';
import '../save/save_manager.dart';

/// Main runtime engine. Otimizado para .awi (script + eventos OS).
/// .awn é formato legado diferente; usado apenas quando .awi não é detectado.
class AwiEngine {
  final ConditionEvaluator _conditionEvaluator = ConditionEvaluator();
  final EffectApplier _effectApplier = EffectApplier();
  final AwiParser _awiParser = AwiParser();
  final AwnParser _awnParser = AwnParser();
  final AwiPathAnalizer _pathAnalizer = AwiPathAnalizer();
  final SaveManager saveManager;
  final ProgressManager? progressManager;

  /// Registry modular para system: commands. Novos comandos podem ser registrados.
  final SystemCommandRegistry systemCommandRegistry;
  /// Registry modular para efeitos de escolhas. Novos prefixos podem ser registrados.
  final EffectRegistry effectRegistry;

  AwiEngine({
    SaveManager? saveManager,
    this.progressManager,
    SystemCommandRegistry? systemCommandRegistry,
    EffectRegistry? effectRegistry,
  })  : saveManager = saveManager ?? MemorySaveManager(),
        systemCommandRegistry =
            systemCommandRegistry ?? SystemCommandHandlers.createDefault(),
        effectRegistry = effectRegistry ?? _createDefaultEffectRegistry();

  static EffectRegistry _createDefaultEffectRegistry() {
    final r = EffectRegistry();
    EffectHandlers.registerDefaults(r);
    return r;
  }

  Map<String, DialogueNode>? _nodes;
  Map<String, Character> _characters = {};
  AwiChapterHeader? _chapterHeader;
  String? _currentNodeId;
  String? _currentChapterId;
  final GameState _state = GameState();
  final List<DialogueNode> _history = [];
  final Set<String> _unlockedMedia = {};

  final StreamController<DialogueNode> _messageController = StreamController<DialogueNode>.broadcast();
  final StreamController<List<Choice>> _choicesController = StreamController<List<Choice>>.broadcast();
  final StreamController<GameState> _stateController = StreamController<GameState>.broadcast();
  final StreamController<ChapterCompleteEvent> _chapterCompleteController = StreamController<ChapterCompleteEvent>.broadcast();
  final StreamController<ThreadTriggerEvent> _threadTriggerController = StreamController<ThreadTriggerEvent>.broadcast();
  final StreamController<ReturnToThreadEvent> _returnToThreadController = StreamController<ReturnToThreadEvent>.broadcast();

  Stream<DialogueNode> get onMessage => _messageController.stream;
  Stream<List<Choice>> get onChoices => _choicesController.stream;
  Stream<GameState> get onStateChanged => _stateController.stream;
  Stream<ChapterCompleteEvent> get onChapterComplete => _chapterCompleteController.stream;
  Stream<ThreadTriggerEvent> get onThreadTrigger => _threadTriggerController.stream;
  Stream<ReturnToThreadEvent> get onReturnToThread => _returnToThreadController.stream;

  GameState get state => _state;
  List<DialogueNode> get history => List.unmodifiable(_history);
  List<DialogueNode> get displayableHistory =>
      _history.where(_isDisplayableMessage).toList();
  Set<String> get unlockedMedia => Set.unmodifiable(_unlockedMedia);
  String? get currentNodeId => _currentNodeId;
  Map<String, Character> get characters => Map.unmodifiable(_characters);

  /// ID do personagem marcado como jogador em CHARACTERS ([Player]).
  String? get playerCharacterId {
    for (final e in _characters.entries) {
      if (e.value.isPlayer) return e.key;
    }
    return null;
  }

  void addUnlockedMedia(String path) {
    final p = path.startsWith('assets/') ? path : 'assets/$path';
    _unlockedMedia.add(p);
    SystemBus.emit(SystemEvent(command: 'unlock', params: {'app': 'gallery', 'id': p}));
  }

  /// Carrega script .awi (primário) ou .awn (legado). Chamar [start] após.
  /// .awi: SETTINGS, CHARACTERS, blocos [label], system:, eventos OS.
  /// .awn: formato legado @labels, sem system:; usado quando .awi não é detectado.
  void loadScript(String script, {String? chapterId}) {
    if (_isAwiFormat(script)) {
      loadAwiScript(script, chapterId: chapterId);
    } else {
      loadAwnScript(script, chapterId: chapterId);
    }
  }

  bool _isAwiFormat(String script) =>
      script.contains('SETTINGS') ||
      script.contains('CHARACTERS') ||
      RegExp(r'^\[[\w]+\]', multiLine: true).hasMatch(script);

  /// Carrega script .awi (format completo com eventos OS).
  void loadAwiScript(String script, {String? chapterId}) {
    final result = _awiParser.parse(script);
    _nodes = result.nodes;
    _characters = result.characters;
    _chapterHeader = result.header;
    _currentNodeId = null;
    _currentChapterId = chapterId;
    _history.clear();
  }

  /// Carrega script .awn (legado, sem SETTINGS/system:).
  void loadAwnScript(String script, {String? chapterId}) {
    _nodes = _awnParser.parse(script);
    _characters = <String, Character>{};
    _chapterHeader = null;
    _currentNodeId = null;
    _currentChapterId = chapterId;
    _history.clear();
  }

  /// Verifica se o capítulo atual pode ser iniciado (dependency, required_flag).
  bool canStartChapter() {
    if (_chapterHeader == null || progressManager == null) return true;
    return _pathAnalizer.canStartChapter(
      _chapterHeader!,
      progressManager!,
      sessionState: _state,
    );
  }

  /// Verifica se um script pode ser iniciado sem carregá-lo. Use antes de loadScript.
  bool canStartChapterForScript(String script) {
    if (progressManager == null) return true;
    final header = _pathAnalizer.parseHeader(script);
    return _pathAnalizer.canStartChapter(
      header,
      progressManager!,
      sessionState: _state,
    );
  }

  /// Start from label (default 'start'). Use [bridgeRules] for chapter transitions.
  /// When .awi has SETTINGS with entry_point/dependency, AwiPathAnalizer resolves the start.
  /// [forceLabel] quando true: usa o label diretamente (ex: threads como sammy_conversa), ignorando entry_point.
  void start({
    String label = 'start',
    Map<String, Map<String, String>>? bridgeRules,
    String? dependencyChapterId,
    bool forceLabel = false,
  }) {
    if (_nodes == null) return;
    String resolvedLabel = label;

    if (!forceLabel) {
      if (_chapterHeader != null && progressManager != null) {
        final h = _chapterHeader!;
        if (h.entryPoint.isNotEmpty) {
          resolvedLabel = _pathAnalizer.resolveStartNode(
            h,
            progressManager!,
            sessionState: _state,
            defaultStart: label,
          );
        } else if (bridgeRules != null &&
            dependencyChapterId != null &&
            _currentChapterId != null) {
          resolvedLabel = progressManager!.resolveStartNode(
            chapterId: _currentChapterId!,
            defaultStart: label,
            bridgeRules: bridgeRules,
            dependencyChapterId: dependencyChapterId,
          );
        }
      } else if (bridgeRules != null &&
          dependencyChapterId != null &&
          _currentChapterId != null &&
          progressManager != null) {
        resolvedLabel = progressManager!.resolveStartNode(
          chapterId: _currentChapterId!,
          defaultStart: label,
          bridgeRules: bridgeRules,
          dependencyChapterId: dependencyChapterId,
        );
      }
    }
    final first = _nodes![resolvedLabel];
    if (first == null) {
      // ignore: avoid_print
      print('AwiEngine: start failed - resolvedLabel=$resolvedLabel not in nodes');
      return;
    }
    _currentNodeId = first.id;
    _stateController.add(_state.copy());
    _processCurrent();
  }

  /// Process current node (user tapped to advance). Do not skip: process current, then advance.
  void next() {
    _processCurrent();
  }

  /// Choose an option. Adds player message to history, applies effects, jumps to choice.nextNode.
  void choose(Choice choice) {
    // Adiciona mensagem da escolha ao histórico para persistir no save/load
    final playerId = playerCharacterId ?? 'player';
    final choiceNode = DialogueNode(
      id: 'choice_${DateTime.now().millisecondsSinceEpoch}',
      senderId: playerId,
      type: DialogueNodeType.text,
      content: choice.text,
      isUser: true,
    );
    _nodes ??= {};
    _nodes![choiceNode.id] = choiceNode;
    _history.add(choiceNode);

    if (choice.effects != null) {
      _applyEffects(choice.effects!);
    }
    _stateController.add(_state.copy());
    _currentNodeId = _resolveLabel(choice.nextNode);
    _choicesController.add([]);
    _processCurrent();
  }

  void _applyEffects(List<String> effects) {
    final effectCtx = EffectContext(
      currentChapterId: _currentChapterId,
      addUnlockedMedia: addUnlockedMedia,
      recordChapterPath: progressManager != null
          ? (c, p) => progressManager!.recordChapterPath(c, p)
          : null,
      sessionState: _state,
    );
    final rest = <String>[];
    for (final e in effects) {
      final s = e.trim();
      if (!effectRegistry.tryApplyPrefix(s, effectCtx)) {
        rest.add(e);
        progressManager?.applyToGlobalFlags([s]);
      }
    }
    if (rest.isNotEmpty) _effectApplier.applyAll(rest, _state);
  }

  void _unlockMediaFromNode(DialogueNode node) {
    final path = node.metadata?['media'] ?? node.metadata?['image'] ?? (node.type == DialogueNodeType.image ? node.content : null);
    if (path != null && path is String) addUnlockedMedia(path);
  }

  /// Registra o path tomado ao terminar um capítulo (Bridge para o próximo).
  void recordChapterPath(String pathOrNodeId) {
    if (_currentChapterId != null) {
      progressManager?.recordChapterPath(_currentChapterId!, pathOrNodeId);
    }
  }

  /// Retorna ao ponto de uma mensagem (clique direito).
  /// Trunca o histórico até esse nó e define o próximo como atual.
  bool jumpToNode(String nodeId) {
    if (_nodes == null) return false;
    final node = _nodes![nodeId];
    if (node == null) return false;
    final idx = _history.indexWhere((n) => n.id == nodeId);
    if (idx < 0) return false;
    _history.removeRange(idx + 1, _history.length);
    final nextId = node.nextNode;
    if (nextId != null && nextId.isNotEmpty) {
      _currentNodeId = _resolveLabel(nextId);
    } else {
      _currentNodeId = null;
    }
    _stateController.add(_state.copy());
    return true;
  }

  /// Reseta saves e progresso (para reset de histórico).
  Future<void> resetAll() async {
    await saveManager.clearAll();
    progressManager?.reset();
    _nodes = null;
    _currentNodeId = null;
    _currentChapterId = null;
    _history.clear();
    _unlockedMedia.clear();
  }

  Future<void> save(int slot) async {
    final data = buildSaveData(
      currentNodeId: _currentNodeId,
      state: _state,
      history: _history,
      unlockedMedia: _unlockedMedia.toList(),
      currentChapterId: _currentChapterId,
      progressManager: progressManager,
    );
    await saveManager.save(slot, data);
  }

  Future<bool> load(int slot) async {
    final data = await saveManager.load(slot);
    if (data == null) return false;
    return applyLoadData(data);
  }

  /// Aplica SaveData sem re-emitir mensagens. Restaura estado e histórico.
  bool applyLoadData(SaveData data) {
    applySaveData(data, _state);
    progressManager?.fromJson({
      'globalFlags': data.globalFlagsJson,
      'chapterHistory': data.chapterHistory.toJson(),
    });
    _unlockedMedia.clear();
    _unlockedMedia.addAll(data.unlockedMedia);
    _currentNodeId = data.currentNode;
    _currentChapterId = data.currentChapterId;
    _history.clear();
    if (_nodes != null) {
      for (final entry in data.choiceNodesJson.entries) {
        try {
          final node = DialogueNode.fromJson(entry.value);
          _nodes![node.id] = node;
        } catch (_) {}
      }
      for (final id in data.history) {
        final node = _nodes![id];
        if (node != null) _history.add(node);
      }
    }
    _stateController.add(_state.copy());
    return true;
  }

  /// Constrói SaveData do estado atual (para persistência por chat).
  SaveData buildCurrentSaveData() {
    return buildSaveData(
      currentNodeId: _currentNodeId,
      state: _state,
      history: _history,
      unlockedMedia: _unlockedMedia.toList(),
      currentChapterId: _currentChapterId,
      progressManager: progressManager,
    );
  }

  void _executeSystemCommand(String cmd, Map<String, dynamic> params) {
    final p = params.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    final event = SystemEvent(command: cmd, params: p);
    SystemBus.emit(event);
    final ctx = AwiEngineContext(
      currentChapterId: _currentChapterId,
      addUnlockedMedia: addUnlockedMedia,
      recordChapterPath: progressManager != null
          ? (c, p) => progressManager!.recordChapterPath(c, p)
          : null,
      applyToGlobalFlags: progressManager != null
          ? (e) => progressManager!.applyToGlobalFlags(e)
          : null,
    );
    systemCommandRegistry.execute(event, ctx);
  }

  bool _isDisplayableMessage(DialogueNode node) {
    if (node.type == DialogueNodeType.system) return false;
    if (node.type == DialogueNodeType.choice) return false;
    return node.content.isNotEmpty || node.type == DialogueNodeType.image;
  }

  String? _resolveLabel(String idOrLabel) {
    if (_nodes == null) return null;
    final n = _nodes![idOrLabel];
    if (n != null) return n.id;
    return idOrLabel;
  }

  /// Process one node at a time: emit one message (or show choices) then stop.
  /// User taps to call next() for the next message.
  void _processCurrent() {
    if (_nodes == null || _currentNodeId == null) return;
    DialogueNode? node = _nodes![_currentNodeId];
    // Se o nó não existe (label quebrado ou script incompleto), limpa para não travar
    if (node == null) {
      _currentNodeId = null;
      return;
    }
    while (node != null) {
      if (node.condition != null && node.condition!.isNotEmpty) {
        if (!_conditionEvaluator.evaluate(node.condition!, _state)) {
          final elseLabel = node.metadata?['branch_else'] as String?;
          if (elseLabel != null) {
            _currentNodeId = _resolveLabel(elseLabel);
            node = _currentNodeId != null ? _nodes![_currentNodeId] : null;
            continue;
          }
          _currentNodeId = null;
          return;
        }
      }
      if (node.type == DialogueNodeType.choice && node.choices != null) {
        final available = node.choices!
            .where((c) => c.condition == null || c.condition!.isEmpty || _conditionEvaluator.evaluate(c.condition!, _state))
            .toList();
        if (available.isNotEmpty) {
          _choicesController.add(available);
          return;
        }
      }
      // system: commands – execução silenciosa, sem bolha
      final systemAction = node.metadata?['system_action'] == true;
      final cmd = node.metadata?['command'] as String?;
      final params = node.metadata?['params'] as Map<String, dynamic>?;
      if (systemAction && cmd != null && params != null) {
        _executeSystemCommand(cmd, params);
        final nextId = node.nextNode;
        if (nextId == null || nextId.isEmpty) {
          _currentNodeId = null;
          return;
        }
        _currentNodeId = _resolveLabel(nextId);
        node = _currentNodeId != null ? _nodes![_currentNodeId] : null;
        continue;
      }
      _history.add(node);
      _unlockMediaFromNode(node);
      if (_isDisplayableMessage(node)) {
        _messageController.add(node);
      }
      if (node.effects != null) _applyEffects(node.effects!);
      _stateController.add(_state.copy());

      final finish = node.metadata?['finish_chapter'];
      if (finish is Map && _currentChapterId != null) {
        final nextCh = (finish['next'] ?? _chapterHeader?.nextChapter)?.toString();
        if (nextCh != null && nextCh.isNotEmpty) {
          _chapterCompleteController.add(ChapterCompleteEvent(
            currentChapterId: _currentChapterId!,
            nextChapterId: nextCh,
          ));
        }
        _currentNodeId = null;
        return;
      }

      final triggerThread = node.metadata?['trigger_thread'] as String?;
      if (triggerThread != null && triggerThread.isNotEmpty) {
        _threadTriggerController.add(ThreadTriggerEvent(threadId: triggerThread));
      }

      final returnToThread = node.metadata?['return_to_thread'] as String?;
      if (returnToThread != null && returnToThread.isNotEmpty) {
        _returnToThreadController.add(ReturnToThreadEvent(threadId: returnToThread));
      }

      if (node.type == DialogueNodeType.choice) {
        next();
        return;
      }
      final nextId = node.nextNode;
      if (nextId == null || nextId.isEmpty) {
        _currentNodeId = null;
        return;
      }
      _currentNodeId = _resolveLabel(nextId);
      node = _currentNodeId != null ? _nodes![_currentNodeId] : null;
      break;
    }
  }

  void dispose() {
    _messageController.close();
    _choicesController.close();
    _stateController.close();
    _chapterCompleteController.close();
    _threadTriggerController.close();
    _returnToThreadController.close();
  }
}

/// Emitido quando o script dispara trigger: thread_id (nova conversa no mesmo arquivo).
class ThreadTriggerEvent {
  final String threadId;

  const ThreadTriggerEvent({required this.threadId});
}

/// Emitido quando o script dispara return_to: thread_id (voltar para chat principal após thread).
class ReturnToThreadEvent {
  final String threadId;

  const ReturnToThreadEvent({required this.threadId});
}

/// Emitido quando um capítulo termina e o próximo deve ser carregado.
class ChapterCompleteEvent {
  final String currentChapterId;
  final String nextChapterId;

  const ChapterCompleteEvent({required this.currentChapterId, required this.nextChapterId});
}
