import 'dart:io';

/// Restores plain assets from build/assets_backup after a release build.
/// Run after `flutter build windows` to continue development with unencrypted assets.
Future<void> main() async {
  final projectRoot = Directory.current;
  final backupDir = Directory('${projectRoot.path}/build/assets_backup');
  if (!await backupDir.exists()) {
    print('No backup found. Run dart run tool/encrypt_assets.dart first.');
    exit(1);
  }

  final assetsDir = Directory('${projectRoot.path}/assets');
  var count = 0;

  await for (final entity in backupDir.list(recursive: true)) {
    if (entity is! File) continue;
    final backupFile = entity;
    final prefix = backupDir.path.endsWith(Platform.pathSeparator)
        ? backupDir.path
        : '${backupDir.path}${Platform.pathSeparator}';
    final relative = backupFile.path.replaceFirst(prefix, '').replaceAll(r'\', '/');
    final targetPath = '${assetsDir.path}/${relative.replaceFirst('assets/', '')}';
    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(await backupFile.readAsBytes());
    count++;
    print('Restored: $relative');
  }

  print('Restored $count assets.');
}
