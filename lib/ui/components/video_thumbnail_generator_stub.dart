import 'package:flutter/material.dart';

/// Stub para web - thumbnail generation não disponível.
Future<String?> generateVideoThumbnail(String assetPath, {int size = 400}) async =>
    null;

/// Stub - retorna placeholder.
Widget buildThumbnailImage(String path, {double? width, double? height, Widget Function(Object, StackTrace?)? errorBuilder}) =>
    const ColoredBox(color: Color(0xFF2a2a2a));
