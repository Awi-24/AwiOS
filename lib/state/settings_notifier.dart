import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings: autosave, language, text speed, gallery unlock all, auto-roll.
class SettingsState {
  final bool autosaveEnabled;
  final String language;
  final double textSpeed;
  final bool galleryUnlockAll;
  final bool autoRollEnabled;
  final bool soundEnabled;

  const SettingsState({
    this.autosaveEnabled = true,
    this.language = 'en',
    this.textSpeed = 1.0,
    this.galleryUnlockAll = false,
    this.autoRollEnabled = true,
    this.soundEnabled = true,
  });

  SettingsState copyWith({
    bool? autosaveEnabled,
    String? language,
    double? textSpeed,
    bool? galleryUnlockAll,
    bool? autoRollEnabled,
    bool? soundEnabled,
  }) {
    return SettingsState(
      autosaveEnabled: autosaveEnabled ?? this.autosaveEnabled,
      language: language ?? this.language,
      textSpeed: textSpeed ?? this.textSpeed,
      galleryUnlockAll: galleryUnlockAll ?? this.galleryUnlockAll,
      autoRollEnabled: autoRollEnabled ?? this.autoRollEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'autosaveEnabled': autosaveEnabled,
        'language': language,
        'textSpeed': textSpeed,
        'galleryUnlockAll': galleryUnlockAll,
        'autoRollEnabled': autoRollEnabled,
        'soundEnabled': soundEnabled,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      autosaveEnabled: json['autosaveEnabled'] as bool? ?? true,
      language: json['language'] as String? ?? 'en',
      textSpeed: (json['textSpeed'] as num?)?.toDouble() ?? 1.0,
      galleryUnlockAll: json['galleryUnlockAll'] as bool? ?? false,
      autoRollEnabled: json['autoRollEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _key = 'awios_settings';

  @override
  SettingsState build() {
    Future.microtask(() => _load());
    return const SettingsState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>?;
        if (decoded != null) {
          state = SettingsState.fromJson(decoded);
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

  void setAutosave(bool value) {
    state = state.copyWith(autosaveEnabled: value);
    _save();
  }

  void setLanguage(String value) {
    state = state.copyWith(language: value);
    _save();
  }

  void setTextSpeed(double value) {
    state = state.copyWith(textSpeed: value);
    _save();
  }

  void setGalleryUnlockAll(bool value) {
    state = state.copyWith(galleryUnlockAll: value);
    _save();
  }

  void setAutoRoll(bool value) {
    state = state.copyWith(autoRollEnabled: value);
    _save();
  }

  void setSoundEnabled(bool value) {
    state = state.copyWith(soundEnabled: value);
    _save();
  }

  /// Restaura configurações padrão e remove da persistência.
  Future<void> clearAll() async {
    state = const SettingsState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
