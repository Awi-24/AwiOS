import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../state/wallpaper_notifier.dart';
import '../theme/app_theme.dart';

/// Viewer para imagem ou vídeo (asset). Usado em chat, galeria e InstaHub.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.path,
    this.allPaths,
    this.initialIndex = 0,
    this.showSetWallpaper = false,
    this.wallpaperTarget = WallpaperTarget.home,
  });

  final String path;
  final List<String>? allPaths;
  final int initialIndex;
  final bool showSetWallpaper;
  final WallpaperTarget wallpaperTarget;

  static bool get isVideo => false;

  static bool isVideoPath(String path) =>
      path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');

  static void show(BuildContext context, String path, {bool showSetWallpaper = false}) {
    final resolvedPath = path.startsWith('assets/') ? path : 'assets/$path';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => MediaViewer(
          path: resolvedPath,
          showSetWallpaper: showSetWallpaper,
          wallpaperTarget: WallpaperTarget.home,
        ),
      ),
    );
  }

  static void showGallery(BuildContext context, List<String> paths, int initialIndex, {bool showSetWallpaper = false}) {
    if (paths.isEmpty) return;
    final idx = initialIndex.clamp(0, paths.length - 1);
    final resolved = paths.map((p) => p.startsWith('assets/') ? p : 'assets/$p').toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => MediaViewer(
          path: resolved[idx],
          allPaths: resolved,
          initialIndex: idx,
          showSetWallpaper: showSetWallpaper,
          wallpaperTarget: WallpaperTarget.home,
        ),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

enum WallpaperTarget { home, chat }

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _videoInitFailed = false;

  @override
  void initState() {
    super.initState();
    _isVideo = MediaViewer.isVideoPath(widget.path);
    if (_isVideo) {
      try {
        _videoController = VideoPlayerController.asset(widget.path);
        _videoController!.initialize().then((_) {
          if (mounted) {
            _videoController!.setLooping(true);
            _videoController!.play();
            setState(() {});
          }
        }).catchError((e, _) {
          if (mounted) {
            _videoInitFailed = true;
            setState(() {});
          }
        });
      } catch (_) {
        _videoInitFailed = true;
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allPaths != null && widget.allPaths!.length > 1) {
      return _GalleryNavigator(
        allPaths: widget.allPaths!,
        initialIndex: widget.initialIndex,
        showSetWallpaper: widget.showSetWallpaper,
        wallpaperTarget: widget.wallpaperTarget,
      );
    }
    return _SingleMediaView(
      path: widget.path,
      videoController: _videoController,
      isVideo: _isVideo,
      videoInitFailed: _videoInitFailed,
      showSetWallpaper: widget.showSetWallpaper,
      wallpaperTarget: widget.wallpaperTarget,
    );
  }
}

class _SingleMediaView extends StatelessWidget {
  const _SingleMediaView({
    required this.path,
    this.videoController,
    required this.isVideo,
    this.videoInitFailed = false,
    this.showSetWallpaper = false,
    this.wallpaperTarget = WallpaperTarget.home,
  });

  final String path;
  final VideoPlayerController? videoController;
  final bool isVideo;
  final bool videoInitFailed;
  final bool showSetWallpaper;
  final WallpaperTarget wallpaperTarget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo && videoController != null && videoController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: videoController!.value.aspectRatio,
                child: VideoPlayer(videoController!),
              ),
            )
          else if (isVideo && videoInitFailed)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text('Video not available on this platform', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          else if (isVideo)
            const Center(child: CircularProgressIndicator(color: Colors.white70))
          else
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.asset(
                  path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white70),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (showSetWallpaper && !isVideo)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Consumer(
                    builder: (context, ref, _) {
                      return Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref.read(wallpaperProvider.notifier).setHomeWallpaper(path);
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.home, size: 20),
                            label: const Text('Wallpaper inicial'),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref.read(wallpaperProvider.notifier).setChatWallpaper(path);
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.chat, size: 20),
                            label: const Text('Wallpaper chats'),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryNavigator extends StatefulWidget {
  const _GalleryNavigator({
    required this.allPaths,
    required this.initialIndex,
    this.showSetWallpaper = false,
    this.wallpaperTarget = WallpaperTarget.home,
  });

  final List<String> allPaths;
  final int initialIndex;
  final bool showSetWallpaper;
  final WallpaperTarget wallpaperTarget;

  @override
  State<_GalleryNavigator> createState() => _GalleryNavigatorState();
}

class _GalleryNavigatorState extends State<_GalleryNavigator> {
  late int _index;
  late FocusNode _focusNode;
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _videoInitFailed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _initMedia();
  }

  void _initMedia() {
    _videoController?.dispose();
    _videoInitFailed = false;
    final path = widget.allPaths[_index];
    _isVideo = MediaViewer.isVideoPath(path);
    if (_isVideo) {
      try {
        _videoController = VideoPlayerController.asset(path);
        _videoController!.initialize().then((_) {
          if (mounted) {
            _videoController!.setLooping(true);
            _videoController!.play();
            setState(() {});
          }
        }).catchError((e, _) {
          if (mounted) {
            _videoInitFailed = true;
            setState(() {});
          }
        });
      } catch (_) {
        _videoInitFailed = true;
        setState(() {});
      }
    } else {
      _videoController = null;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goPrevious() {
    if (_index > 0) {
      setState(() {
        _index--;
        _initMedia();
      });
    }
  }

  void _goNext() {
    if (_index < widget.allPaths.length - 1) {
      setState(() {
        _index++;
        _initMedia();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.allPaths[_index];
    final canGoPrev = _index > 0;
    final canGoNext = _index < widget.allPaths.length - 1;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
            if (canGoPrev) {
              _goPrevious();
              return KeyEventResult.handled;
            }
            break;
          case LogicalKeyboardKey.arrowRight:
            if (canGoNext) {
              _goNext();
              return KeyEventResult.handled;
            }
            break;
          case LogicalKeyboardKey.escape:
            Navigator.of(context).pop();
            return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_isVideo && _videoController != null && _videoController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else if (_isVideo && _videoInitFailed)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                    SizedBox(height: 12),
                    Text('Video not available on this platform', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            else if (_isVideo)
              const Center(child: CircularProgressIndicator(color: Colors.white70))
            else
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white70),
                  ),
                ),
              ),
            if (canGoPrev)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 48),
                    onPressed: _goPrevious,
                    style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            if (canGoNext)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white, size: 48),
                    onPressed: _goNext,
                    style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_index + 1} / ${widget.allPaths.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (widget.showSetWallpaper && !_isVideo) ...[
                        const SizedBox(width: 16),
                        Consumer(
                          builder: (context, ref, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(wallpaperProvider.notifier).setHomeWallpaper(path);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                icon: const Icon(Icons.home, size: 18, color: Colors.white70),
                                label: const Text('Inicial', style: TextStyle(color: Colors.white70)),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(wallpaperProvider.notifier).setChatWallpaper(path);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                icon: const Icon(Icons.chat, size: 18, color: Colors.white70),
                                label: const Text('Chats', style: TextStyle(color: Colors.white70)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
