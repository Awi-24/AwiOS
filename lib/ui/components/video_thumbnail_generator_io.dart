import 'dart:io';

import 'package:flutter/material.dart';

/// Uses video_player for thumbnails on desktop; no native thumbnail generation.
/// Skipping fc_native_video_thumbnail avoids Windows ATL (atlimage.h) build issues.
final _cache = <String, String?>{};

Widget buildThumbnailImage(String path, {double? width, double? height, Widget Function(Object, StackTrace?)? errorBuilder}) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    width: width,
    height: height,
    errorBuilder: errorBuilder != null ? (_, e, st) => errorBuilder(e, st) : null,
  );
}

/// Returns null so VideoThumbnail falls back to VideoPlayerController (first frame).
Future<String?> generateVideoThumbnail(String assetPath, {int size = 400}) async {
  if (_cache.containsKey(assetPath)) return _cache[assetPath];
  _cache[assetPath] = null;
  return null;
}
