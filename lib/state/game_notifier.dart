import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/character.dart';
import '../models/chat_entry.dart';
import '../models/choice.dart';
import '../models/dialogue_node.dart';
import '../models/game_state.dart';
import '../models/save_data.dart';
import '../core/system_bus.dart';
import '../engine/engine.dart';
import '../services/sound_service.dart';
import 'chat_progress_notifier.dart';
import 'chats_provider.dart';
import 'instahub_notifier.dart';
import 'settings_notifier.dart';
import 'unlocked_gallery_notifier.dart';
import 'unlocked_threads_notifier.dart';
import 'wallpaper_notifier.dart';

/// Sound service singleton (disposed when app closes).
final soundServiceProvider = Provider<SoundService>((ref) {
  final svc = SoundService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// Save por chat (SharedPreferences).
final chatSaveManagerProvider = Provider<ChatSaveManager>((ref) {
  return SharedPreferencesChatSaveManager();
});

/// Gerenciador de progresso global – Caderno de Notas para dependência dinâmica.
/// Usa SharedPreferences para persistir chapter history e flags.
final progressProvider = Provider<ProgressManager>((ref) {
  final pm = ProgressManager(storage: SharedPreferencesProgressStorage());
  pm.load(); // Carrega em background (async)
  ref.onDispose(() {});
  return pm;
});

/// Provides [AwiEngine] (single instance) with ProgressManager.
final engineProvider = Provider<AwiEngine>((ref) {
  final progress = ref.watch(progressProvider);
  final engine = AwiEngine(progressManager: progress);
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Game notifier: connects UI to engine, holds message list, typing, auto-scroll.
/// Uses Riverpod 3 Notifier API.
class GameNotifier extends Notifier<GameStateUI> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _autoRollTimer;

  @override
  GameStateUI build() {
    final engine = ref.watch(engineProvider);
    ref.onDispose(() {
      _autoRollTimer?.cancel();
      _autoRollTimer = null;
      for (final s in _subscriptions) {
        s.cancel();
      }
    });
    _subscriptions.add(engine.onMessage.listen(_onMessage));
    _subscriptions.add(engine.onChoices.listen(_onChoices));
    _subscriptions.add(engine.onStateChanged.listen(_onStateChanged));
    _subscriptions.add(engine.onChapterComplete.listen(_onChapterComplete));
    _subscriptions.add(engine.onThreadTrigger.listen(_onThreadTrigger));
    _subscriptions.add(engine.onReturnToThread.listen(_onReturnToThread));
    return GameStateUI.initial();
  }

  void _onMessage(DialogueNode node) {
    if (state.currentChatId == null) return;
    final chatId = state.currentChatId!;
    ChatEntry? chat;
    for (final c in ref.read(chatsProvider)) {
      if (c.id == chatId) {
        chat = c;
        break;
      }
    }
    if (chat != null) {
      final playerId = state.playerCharacterId ?? ref.read(engineProvider).playerCharacterId;
      final participants = chat.participantIds(playerId);
      if (participants != null && !participants.contains(node.senderId.trim())) {
        _showToastForOtherChat(node);
        return;
      }
    }
    _autoRollTimer?.cancel();
    _autoRollTimer = null;
    state = state.copyWith(
      messages: [...state.messages, node],
      choices: null,
      isTyping: false,
    );
    if (node.content.isNotEmpty) {
      ref.read(chatProgressProvider.notifier).markInteracted(chatId, node.content);
    }
    if (ref.read(settingsProvider).soundEnabled) {
      ref.read(soundServiceProvider).playReceive();
    }
    _scheduleAutoRoll(node);
    _saveChatIfEnabled();
  }

  void _showToastForOtherChat(DialogueNode node) {
    final chatId = state.currentChatId;
    if (chatId == null) return;
    final allChats = ref.read(chatsProvider);
    for (final c in allChats) {
      if (c.id == chatId) continue;
      final playerId = state.playerCharacterId ?? ref.read(engineProvider).playerCharacterId;
      final participants = c.participantIds(playerId);
      if (participants != null && participants.contains(node.senderId.trim())) {
        final preview = node.content.length > 40 ? '${node.content.substring(0, 40)}...' : node.content;
        final avatarPath = c.avatarPathForDisplay;
        final params = <String, String>{'title': c.name, 'body': preview};
        if (avatarPath != null && avatarPath.isNotEmpty) params['avatar'] = avatarPath;
        SystemBus.emit(SystemEvent(command: 'toast_from_other_chat', params: params));
        return;
      }
    }
  }

  void _scheduleAutoRoll(DialogueNode node) {
    final settings = ref.read(settingsProvider);
    if (!settings.autoRollEnabled) return;
    final delaySec = node.delay > 0 ? node.delay : 2.0;
    final adjusted = delaySec / settings.textSpeed;
    final duration = Duration(milliseconds: (adjusted * 1000).round().clamp(500, 15000));
    _autoRollTimer = Timer(duration, () {
      _autoRollTimer = null;
      next();
    });
  }

  /// Cancela o timer de auto-roll (quando o usuário desativa).
  void cancelAutoRoll() {
    _autoRollTimer?.cancel();
    _autoRollTimer = null;
  }

  /// Agenda auto-roll quando o usuário ativa enquanto já há mensagem na tela.
  void scheduleAutoRollIfEnabled() {
    final settings = ref.read(settingsProvider);
    if (!settings.autoRollEnabled) return;
    if (state.choices != null && state.choices!.isNotEmpty) return;
    if (state.messages.isEmpty) return;
    final lastNode = state.messages.last;
    if (lastNode.content.isEmpty) return;
    _scheduleAutoRoll(lastNode);
  }

  void _onChoices(List<Choice> choices) {
    if (state.currentChatId == null) return;
    _autoRollTimer?.cancel();
    _autoRollTimer = null;
    state = state.copyWith(choices: choices, isTyping: false);
    _saveChatIfEnabled();
  }

  void _saveChatIfEnabled() {
    if (!ref.read(settingsProvider).autosaveEnabled) return;
    if (state.currentChatId == null) return;
    saveChat(state.currentChatId!);
  }

  void _onStateChanged(GameState g) {
    state = state.copyWith(gameState: g);
  }

  void _onChapterComplete(ChapterCompleteEvent e) {
    state = state.copyWith(
      pendingChapterTransition: PendingChapterTransition(
        currentChapterId: e.currentChapterId,
        nextChapterId: e.nextChapterId,
      ),
    );
  }

  void _onThreadTrigger(ThreadTriggerEvent e) {
    final baseId = state.currentChatId;
    if (baseId != null && baseId.isNotEmpty) {
      final threadKey = '${baseId}_${e.threadId}';
      ref.read(unlockedThreadsProvider.notifier).unlock(baseId, e.threadId);
      ref.read(chatProgressProvider.notifier).markUnread(threadKey);
      if (ref.read(settingsProvider).soundEnabled) {
        ref.read(soundServiceProvider).playNotification();
      }
    }
  }

  void _onReturnToThread(ReturnToThreadEvent e) async {
    final chatId = state.currentChatId;
    if (chatId == null || !chatId.contains('_')) return;
    final baseChatId = chatId.substring(0, chatId.lastIndexOf('_'));
    final threadId = chatId.substring(chatId.lastIndexOf('_') + 1);
    final engine = ref.read(engineProvider);

    final returnTarget = e.threadId;
    final pipeIdx = returnTarget.indexOf('|');
    final returnLabel = pipeIdx >= 0
        ? returnTarget.substring(pipeIdx + 1).trim()
        : null;
    ChatEntry? baseChat;
    String? excludeThreadCharacterId;
    for (final c in ref.read(chatsProvider)) {
      if (c.id == baseChatId) {
        baseChat = c;
        if (c.threads != null) {
          for (final t in c.threads!) {
            if (t.id == threadId) {
              excludeThreadCharacterId = t.characterId;
              break;
            }
          }
        }
        break;
      }
    }
    final participants = baseChat?.participantIds(engine.playerCharacterId);
    final baseSave = await ref.read(chatSaveManagerProvider).load(baseChatId);
    final baseHistoryIds = List<String>.from(baseSave?.history ?? []);
    final seen = baseHistoryIds.toSet();
    final history = engine.history;
    int returnFromIndex = 0;
    for (var i = 0; i < history.length; i++) {
      if (history[i].metadata?['return_to_thread'] != null) {
        returnFromIndex = i;
        break;
      }
    }
    for (var i = returnFromIndex; i < history.length; i++) {
      final node = history[i];
      final sid = node.senderId.trim();
      final isExcluded = excludeThreadCharacterId != null && sid == excludeThreadCharacterId;
      final isParticipant = participants == null ? !isExcluded : participants.contains(sid);
      if (isParticipant && !seen.contains(node.id)) {
        baseHistoryIds.add(node.id);
        seen.add(node.id);
      }
    }
    SaveData dataToSave;
    final base = engine.buildCurrentSaveData();
    dataToSave = SaveData(
      currentNode: returnLabel ?? base.currentNode,
      currentChapterId: base.currentChapterId,
      variables: base.variables,
      flags: base.flags,
      history: baseHistoryIds,
      unlockedMedia: base.unlockedMedia,
      globalFlagsJson: base.globalFlagsJson,
      chapterHistoryPaths: base.chapterHistoryPaths,
      choiceNodesJson: base.choiceNodesJson,
      timestamp: base.timestamp,
    );
    await ref.read(chatSaveManagerProvider).save(baseChatId, dataToSave);
    state = state.copyWith(returnToChatId: baseChatId);
  }

  void loadScript(String script, {String? chapterId}) {
    ref.read(engineProvider).loadScript(script, chapterId: chapterId);
    final engine = ref.read(engineProvider);
    state = state.copyWith(
      messages: [],
      choices: null,
      isTyping: false,
      characters: engine.characters,
      playerCharacterId: engine.playerCharacterId,
    );
  }

  void start({
    String label = 'start',
    Map<String, Map<String, String>>? bridgeRules,
    String? dependencyChapterId,
    bool forceLabel = false,
  }) {
    state = state.copyWith(isTyping: true);
    ref.read(engineProvider).start(label: label, bridgeRules: bridgeRules, dependencyChapterId: dependencyChapterId, forceLabel: forceLabel);
  }

  void next() {
    _autoRollTimer?.cancel();
    _autoRollTimer = null;
    ref.read(engineProvider).next();
  }

  void choose(Choice choice) {
    if (ref.read(settingsProvider).soundEnabled) {
      ref.read(soundServiceProvider).playSend();
    }
    // Exibe a escolha do jogador no chat antes de processar
    final engine = ref.read(engineProvider);
    final playerId = engine.playerCharacterId ?? 'player';
    final playerNode = DialogueNode(
      id: 'choice_${DateTime.now().millisecondsSinceEpoch}',
      senderId: playerId,
      type: DialogueNodeType.text,
      content: choice.text,
      isUser: true,
    );
    state = state.copyWith(
      messages: [...state.messages, playerNode],
      choices: null,
    );
    if (state.currentChatId != null) {
      ref.read(chatProgressProvider.notifier).markInteracted(state.currentChatId!, choice.text);
    }
    ref.read(engineProvider).choose(choice);
    _saveChatIfEnabled();
  }

  Future<void> save(int slot) => ref.read(engineProvider).save(slot);
  Future<bool> load(int slot) => ref.read(engineProvider).load(slot);

  /// Salva o estado atual do chat (persistência por conversa).
  Future<void> saveChat(String chatId) async {
    final engine = ref.read(engineProvider);
    final data = engine.buildCurrentSaveData();
    await ref.read(chatSaveManagerProvider).save(chatId, data);
  }

  /// Carrega o estado salvo do chat. Retorna true se havia save.
  Future<bool> loadChat(String chatId, [ChatEntry? chatEntry]) async {
    final data = await ref.read(chatSaveManagerProvider).load(chatId);
    if (data == null) return false;
    ref.read(unlockedGalleryProvider.notifier).merge(data.unlockedMedia);
    final engine = ref.read(engineProvider);
    if (!engine.applyLoadData(data)) return false;
    var messages = engine.displayableHistory;
    if (chatEntry != null) {
      final playerId = engine.playerCharacterId;
      final participants = chatEntry.participantIds(playerId);
      if (participants != null && participants.isNotEmpty) {
        messages = messages.where((n) => participants.contains(n.senderId.trim())).toList();
      }
    }
    state = state.copyWith(
      messages: messages,
      choices: null,
      isTyping: false,
      characters: engine.characters,
      playerCharacterId: engine.playerCharacterId,
    );
    return true;
  }

  void openChat(String chatId) {
    state = state.copyWith(currentChatId: chatId);
  }

  void prepareForNewChat() {
    cancelAutoRoll();
    state = state.copyWith(currentChatId: null, messages: [], choices: null, isTyping: false, clearPendingChapterTransition: true);
  }

  void backToChatList() {
    cancelAutoRoll();
    state = state.copyWith(currentChatId: null, messages: [], clearPendingChapterTransition: true);
  }

  /// Limpa a transição de capítulo pendente (após carregar o próximo).
  void clearPendingChapterTransition() {
    state = state.copyWith(clearPendingChapterTransition: true);
  }

  /// Limpa returnToChatId após a UI ter feito a troca de chat.
  void clearReturnToChatId() {
    state = state.copyWith(clearReturnToChatId: true);
  }

  /// Retorna ao ponto de uma mensagem (clique direito / long press na bolha).
  void returnToMessage(String nodeId) {
    _autoRollTimer?.cancel();
    _autoRollTimer = null;
    final engine = ref.read(engineProvider);
    if (engine.jumpToNode(nodeId)) {
      final messages = engine.displayableHistory;
      state = state.copyWith(
        messages: messages,
        choices: null,
        isTyping: false,
      );
      _saveChatIfEnabled();
    }
  }

  /// Transição para o próximo capítulo: sincroniza estado, salva e volta para a lista.
  /// Usuário deve tocar no chat de novo para entrar no novo capítulo.
  Future<bool> transitionToNextChapterAndSave(
    ChatEntry chat,
    String nextChapterId,
    String script,
  ) async {
    final engine = ref.read(engineProvider);
    final progress = ref.read(progressProvider);
    // Apply bridge vars (e.g. trust_cap1) BEFORE canStartChapterForScript,
    // so chapter 2's dependency (global.trust_cap1 >= 0) can be evaluated.
    final trustVal = engine.state.get('trust');
    if (trustVal != null && trustVal is num) {
      progress.applyToGlobalFlags(['trust_cap1 = $trustVal']);
    }
    if (!engine.canStartChapterForScript(script)) {
      debugPrint('AwiOS: chapter $nextChapterId blocked (dependency/required_flag failed)');
      clearPendingChapterTransition();
      return false;
    }

    ref.read(engineProvider).loadScript(script, chapterId: nextChapterId);
    final loadedEngine = ref.read(engineProvider);

    final data = SaveData(
      currentNode: null,
      currentChapterId: nextChapterId,
      variables: Map.from(loadedEngine.state.variables),
      flags: loadedEngine.state.flags.toList(),
      history: [],
      unlockedMedia: List.from(loadedEngine.unlockedMedia),
      globalFlagsJson: progress.globalFlags.toJson(),
      chapterHistoryPaths: progress.chapterHistory.all,
      choiceNodesJson: {},
      timestamp: DateTime.now(),
    );
    await ref.read(chatSaveManagerProvider).save(chat.id, data);
    ref.read(unlockedGalleryProvider.notifier).merge(loadedEngine.unlockedMedia);

    clearPendingChapterTransition();
    backToChatList();
    return true;
  }

  /// Reseta todo o histórico: progresso, saves e progresso de chats.
  Future<void> resetChatHistory() async {
    await ref.read(engineProvider).resetAll();
    await ref.read(progressProvider).resetAndPersist();
    await ref.read(chatProgressProvider.notifier).resetAll();
    await ref.read(unlockedThreadsProvider.notifier).resetAll();
    await ref.read(chatSaveManagerProvider).clearAll();
    state = state.copyWith(messages: [], choices: null);
  }

  /// Limpa todo o cache e dados persistentes (saves, progresso, galeria, threads, wallpapers, instahub, settings).
  Future<void> clearAllData() async {
    await resetChatHistory();
    await ref.read(unlockedGalleryProvider.notifier).clearAll();
    await ref.read(wallpaperProvider.notifier).clearAll();
    await ref.read(instahubProvider.notifier).clearAll();
    await ref.read(settingsProvider.notifier).clearAll();
    await _clearAllSharedPreferences();
  }

  /// Remove todos os keys awios_* do SharedPreferences (garante limpeza total).
  Future<void> _clearAllSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('awios_')).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

/// Transição de capítulo pendente (capítulo terminou, próximo deve carregar).
class PendingChapterTransition {
  final String currentChapterId;
  final String nextChapterId;

  const PendingChapterTransition({
    required this.currentChapterId,
    required this.nextChapterId,
  });
}

/// UI state: current chat, messages, choices, typing, characters.
class GameStateUI {
  final String? currentChatId;
  final List<DialogueNode> messages;
  final List<Choice>? choices;
  final bool isTyping;
  final GameState? gameState;
  final Map<String, Character> characters;
  /// ID do personagem marcado como jogador em CHARACTERS ([Player]). Mensagens dele à direita.
  final String? playerCharacterId;
  /// Quando um capítulo termina e o próximo deve ser carregado.
  final PendingChapterTransition? pendingChapterTransition;
  /// Quando return_to no script: voltar para este chat (ex: Ana após Mike).
  final String? returnToChatId;

  const GameStateUI({
    this.currentChatId,
    this.messages = const [],
    this.choices,
    this.isTyping = false,
    this.gameState,
    this.characters = const {},
    this.playerCharacterId,
    this.pendingChapterTransition,
    this.returnToChatId,
  });

  factory GameStateUI.initial() => const GameStateUI();

  GameStateUI copyWith({
    String? currentChatId,
    List<DialogueNode>? messages,
    List<Choice>? choices,
    bool? isTyping,
    GameState? gameState,
    Map<String, Character>? characters,
    String? playerCharacterId,
    PendingChapterTransition? pendingChapterTransition,
    bool clearPendingChapterTransition = false,
    String? returnToChatId,
    bool clearReturnToChatId = false,
  }) {
    return GameStateUI(
      currentChatId: currentChatId ?? this.currentChatId,
      messages: messages ?? this.messages,
      choices: choices ?? this.choices,
      isTyping: isTyping ?? this.isTyping,
      gameState: gameState ?? this.gameState,
      characters: characters ?? this.characters,
      playerCharacterId: playerCharacterId ?? this.playerCharacterId,
      pendingChapterTransition: clearPendingChapterTransition
          ? null
          : (pendingChapterTransition ?? this.pendingChapterTransition),
      returnToChatId: clearReturnToChatId ? null : (returnToChatId ?? this.returnToChatId),
    );
  }
}

final gameNotifierProvider = NotifierProvider<GameNotifier, GameStateUI>(GameNotifier.new);
