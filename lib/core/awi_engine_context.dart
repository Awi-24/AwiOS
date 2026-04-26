/// Contexto passado aos handlers de system: e efeitos.
/// Usa callbacks para evitar acoplamento com a engine.
class AwiEngineContext {
  final String? currentChapterId;
  final void Function(String path) addUnlockedMedia;
  final void Function(String chapterId, String path)? recordChapterPath;
  final void Function(List<String> effects)? applyToGlobalFlags;

  const AwiEngineContext({
    this.currentChapterId,
    required this.addUnlockedMedia,
    this.recordChapterPath,
    this.applyToGlobalFlags,
  });
}
