import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../awi_app.dart';
import '../../models/instahub_comment.dart';
import '../../state/instahub_notifier.dart';
import '../../ui/components/media_viewer.dart';
import '../../ui/components/video_thumbnail.dart';
import '../../ui/theme/app_theme.dart';

/// App estilo Instagram: feed de posts desbloqueados pelo script.
/// Posts são adicionados via system: trigger(app="instahub", action="post", id="p01")
class InstaHubApp extends AwiApp {
  const InstaHubApp({super.key});

  @override
  String get id => 'instahub';
  @override
  IconData get icon => Icons.photo_camera_outlined;
  @override
  String get name => 'InstaHub';

  @override
  Widget build(BuildContext context) {
    return const _InstaHubScreen();
  }

  static const _postDefinitions = <String, _PostDef>{
    'p01': _PostDef(id: 'p01', author: 'Marcus', avatarPath: 'assets/images/tulip.png', content: 'Finally finished the project! 🎉'),
    'p02': _PostDef(id: 'p02', author: 'Alice', avatarPath: 'assets/images/tulip.png', content: 'Meeting tomorrow at 10am. Don\'t miss it!'),
    'p03': _PostDef(id: 'p03', author: 'Bob', avatarPath: 'assets/images/tulip.png', content: 'Bug logs on the drive. Feel free to check.'),
    'p_tulip': _PostDef(id: 'p_tulip', author: 'AwiOS', avatarPath: 'assets/images/tulip.png', content: 'Guide: A tulip for you 🌷', imagePath: 'assets/images/tulip.png'),
    'p_sunset': _PostDef(id: 'p_sunset', author: 'AwiOS', avatarPath: 'assets/images/sunset_sky.png', content: 'Sunset on the horizon 🌅', imagePath: 'assets/images/sunset_sky.png'),
    'p_casal': _PostDef(id: 'p_casal', author: 'Yuki', avatarPath: 'assets/images/tulip.png', content: 'Our moment at the beach 💕', imagePath: 'assets/images/mountain_snow.png'),
    'p_secreto': _PostDef(id: 'p_secreto', author: '???', avatarPath: null, content: 'You need to see this...', imagePath: 'assets/images/mountain_snow.png'),
    'p_video': _PostDef(id: 'p_video', author: 'AwiOS', avatarPath: 'assets/images/tulip.png', content: 'Video demo in feed 📹', videoPath: 'assets/videos/awiOS.mp4'),
    'festa01': _PostDef(id: 'festa01', author: 'Liam', avatarPath: 'assets/images/avatar/liam_avatar.png', content: 'Pics from last night\'s party! 🍻', imagePath: 'assets/images/avatar/festa_bar.png'),
  };
}

class _PostDef {
  final String id;
  final String author;
  final String? avatarPath;
  final String content;
  final String? imagePath;
  final String? videoPath;

  const _PostDef({
    required this.id,
    required this.author,
    this.avatarPath,
    required this.content,
    this.imagePath,
    this.videoPath,
  });
}

