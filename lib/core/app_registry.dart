import 'package:flutter/material.dart';

import '../apps/awi_app.dart';
import '../apps/chat/chat_app.dart';
import '../apps/gallery/gallery_app.dart';
import '../apps/instahub/instahub_app.dart';
import '../apps/settings/settings_app.dart';

/// Central registry of AwiOS apps.
/// Extensível: novos apps podem registrar-se via [register].
class AppRegistry {
  AppRegistry._();

  static final List<AwiApp> _apps = [];
  static final Map<String, Color> _accents = {};

  /// Lista de apps registrados (ordem determina grade e dock).
  static List<AwiApp> get apps => List.unmodifiable(_apps);

  /// Cor de destaque por app id. Fallback: [AppTheme.primary].
  static Color accent(String appId) {
    return _accents[appId] ?? const Color(0xFF098DF1);
  }

  /// Registra um app e sua cor opcional.
  static void register(AwiApp app, {Color? accent}) {
    if (!_apps.any((a) => a.id == app.id)) {
      _apps.add(app);
      if (accent != null) _accents[app.id] = accent;
    }
  }

  /// Registra o conjunto padrão de apps (Chat, Gallery, InstaHub, Settings).
  static void registerDefaults() {
    register(const ChatApp(), accent: const Color(0xFF098DF1));
    register(const GalleryApp(), accent: const Color(0xFF7B5FB8));
    register(const InstaHubApp(), accent: const Color(0xFFE4405F)); // Instagram rose
    register(const SettingsApp(), accent: const Color(0xFFE68A00));
  }

  /// Limpa o registro (útil para testes).
  static void clear() {
    _apps.clear();
    _accents.clear();
  }
}
