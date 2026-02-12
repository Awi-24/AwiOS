// ignore_for_file: avoid_print

import 'dart:io';

import 'package:awios/core/asset_key.dart';
import 'package:encrypt/encrypt.dart';

/// Encrypts assets for release builds. Run before `flutter build windows`.
///
/// 1. Backs up assets to build/assets_backup
/// 2. Encrypts files in assets/scripts, assets/sounds, assets/images, assets/videos
/// 3. Overwrites originals with encrypted data
///
/// After build, run `dart run tool/restore_assets.dart` to restore plain assets for development.
Future<void> main() async {
  final projectRoot = Directory.current;
  if (!await File('${projectRoot.path}/pubspec.yaml').exists()) {
    print('Run from AwiOS project root: dart run tool/encrypt_assets.dart');
    exit(1);
  }

  final assetsDir = Directory('${projectRoot.path}/assets');
  if (!await assetsDir.exists()) {
    print('assets/ not found');
    exit(1);
  }

  final backupDir = Directory('${projectRoot.path}/build/assets_backup');
  await backupDir.create(recursive: true);

  final encrypter = Encrypter(AES(getAssetDecryptionKey(), mode: AESMode.cbc));
  final iv = getAssetDecryptionIV();

  final assetDirs = ['scripts', 'sounds', 'images', 'videos'];
  var count = 0;

  for (final dirName in assetDirs) {
    final dir = Directory('${assetsDir.path}/$dirName');
    if (!await dir.exists()) continue;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final file = entity;
      if (file.path.contains('README')) continue;

      final suffix = file.path.substring(assetsDir.path.length).replaceAll(Platform.pathSeparator, '/');
      final relative = 'assets${suffix.startsWith('/') ? '' : '/'}$suffix';
      final backupFile = File('${backupDir.path}/$relative');
      await backupFile.parent.create(recursive: true);

      final bytes = await file.readAsBytes();
      await backupFile.writeAsBytes(bytes);

      final encrypted = encrypter.encryptBytes(bytes, iv: iv);
      await file.writeAsBytes(encrypted.bytes);

      count++;
      print('Encrypted: $relative');
    }
  }

  print('Done. Encrypted $count assets. Run flutter build, then dart run tool/restore_assets.dart');
}
