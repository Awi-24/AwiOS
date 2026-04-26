import '../models/game_state.dart';

/// Handler para efeitos com prefixo: "PREFIX: value" ou "PREFIX=value".
typedef EffectHandler = void Function(String value, EffectContext ctx);

/// Contexto para handlers de efeitos.
class EffectContext {
  final String? currentChapterId;
  final void Function(String path) addUnlockedMedia;
  final void Function(String chapterId, String path)? recordChapterPath;
  final GameState sessionState;

  const EffectContext({
    this.currentChapterId,
    required this.addUnlockedMedia,
    this.recordChapterPath,
    required this.sessionState,
  });
}

/// Registry modular de handlers para efeitos em escolhas.
/// Formato: "PREFIX: value" ou "PREFIX=value".
/// Efeitos sem prefixo conhecido vão para o fallback (variáveis/flags).
class EffectRegistry {
  final Map<String, EffectHandler> _prefixHandlers = {};

  /// Registra handler para um prefixo (ex: UNLOCK_MEDIA, RECORD_PATH).
  void register(String prefix, EffectHandler handler) {
    _prefixHandlers[prefix.toUpperCase()] = handler;
  }

  /// Remove handler de um prefixo.
  void unregister(String prefix) {
    _prefixHandlers.remove(prefix.toUpperCase());
  }

  /// Tenta aplicar um efeito com prefixo. Retorna true se encontrou handler.
  bool tryApplyPrefix(String effectStr, EffectContext ctx) {
    final s = effectStr.trim();
    if (s.isEmpty) return false;

    final colonIdx = s.indexOf(':');
    final eqIdx = s.indexOf('=');
    int splitIdx = -1;

    if (colonIdx > 0 && (eqIdx < 0 || colonIdx < eqIdx)) {
      splitIdx = colonIdx;
    } else if (eqIdx > 0) {
      splitIdx = eqIdx;
    }

    if (splitIdx > 0 && splitIdx < s.length - 1) {
      final prefix = s.substring(0, splitIdx).trim().toUpperCase();
      final value = s.substring(splitIdx + 1).trim();
      final handler = _prefixHandlers[prefix];
      if (handler != null) {
        handler(value, ctx);
        return true;
      }
    }

    return false;
  }

  Iterable<String> get registeredPrefixes => _prefixHandlers.keys;
}

/// Handlers built-in para efeitos de escolhas.
class EffectHandlers {
  static void registerDefaults(EffectRegistry registry) {
    registry.register('UNLOCK_MEDIA', (value, ctx) {
      final path = value.startsWith('assets/') ? value : 'assets/$value';
      ctx.addUnlockedMedia(path);
    });

    registry.register('RECORD_PATH', (value, ctx) {
      if (ctx.currentChapterId != null &&
          value.isNotEmpty &&
          ctx.recordChapterPath != null) {
        ctx.recordChapterPath!(ctx.currentChapterId!, value);
      }
    });
  }
}
