import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wallpaper para home (phone shell) e chats.
class WallpaperState {
  final String? homeWallpaper;
  final String? chatWallpaper;

  const WallpaperState({this.homeWallpaper, this.chatWallpaper});

  WallpaperState copyWith({String? homeWallpaper, String? chatWallpaper, bool clearHome = false, bool clearChat = false}) {
    return WallpaperState(
      homeWallpaper: clearHome ? null : (homeWallpaper ?? this.homeWallpaper),
      chatWallpaper: clearChat ? null : (chatWallpaper ?? this.chatWallpaper),
    );
  }

  Map<String, dynamic> toJson() => {
        'homeWallpaper': homeWallpaper,
        'chatWallpaper': chatWallpaper,
      };

  factory WallpaperState.fromJson(Map<String, dynamic> json) {
    return WallpaperState(
      homeWallpaper: json['homeWallpaper'] as String?,
      chatWallpaper: json['chatWallpaper'] as String?,
    );
  }
}

class WallpaperNotifier extends Notifier<WallpaperState> {
  static const _key = 'awios_wallpaper';

  @override
  WallpaperState build() {
    Future.microtask(() => _load());
    return const WallpaperState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>?;
        if (decoded != null) {
          state = WallpaperState.fromJson(decoded);
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void setHomeWallpaper(String? path) {
    state = state.copyWith(homeWallpaper: path, clearHome: path == null);
    _save();
  }

  void setChatWallpaper(String? path) {
    state = state.copyWith(chatWallpaper: path, clearChat: path == null);
    _save();
  }
}

final wallpaperProvider = NotifierProvider<WallpaperNotifier, WallpaperState>(WallpaperNotifier.new);
