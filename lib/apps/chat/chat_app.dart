import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../apps/awi_app.dart';
import '../../models/chat_entry.dart';
import '../../models/choice.dart';
import '../../engine/parser/awi_parser.dart';
import '../../state/chats_provider.dart';
import '../../state/chat_progress_notifier.dart';
import '../../state/chapter_selector_provider.dart';
import '../../state/game_notifier.dart';
import '../../state/settings_notifier.dart';
import '../../state/wallpaper_notifier.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/components/message_bubble.dart';

/// Chat app: list of chats -> tap to open -> full-screen conversation (tap to advance).
class ChatApp extends AwiApp {
  const ChatApp({super.key});

  @override
  String get id => 'chat';
  @override
  IconData get icon => Icons.chat_bubble_outline;
  @override
  String get name => 'Messages';

  @override
  Widget build(BuildContext context) {
    return const _ChatListScreen();
  }
}

class _ChatListScreen extends ConsumerWidget {
  const _ChatListScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);
    final progress = ref.watch(chatProgressProvider);
    final unreadCount = progress.values.where((e) => e.hasUnread).length;
    final pending = ref.watch(pendingChapterStartProvider);
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final p = pending;
        ref.read(pendingChapterStartProvider.notifier).clear();
        final chat = chats.where((c) => c.id == p.chatId).firstOrNull;
        if (chat != null && context.mounted) {
          await _openChatAtChapter(context, ref, chat, p.chapterId, p.scriptPath);
        }
      });
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.messagesAccent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Messages',
              style: TextStyle(color: AppTheme.labelPrimary, fontWeight: FontWeight.w600, fontSize: 20),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: AppTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4405F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
        itemCount: chats.length,
        itemBuilder: (context, i) {
          final chat = chats[i];
          final hasUnread = progress[chat.id]?.hasUnread ?? false;
          return _ChatTile(
            chat: chat,
            hasUnread: hasUnread,
            onTap: () {
              HapticFeedback.lightImpact();
              _openChat(context, ref, chat);
            },
          );
        },
      ),
    );
  }

  static Future<void> _openChat(BuildContext context, WidgetRef ref, ChatEntry chat) async {
    try {
      final notifier = ref.read(gameNotifierProvider.notifier);
      final chatProgress = ref.read(chatProgressProvider.notifier);
      final chatSave = ref.read(chatSaveManagerProvider);
      notifier.cancelAutoRoll();
      notifier.prepareForNewChat();
      chatProgress.markOpened(chat.id);

      final baseChatId = chat.id.contains('_') ? chat.id.substring(0, chat.id.lastIndexOf('_')) : chat.id;
      final saveData = await chatSave.load(chat.id) ?? await chatSave.load(baseChatId);
      final chapterId = saveData?.currentChapterId ?? chat.chapterId ?? chat.id;
      final scriptPath = chat.scriptPathForChapter(chapterId);

      if (!context.mounted) return;
      final script = await DefaultAssetBundle.of(context).loadString(scriptPath);
      if (!context.mounted) return;

      notifier.loadScript(script, chapterId: chapterId);
      notifier.openChat(chat.id);

      final loaded = await notifier.loadChat(chat.id, chat);
      if (!context.mounted) return;

      final engine = ref.read(engineProvider);
      final isThread = chat.threadId != null;
      if (!loaded || engine.history.isEmpty) {
        notifier.start(label: chat.startLabel, forceLabel: isThread);
      } else if (engine.currentNodeId != null) {
        notifier.next();
      }
      // Se currentNodeId == null mas temos history: pause (ex: trigger sem next). Mantém as mensagens.

      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ConversationPage(chat: chat),
        ),
      );
      if (!context.mounted) return;
      await notifier.saveChat(chat.id);
      notifier.backToChatList();
    } catch (e) {
      debugPrint('AwiOS: could not load ${chat.scriptPath}: $e');
    }
  }

  static Future<void> _openChatAtChapter(BuildContext context, WidgetRef ref, ChatEntry chat, String chapterId, String scriptPath) async {
    try {
      final notifier = ref.read(gameNotifierProvider.notifier);
      final chatProgress = ref.read(chatProgressProvider.notifier);
      final chatSave = ref.read(chatSaveManagerProvider);
      notifier.cancelAutoRoll();
      notifier.prepareForNewChat();
      chatProgress.markOpened(chat.id);

      final script = await DefaultAssetBundle.of(context).loadString(scriptPath);
      if (!context.mounted) return;

      final parser = AwiParser();
      final header = parser.parseHeaderOnly(script);
      final startLabel = header?.defaultStartLabel ?? 'start';

      await chatSave.clearChat(chat.id);
      notifier.loadScript(script, chapterId: chapterId);
      notifier.openChat(chat.id);
      notifier.start(label: startLabel, forceLabel: false);

      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _ConversationPage(chat: chat)),
      );
      if (!context.mounted) return;
      await notifier.saveChat(chat.id);
      notifier.backToChatList();
    } catch (e) {
      debugPrint('AwiOS: could not open chapter $chapterId: $e');
    }
  }
}