class _InstaHubScreen extends ConsumerWidget {
  const _InstaHubScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instahubProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(instahubProvider.notifier).clearNew());

    final unlockedIds = state.unlockedPostIds
        .where((id) => InstaHubApp._postDefinitions.containsKey(id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: const Color(0xFFE4405F),
        elevation: 0,
        title: const Text('InstaHub', style: TextStyle(color: AppTheme.labelPrimary, fontWeight: FontWeight.w600, fontSize: 20)),
      ),
      body: unlockedIds.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined, size: 64, color: AppTheme.labelTertiary),
                  SizedBox(height: AppTheme.spaceMd),
                  Text('No posts yet', style: TextStyle(color: AppTheme.labelSecondary, fontSize: 17)),
                  SizedBox(height: AppTheme.spaceXs),
                  Text('Posts aparecem aqui quando o script os desbloqueia.', style: TextStyle(color: AppTheme.labelTertiary, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
              itemCount: unlockedIds.length,
              itemBuilder: (context, i) {
                final def = InstaHubApp._postDefinitions[unlockedIds[i]];
                if (def == null) return const SizedBox.shrink();
                return _PostCard(
                  def: def,
                  isNew: state.hasNew(def.id),
                  isLiked: state.isLiked(def.id),
                  comments: state.commentsFor(def.id),
                  onLike: () => ref.read(instahubProvider.notifier).toggleLike(def.id),
                  onAddComment: (text) => ref.read(instahubProvider.notifier).addComment(def.id, text),
                  onToggleCommentLike: (commentId) => ref.read(instahubProvider.notifier).toggleCommentLike(def.id, commentId),
                );
              },
            ),
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.def,
    required this.isNew,
    required this.isLiked,
    required this.comments,
    required this.onLike,
    required this.onAddComment,
    required this.onToggleCommentLike,
  });

  final _PostDef def;
  final bool isNew;
  final bool isLiked;
  final List<dynamic> comments;
  final VoidCallback onLike;
  final void Function(String) onAddComment;
  final void Function(String) onToggleCommentLike;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  final _commentController = TextEditingController();
  bool _showComments = false;
  bool _hovered = false;

  static const _instaColor = Color(0xFFE4405F);

  Widget _buildAuthorAvatar(_PostDef def) {
    if (def.avatarPath != null && def.avatarPath!.isNotEmpty) {
      final path = def.avatarPath!.startsWith('assets/') ? def.avatarPath! : 'assets/${def.avatarPath!}';
      return ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarFallback(),
          ),
        ),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    return CircleAvatar(
      backgroundColor: _instaColor.withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: _instaColor, size: 24),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    const instaColor = _instaColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_hovered ? 1.02 : 1.0),
        transformAlignment: Alignment.center,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAuthorAvatar(def),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(def.author, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.labelPrimary, fontSize: 16)),
                              if (widget.isNew) ...[
                                const SizedBox(width: AppTheme.spaceXs),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: instaColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE4405F))),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  def.content,
                  style: const TextStyle(color: AppTheme.labelPrimary, fontSize: 15, height: 1.4),
                ),
                if (def.imagePath != null || def.videoPath != null) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  _PostMedia(path: def.imagePath ?? def.videoPath!, isVideo: def.videoPath != null),
                ],
                const SizedBox(height: AppTheme.spaceMd),
                // Botões: curtir, comentar, compartilhar, salvar
                Row(
                  children: [
                    IconButton(
                      icon: Icon(widget.isLiked ? Icons.favorite : Icons.favorite_border, color: widget.isLiked ? instaColor : AppTheme.labelSecondary, size: 26),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onLike();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.labelSecondary, size: 24),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showComments = !_showComments);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_outlined, color: AppTheme.labelSecondary, size: 24),
                      onPressed: () { HapticFeedback.lightImpact(); },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: AppTheme.labelSecondary, size: 24),
                      onPressed: () { HapticFeedback.lightImpact(); },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showComments) _CommentsSection(
            comments: widget.comments as List<InstaHubComment>,
            onToggleLike: widget.onToggleCommentLike,
            onSend: (text) {
              if (text.trim().isEmpty) return;
              widget.onAddComment(text.trim());
              _commentController.clear();
            },
            commentController: _commentController,
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.path, required this.isVideo});

  final String path;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return GestureDetector(
        onTap: () => MediaViewer.show(context, path),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: VideoThumbnail(
            path: path,
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => MediaViewer.show(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          path,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.onToggleLike,
    required this.onSend,
    required this.commentController,
  });

  final List<InstaHubComment> comments;
  final void Function(String) onToggleLike;
  final void Function(String) onSend;
  final TextEditingController commentController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
      decoration: const BoxDecoration(color: AppTheme.background),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comments.isNotEmpty) ...[
            ...comments.map((c) => _CommentTile(
              comment: c,
              onToggleLike: () => onToggleLike(c.id),
            )),
            const SizedBox(height: AppTheme.spaceSm),
          ],
          // Barra de comentário estética (enviar apenas visual - texto é funcional)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: 'Add comment...',
                    hintStyle: const TextStyle(color: AppTheme.labelTertiary, fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSend,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppTheme.primary, size: 26),
                onPressed: () => onSend(commentController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onToggleLike});

  final InstaHubComment comment;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final likeCount = comment.likeCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${comment.author} ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.labelPrimary),
          ),
          Expanded(
            child: Text(
              comment.text,
              style: const TextStyle(fontSize: 14, color: AppTheme.labelSecondary),
            ),
          ),
          if (likeCount > 0)
            Text('$likeCount ', style: const TextStyle(fontSize: 12, color: AppTheme.labelTertiary)),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleLike();
            },
            child: Icon(likeCount > 0 ? Icons.favorite : Icons.favorite_border, size: 16, color: likeCount > 0 ? const Color(0xFFE4405F) : AppTheme.labelTertiary),
          ),
        ],
      ),
    );
  }
}
