/// Thread dentro de um chat (conversa separada no mesmo arquivo).
class ChatThreadDef {
  final String id;
  final String name;
  final String entryLabel;
  /// ID do personagem no script para 1:1 (ex: S) – usado para filtrar mensagens.
  final String? characterId;
  /// Caminho do avatar na lista de chats.
  final String? avatarPath;
  /// IDs explícitos de participantes (ex: ['A','P'] para grupo). Se null, usa characterId.
  final List<String>? participantIds;

  const ChatThreadDef({
    required this.id,
    required this.name,
    required this.entryLabel,
    this.characterId,
    this.avatarPath,
    this.participantIds,
  });
}

/// Represents a chat / story the player can open.
class ChatEntry {
  final String id;
  final String name;
  final String scriptPath;
  final String? avatarPath;
  final String? lastPreview;
  final String? chapterId;
  final Map<String, String>? chapterScripts;
  /// Threads no mesmo arquivo (ex: Ana + Mike). Primeiro = principal.
  final List<ChatThreadDef>? threads;
  /// Quando é uma thread filha: ID da thread, label de entrada.
  final String? threadId;
  final String? entryLabel;

  const ChatEntry({
    required this.id,
    required this.name,
    required this.scriptPath,
    this.avatarPath,
    this.lastPreview,
    this.chapterId,
    this.chapterScripts,
    this.threads,
    this.threadId,
    this.entryLabel,
  });

  String scriptPathForChapter(String chapterId) {
    if (chapterScripts != null && chapterScripts!.containsKey(chapterId)) {
      return chapterScripts![chapterId]!;
    }
    return scriptPath;
  }

  /// ID para save (com thread quando aplicável).
  String get effectiveId => id;

  /// Label de início no script.
  String get startLabel => entryLabel ?? 'start';

  /// IDs de personagens cujas mensagens devem aparecer neste chat (filter por thread).
  /// Null = sem filtro (mostra tudo).
  List<String>? participantIds(String? playerCharacterId) {
    if (threads == null || threads!.isEmpty) return null;
    ChatThreadDef? t;
    if (threadId != null) {
      for (final x in threads!) {
        if (x.id == threadId) {
          t = x;
          break;
        }
      }
    } else {
      t = threads!.first;
    }
    if (t == null) return null;
    if (t.participantIds != null && t.participantIds!.isNotEmpty) {
      return t.participantIds!;
    }
    final cid = t.characterId;
    if (cid == null) return null;
    return playerCharacterId != null ? [cid, playerCharacterId] : [cid];
  }

  /// Avatar do chat na lista (por thread ou chat).
  String? get avatarPathForDisplay {
    if (threads == null || threads!.isEmpty) return avatarPath;
    if (threadId != null) {
      for (final t in threads!) {
        if (t.id == threadId && t.avatarPath != null) return t.avatarPath;
      }
    }
    return threads!.first.avatarPath ?? avatarPath;
  }
}
