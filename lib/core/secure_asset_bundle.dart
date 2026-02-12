import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'asset_key.dart';

/// Asset bundle that decrypts encrypted assets in release mode.
/// In debug mode, delegates to rootBundle (no encryption).
class SecureAssetBundle extends CachingAssetBundle {
  SecureAssetBundle({AssetBundle? parent}) : _parent = parent ?? rootBundle;

  /// Singleton para uso em todo o app (sons, scripts, etc.).
  static final instance = SecureAssetBundle();

  final AssetBundle _parent;

  @override
  Future<ByteData> load(String key) async {
    final data = await _parent.load(key);
    if (!kReleaseMode) return data;

    try {
      final encrypted = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final decrypted = _decrypt(encrypted);
      return ByteData.sublistView(decrypted);
    } catch (_) {
      return data;
    }
  }

  Uint8List _decrypt(Uint8List encrypted) {
    final encrypter = Encrypter(AES(getAssetDecryptionKey(), mode: AESMode.cbc));
    final enc = Encrypted(encrypted);
    return Uint8List.fromList(encrypter.decryptBytes(enc, iv: getAssetDecryptionIV()));
  }
}
