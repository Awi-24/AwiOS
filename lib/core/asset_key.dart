import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Obfuscated key material for asset decryption.
/// Built from dispersed values to avoid plain strings in code.
/// Not cryptographically secure against reverse engineering—raises the bar for casual extraction.
Key getAssetDecryptionKey() {
  const p1 = 0x4177694f;
  const p2 = 0x53637269;
  const p3 = 0x7074456e;
  const p4 = 0x67696e65;
  const p5 = 0x32326279;
  const p6 = 0x74655f6b;
  const p7 = 0x65792121;
  const p8 = 0x21212121;
  final b = ByteData(32);
  b.setUint32(0, p1 ^ 0x01010101, Endian.big);
  b.setUint32(4, p2 ^ 0x02020202, Endian.big);
  b.setUint32(8, p3 ^ 0x03030303, Endian.big);
  b.setUint32(12, p4 ^ 0x04040404, Endian.big);
  b.setUint32(16, p5 ^ 0x05050505, Endian.big);
  b.setUint32(20, p6 ^ 0x06060606, Endian.big);
  b.setUint32(24, p7 ^ 0x07070707, Endian.big);
  b.setUint32(28, p8 ^ 0x08080808, Endian.big);
  return Key(b.buffer.asUint8List());
}

IV getAssetDecryptionIV() {
  const iv = [
    0x41, 0x77, 0x69, 0x4f, 0x53, 0x5f, 0x41, 0x73,
    0x73, 0x65, 0x74, 0x5f, 0x49, 0x56, 0x5f, 0x31,
  ];
  return IV(Uint8List.fromList(iv));
}
