import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_thumbnail_generator_stub.dart' if (dart.library.io) 'video_thumbnail_generator_io.dart' as thumb;

/// Cache de controllers por path para evitar criar/dispor repetidamente em listas.
final class _VideoThumbnailCache {
  _VideoThumbnailCache._();
  static final _instance = _VideoThumbnailCache._();
  static _VideoThumbnailCache get instance => _instance;

  final Map<String, _CachedEntry> _cache = {};
  static const _maxSize = 8;

  VideoPlayerController? getOrCreate(String path, VoidCallback onReady, [VoidCallback? onError]) {
    final entry = _cache[path];
    if (entry != null) {
      entry.refCount++;
      if (entry.controller.value.isInitialized) {
        onReady();
        return entry.controller;
      }
      entry.listeners.add(onReady);
      return entry.controller;
    }
    _evictIfNeeded();
    final controller = VideoPlayerController.asset(path);
    final listeners = <VoidCallback>[onReady];
    _cache[path] = _CachedEntry(controller, listeners);
    controller.initialize().then((_) {
      final e = _cache[path];
      if (e != null && controller.value.isInitialized) {
        controller.pause();
        controller.seekTo(Duration.zero);
        for (final cb in List<VoidCallback>.from(e.listeners)) {
          cb();
        }
        e.listeners.clear();
      }
    }).catchError((_, __) {
      _cache.remove(path);
      controller.dispose();
      onError?.call();
    });
    return controller;
  }

  void release(String path, VideoPlayerController controller) {
    final entry = _cache[path];
    if (entry != null && entry.controller == controller) {
      entry.refCount--;
      if (entry.refCount <= 0) {
        _cache.remove(path);
        controller.dispose();
      }
    }
  }

  void _evictIfNeeded() {
    if (_cache.length < _maxSize) return;
    MapEntry<String, _CachedEntry>? toRemove;
    for (final e in _cache.entries) {
      if (e.value.refCount <= 0) {
        toRemove = e;
        break;
      }
    }
    if (toRemove == null) return;
    toRemove.value.controller.dispose();
    _cache.remove(toRemove.key);
  }
}

class _CachedEntry {
  final VideoPlayerController controller;
  final List<VoidCallback> listeners;
  int refCount = 1;

  _CachedEntry(this.controller, this.listeners);
}

/// Thumbnail de vídeo usando o primeiro frame. Fallback para ícone quando init falha.
class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.path,
    this.width,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  final String path;
  final double? width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  String? _thumbnailPath;

  String get _resolvedPath =>
      widget.path.startsWith('assets/') ? widget.path : 'assets/${widget.path}';

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _generateThumbnailFirst();
  }

  void _generateThumbnailFirst() async {
    final path = await thumb.generateVideoThumbnail(_resolvedPath, size: 480);
    if (mounted && path != null) {
      setState(() => _thumbnailPath = path);
      return;
    }
    if (mounted) _initVideoPlayer();
  }

  void _onThumbnailImageError() {
    if (!mounted) return;
    setState(() => _thumbnailPath = null);
    _initVideoPlayer();
  }

  void _initVideoPlayer() {
    try {
      _controller = _VideoThumbnailCache.instance.getOrCreate(
        _resolvedPath,
        () {
          if (mounted) setState(() {});
        },
        () {
          if (mounted) {
            _initFailed = true;
            setState(() {});
          }
        },
      );
      if (_controller != null && _controller!.value.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    } catch (_) {
      _initFailed = true;
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _VideoThumbnailCache.instance.release(_resolvedPath, _controller!);
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_thumbnailPath != null) {
      child = Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          thumb.buildThumbnailImage(
            _thumbnailPath!,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, __) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _onThumbnailImageError());
              return _buildLoading();
            },
          ),
          _playOverlay(),
        ],
      );
    } else if (_initFailed || _controller == null) {
      child = _buildFallback();
    } else if (_controller!.value.isInitialized) {
      child = Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          _playOverlay(),
        ],
      );
    } else {
      child = _buildLoading();
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    if (widget.onTap != null) {
      child = GestureDetector(onTap: widget.onTap, child: child);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }

  Widget _playOverlay() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: widget.borderRadius != null ? widget.borderRadius! : BorderRadius.zero,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF2d2d2d),
          ],
        ),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.videocam_rounded, size: 48, color: Colors.white.withValues(alpha: 0.05)),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