class _ChatTile extends StatefulWidget {
  const _ChatTile({required this.chat, required this.onTap, this.hasUnread = false});

  final ChatEntry chat;
  final VoidCallback onTap;
  final bool hasUnread;

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final avatarPath = widget.chat.avatarPathForDisplay;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        color: _hovered ? AppTheme.surface.withValues(alpha: 0.5) : Colors.transparent,
        child: ListTile(
          onTap: widget.onTap,
          leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.messagesAccent.withValues(alpha: 0.2),
            backgroundImage: avatarPath != null
                ? AssetImage(avatarPath)
                : null,
            child: avatarPath == null
                ? const Icon(Icons.person, color: AppTheme.messagesAccent)
                : null,
          ),
          if (widget.hasUnread)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4405F),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.chat.name,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.labelPrimary),
            ),
          ),
          if (widget.hasUnread)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE4405F),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: widget.chat.lastPreview != null
          ? Text(
              widget.chat.lastPreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.labelSecondary, fontSize: 14),
            )
          : null,
        ),
      ),
    );
  }
}

class _ConversationPage extends ConsumerStatefulWidget {
  const _ConversationPage({required this.chat});

  final ChatEntry chat;

  @override
  ConsumerState<_ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<_ConversationPage> {
  void _checkReturnToChat(WidgetRef ref) {
    final returnToId = ref.read(gameNotifierProvider).returnToChatId;
    if (returnToId == null) return;
    ref.read(gameNotifierProvider.notifier).clearReturnToChatId();
    final chats = ref.read(chatsProvider);
    ChatEntry? targetChat;
    for (final c in chats) {
      if (c.id == returnToId) {
        targetChat = c;
        break;
      }
    }
    if (targetChat == null) return;
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _openChatById(navigator.context, ref, targetChat!);
    });
  }

  static Future<void> _openChatById(BuildContext context, WidgetRef ref, ChatEntry chat) async {
    try {
      final notifier = ref.read(gameNotifierProvider.notifier);
      final chatProgress = ref.read(chatProgressProvider.notifier);
      final chatSave = ref.read(chatSaveManagerProvider);
      notifier.cancelAutoRoll();
      notifier.prepareForNewChat();
      chatProgress.markOpened(chat.id);

      final baseChatId = chat.id.contains('_') ? chat.id.substring(0, chat.id.lastIndexOf('_')) : chat.id;
      final saveData = await chatSave.load(chat.id) ?? await chatSave.load(baseChatId);
      final chapterId = saveData?.currentChapterId ?? chat.chapterId ?? chat.id;
      final scriptPath = chat.scriptPathForChapter(chapterId);

      if (!context.mounted) return;
      final script = await DefaultAssetBundle.of(context).loadString(scriptPath);
      if (!context.mounted) return;

      notifier.loadScript(script, chapterId: chapterId);
      notifier.openChat(chat.id);

      final loaded = await notifier.loadChat(chat.id, chat);
      if (!context.mounted) return;

      final engine = ref.read(engineProvider);
      final isThread = chat.threadId != null;
      if (!loaded || engine.history.isEmpty) {
        notifier.start(label: chat.startLabel, forceLabel: isThread);
      } else if (engine.currentNodeId != null) {
        notifier.next();
      }
      // Se currentNodeId == null mas temos history: pause (ex: trigger sem next). Mantém as mensagens.

      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ConversationPage(chat: chat),
        ),
      );
      if (!context.mounted) return;
      await notifier.saveChat(chat.id);
      notifier.backToChatList();
    } catch (e) {
      debugPrint('AwiOS: could not load ${chat.scriptPath}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameStateUI>(gameNotifierProvider, (prev, next) {
      if (next.returnToChatId != null && next.returnToChatId != prev?.returnToChatId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkReturnToChat(ref));
      }
    });
    return _ConversationScreen(chat: widget.chat, ref: ref);
  }
}

class _ConversationScreen extends StatelessWidget {
  const _ConversationScreen({required this.chat, required this.ref});

