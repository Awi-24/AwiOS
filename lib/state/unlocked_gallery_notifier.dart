import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/system_bus.dart';

/// Estado global de imagens desbloqueadas na galeria.
/// Escuta SystemBus para unlock(app="gallery") e persiste.
class UnlockedGalleryNotifier extends Notifier<Set<String>> {
  static const _key = 'awios_unlocked_gallery';
  StreamSubscription<SystemEvent>? _sub;

  @override
  Set<String> build() {
    Future.microtask(() => _load());
    ref.onDispose(() => _sub?.cancel());
    _sub ??= SystemBus.events.listen((event) {
      if (event.command == 'unlock' && event.app == 'gallery' && event.id != null) {
        add(event.id!);
      }
    });
    return {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>?;
        if (list != null) {
          state = list.map((e) => e.toString()).toSet();
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toList()));
    } catch (_) {}
  }

  void add(String path) {
    final p = path.startsWith('assets/') ? path : 'assets/$path';
    if (state.contains(p)) return;
    state = {...state, p};
    _save();
  }

  Future<void> clearAll() async {
    state = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  void merge(Iterable<String> paths) {
    var changed = false;
    for (final p in paths) {
      final norm = p.startsWith('assets/') ? p : 'assets/$p';
      if (!state.contains(norm)) {
        state = {...state, norm};
        changed = true;
      }
    }
    if (changed) _save();
  }
}

final unlockedGalleryProvider =
    NotifierProvider<UnlockedGalleryNotifier, Set<String>>(UnlockedGalleryNotifier.new);
