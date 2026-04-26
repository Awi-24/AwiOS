import 'package:flutter/material.dart';

/// Base class for AwiOS "phone" apps (Chat, Gallery, Settings, etc.).
/// Each app is pluggable and has an icon + build method.
abstract class AwiApp extends StatelessWidget {
  const AwiApp({super.key});

  String get id;
  IconData get icon;
  String get name;
}