  final ChatEntry chat;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final engine = ref.watch(engineProvider);
    final chatWallpaper = ref.watch(wallpaperProvider).chatWallpaper;
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.messagesAccent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            chat.name,
            style: const TextStyle(color: AppTheme.labelPrimary, fontWeight: FontWeight.w600, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: Icon(
                settings.autoRollEnabled ? Icons.pause : Icons.play_arrow,
                size: 22,
              ),
              tooltip: settings.autoRollEnabled ? 'Auto-roll ligado (pausar)' : 'Auto-roll desligado (ativar)',
              onPressed: () {
                HapticFeedback.selectionClick();
                final notifier = ref.read(gameNotifierProvider.notifier);
                final willEnable = !settings.autoRollEnabled;
                ref.read(settingsProvider.notifier).setAutoRoll(willEnable);
                if (willEnable) {
                  notifier.scheduleAutoRollIfEnabled();
                } else {
                  notifier.cancelAutoRoll();
                }
              },
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (chatWallpaper != null)
              Image.asset(
                chatWallpaper,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: AppTheme.background),
              )
            else
              const ColoredBox(color: AppTheme.background),
            if (chatWallpaper != null)
              Container(color: Colors.white.withValues(alpha: 0.4)),
            Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (state.choices == null || state.choices!.isEmpty) {
                        HapticFeedback.lightImpact();
                        ref.read(gameNotifierProvider.notifier).next();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Builder(
                      builder: (context) {
                        final playerId = state.playerCharacterId ?? engine.playerCharacterId;
                        final participants = chat.participantIds(playerId);
                        final messages = participants != null
                            ? state.messages.where((n) => participants.contains(n.senderId.trim())).toList()
                            : state.messages;
                        final hasChapterTransition = state.pendingChapterTransition != null;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                          reverse: true,
                          itemCount: messages.length + (hasChapterTransition ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (hasChapterTransition && i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                                child: _ChapterTransitionBubble(
                                  chat: chat,
                                  transition: state.pendingChapterTransition!,
                                  ref: ref,
                                ),
                              );
                            }
                            final msgIdx = hasChapterTransition ? i - 1 : i;
                            final node = messages[messages.length - 1 - msgIdx];
                            final chars = state.characters.isNotEmpty ? state.characters : engine.characters;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                              child: MessageBubble(
                                node: node,
                                characters: chars,
                                playerCharacterId: playerId,
                                onReturnTo: () => ref.read(gameNotifierProvider.notifier).returnToMessage(node.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (state.choices != null && state.choices!.isNotEmpty) _ChoicesBar(choices: state.choices!, ref: ref),
                if (state.isTyping)
                  const Padding(
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.messagesAccent),
                        ),
                        SizedBox(width: AppTheme.spaceMd),
                        Text('...', style: TextStyle(color: AppTheme.labelSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats chapter ID for display (e.g. tutorial_awi_v2_cap2 → Chapter 2).
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

class _ChapterTransitionBubble extends StatelessWidget {
  const _ChapterTransitionBubble({
    required this.chat,
    required this.transition,
    required this.ref,
  });

  final ChatEntry chat;
  final PendingChapterTransition transition;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final formattedName = _formatChapterName(transition.nextChapterId);
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _continueToNextChapter(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppTheme.messagesAccent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.messagesAccent.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                'Continue to $formattedName',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueToNextChapter(BuildContext context) async {
    final path = chat.scriptPathForChapter(transition.nextChapterId);
    if (path == chat.scriptPath && (chat.chapterScripts == null || !chat.chapterScripts!.containsKey(transition.nextChapterId))) {
      debugPrint('AwiOS: no script for chapter ${transition.nextChapterId}');
      ref.read(gameNotifierProvider.notifier).clearPendingChapterTransition();
      return;
    }
    final navigator = Navigator.of(context);
    final formattedName = _formatChapterName(transition.nextChapterId);
    navigator.push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _ChapterTransitionOverlay(formattedName: formattedName),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    bool success = false;
    try {
      final script = await DefaultAssetBundle.of(context).loadString(path);
      success = await ref.read(gameNotifierProvider.notifier).transitionToNextChapterAndSave(
        chat,
        transition.nextChapterId,
        script,
      );
    } catch (e, st) {
      debugPrint('AwiOS: could not load chapter ${transition.nextChapterId}: $e\n$st');
      ref.read(gameNotifierProvider.notifier).clearPendingChapterTransition();
    }
    if (success) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    navigator.pop(); // pop overlay
    if (success) {
      navigator.pop(); // pop conversation
    }
  }
}

/// Black screen with chapter title during transition.
class _ChapterTransitionOverlay extends StatelessWidget {
  const _ChapterTransitionOverlay({required this.formattedName});

  final String formattedName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                inherit: false,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoicesBar extends StatelessWidget {
  const _ChoicesBar({required this.choices, required this.ref});

  final List<Choice> choices;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      color: AppTheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: choices
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.messagesAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(gameNotifierProvider.notifier).choose(c);
                    },
                    child: Text(c.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
