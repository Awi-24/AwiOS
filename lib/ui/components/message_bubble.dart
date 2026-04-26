import 'package:flutter/material.dart';

import '../../models/character.dart';
import '../../models/dialogue_node.dart';
import '../theme/app_theme.dart';
import 'media_viewer.dart';
import 'video_thumbnail.dart';

/// iOS-style message bubble with optional circular avatar (photo bubble).
/// Player messages (isSelf) à direita; NPCs à esquerda.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.node,
    this.characters = const {},
    this.playerCharacterId,
    this.onReturnTo,
  });

  final DialogueNode node;
  final Map<String, Character> characters;
  /// ID do jogador em CHARACTERS ([Player]). Fallback quando character não está no map.
  final String? playerCharacterId;
  /// Right-click or long-press to return to this point in the script.
  final VoidCallback? onReturnTo;

  @override
  Widget build(BuildContext context) {
    final sender = node.senderId.trim();
    // Lookup com fallback para senderId com espaços
    final character = characters[node.senderId] ?? characters[sender];
    // isUser vem do parser (CHARACTERS [Player]); fallbacks para compatibilidade
    final isSelf = node.isUser ||
        character?.isPlayer == true ||
        (playerCharacterId != null && sender.toLowerCase() == playerCharacterId!.toLowerCase()) ||
        sender.toLowerCase() == 'player' ||
        sender.toLowerCase() == 'you' ||
        sender.toLowerCase() == 'jogador' ||
        sender.toLowerCase() == 'eu';
    final avatarPath = character?.avatar;

    final imagePath = node.metadata?['image'] as String?;
    final videoPath = node.metadata?['video'] as String?;
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    final hasVideo = videoPath != null && videoPath.isNotEmpty;
    final hasMedia = hasImage || hasVideo;

    final bubbleColor = isSelf
        ? (character?.bubbleColor != null ? Color(character!.bubbleColor) : AppTheme.bubbleSelf)
        : (character?.bubbleColor != null ? Color(character!.bubbleColor) : AppTheme.bubbleOther);

    final isGroup = characters.length > 2;
    final showName = !isSelf && isGroup;
    final senderName = showName ? (character?.name ?? node.senderId) : null;

    final bubble = GestureDetector(
      onSecondaryTapDown: onReturnTo != null
          ? (_) => _showReturnMenu(context)
          : null,
      onLongPress: onReturnTo != null
          ? () => _showReturnMenu(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: isSelf ? null : Border.all(color: AppTheme.bubbleOtherBorder, width: 1),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isSelf ? 18 : 4),
          bottomRight: Radius.circular(isSelf ? 4 : 18),
        ),
      ),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (node.content.isNotEmpty)
            Text(
              node.content,
              style: TextStyle(
                color: isSelf ? Colors.white : AppTheme.labelPrimary,
                fontSize: 16,
              ),
            ),
          if (hasMedia) ...[
            if (node.content.isNotEmpty) const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                final path = hasVideo ? videoPath : imagePath;
                if (path != null) MediaViewer.show(context, path);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasVideo
                    ? _buildVideoThumbnail(videoPath)
                    : Image.asset(
                        _resolveAssetPath(imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: AppTheme.labelTertiary.withValues(alpha: 0.2),
                          child: const Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.labelTertiary),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
      ),
    );

    final avatar = _buildAvatar(avatarPath);

    if (isSelf) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(left: 40),
          child: bubble,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (avatarPath != null) ...[avatar!, const SizedBox(width: 8)],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderName != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.labelSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  bubble,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnMenu(BuildContext context) {
    if (onReturnTo == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.replay),
          title: const Text('Return to this point'),
          onTap: () {
            Navigator.pop(ctx);
            onReturnTo!();
          },
        ),
      ),
    );
  }

  static String _resolveAssetPath(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.startsWith('assets/') ? path : 'assets/$path';
  }

  Widget _buildVideoThumbnail(String path) {
    return VideoThumbnail(
      path: _resolveAssetPath(path),
      width: double.infinity,
      height: 200,
      borderRadius: BorderRadius.zero,
    );
  }

  Widget? _buildAvatar(String? path) {
    if (path == null || path.isEmpty) return null;
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.asset(
          path.startsWith('assets/') ? path : 'assets/$path',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.messagesAccent.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: AppTheme.messagesAccent),
          ),
        ),
      ),
    );
  }
}
