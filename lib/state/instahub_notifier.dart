import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/system_bus.dart';
import '../data/instahub_posts.dart';
import '../models/instahub_comment.dart';
import 'game_notifier.dart' show engineProvider;

/// Estado dos posts do InstaHub.
class InstaHubState {
  final List<String> unlockedPostIds;
  final List<String> newPostIds;
  final Set<String> viewedPostIds;
  /// Post IDs curtidos pelo usuário local.
  final Set<String> likedPostIds;
  /// Comentários por post ID.
  final Map<String, List<InstaHubComment>> commentsByPostId;

  const InstaHubState({
    this.unlockedPostIds = const [],
    this.newPostIds = const [],
    this.viewedPostIds = const {},
    this.likedPostIds = const {},
    this.commentsByPostId = const {},
  });

  InstaHubState copyWith({
    List<String>? unlockedPostIds,
    List<String>? newPostIds,
    Set<String>? viewedPostIds,
    Set<String>? likedPostIds,
    Map<String, List<InstaHubComment>>? commentsByPostId,
  }) {
    return InstaHubState(
      unlockedPostIds: unlockedPostIds ?? this.unlockedPostIds,
      newPostIds: newPostIds ?? this.newPostIds,
      viewedPostIds: viewedPostIds ?? this.viewedPostIds,
      likedPostIds: likedPostIds ?? this.likedPostIds,
      commentsByPostId: commentsByPostId ?? this.commentsByPostId,
    );
  }

  bool hasNew(String id) => newPostIds.contains(id);
  bool hasViewed(String id) => viewedPostIds.contains(id);
  bool isLiked(String id) => likedPostIds.contains(id);
  List<InstaHubComment> commentsFor(String postId) => commentsByPostId[postId] ?? [];
}

class InstaHubNotifier extends Notifier<InstaHubState> {
  static const _key = 'awios_instahub_social';
  static const _localUserId = 'local_user';
  StreamSubscription<SystemEvent>? _sub;

  @override
  InstaHubState build() {
    Future.microtask(() => _load());
    ref.onDispose(() => _sub?.cancel());
    _sub ??= SystemBus.events.listen((event) {
      if (event.command == 'trigger' && event.app == 'instahub') {
        if (event.action == 'post' && event.id != null) _addPost(event.id!);
      }
      if (event.command == 'unlock' && event.app == 'instahub') {
        if (event.id != null) _addPost(event.id!);
      }
    });
    return const InstaHubState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>?;
        if (decoded != null) {
          final liked = (decoded['likedPostIds'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};
          final commentsRaw = decoded['commentsByPostId'] as Map<String, dynamic>?;
          final comments = <String, List<InstaHubComment>>{};
          if (commentsRaw != null) {
            for (final e in commentsRaw.entries) {
              final list = (e.value as List<dynamic>?)?.map((c) => InstaHubComment.fromJson(Map<String, dynamic>.from(c as Map))).toList() ?? [];
              comments[e.key] = list;
            }
          }
          state = state.copyWith(likedPostIds: liked, commentsByPostId: comments);
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        'likedPostIds': state.likedPostIds.toList(),
        'commentsByPostId': state.commentsByPostId.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
      }));
    } catch (_) {}
  }

  void _addPost(String id) {
    if (!state.unlockedPostIds.contains(id)) {
      state = state.copyWith(
        unlockedPostIds: [...state.unlockedPostIds, id],
        newPostIds: [...state.newPostIds, id],
      );
      final post = kInstaHubPosts[id];
      if (post?.imagePath != null) ref.read(engineProvider).addUnlockedMedia(post!.imagePath!);
      if (post?.videoPath != null) ref.read(engineProvider).addUnlockedMedia(post!.videoPath!);
    }
  }

  void markViewed(String id) {
    state = state.copyWith(viewedPostIds: {...state.viewedPostIds, id});
  }

  void clearNew() {
    state = state.copyWith(newPostIds: []);
  }

  void toggleLike(String postId) {
    final liked = state.likedPostIds.contains(postId);
    final newLiked = Set<String>.from(state.likedPostIds);
    if (liked) {
      newLiked.remove(postId);
    } else {
      newLiked.add(postId);
    }
    state = state.copyWith(likedPostIds: newLiked);
    _save();
  }

  void addComment(String postId, String text) {
    final comment = InstaHubComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      author: 'You',
      text: text,
    );
    final comments = [...state.commentsFor(postId), comment];
    state = state.copyWith(
      commentsByPostId: {...state.commentsByPostId, postId: comments},
    );
    _save();
  }

  void toggleCommentLike(String postId, String commentId) {
    final comments = state.commentsFor(postId).toList();
    final idx = comments.indexWhere((c) => c.id == commentId);
    if (idx < 0) return;
    final c = comments[idx];
    final liked = c.likedBy.contains(_localUserId);
    final newLiked = Set<String>.from(c.likedBy);
    if (liked) {
      newLiked.remove(_localUserId);
    } else {
      newLiked.add(_localUserId);
    }
    comments[idx] = c.copyWith(likedBy: newLiked);
    state = state.copyWith(commentsByPostId: {...state.commentsByPostId, postId: comments});
    _save();
  }

  void reset() {
    state = const InstaHubState();
  }
}

final instahubProvider = NotifierProvider<InstaHubNotifier, InstaHubState>(InstaHubNotifier.new);
