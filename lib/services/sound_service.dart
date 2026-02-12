import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../core/secure_asset_bundle.dart';

/// Sons do chat: envio, recebimento, notificação.
/// Usa [secureAssetBundle] para suportar assets encriptados em release.
/// Fallback para beeps gerados quando o asset falha.
class SoundService {
  static const _sendPath = 'assets/sounds/send_message.mp3';
  static const _receivePath = 'assets/sounds/received_message.mp3';
  static const _notificationPath = 'assets/sounds/toast_sound.mp3';

  final AudioPlayer _player = AudioPlayer();
  bool _useAssets = true;

  SoundService() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  void dispose() {
    _player.dispose();
  }

  Future<void> playSend({bool enabled = true}) async {
    if (!enabled) return;
    await _play(_sendPath, _buildBeepBytes(440, 0.03));
  }

  Future<void> playReceive({bool enabled = true}) async {
    if (!enabled) return;
    await _play(_receivePath, _buildBeepBytes(880, 0.04));
  }

  Future<void> playNotification({bool enabled = true}) async {
    if (!enabled) return;
    await _play(_notificationPath, _buildBeepBytes(660, 0.08));
  }

  Future<void> _play(String assetPath, Uint8List fallbackBytes) async {
    try {
      if (_useAssets) {
        final data = await SecureAssetBundle.instance.load(assetPath);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await _player.play(BytesSource(bytes));
      } else {
        throw Exception('no asset');
      }
    } catch (_) {
      _useAssets = false;
      try {
        await _player.play(BytesSource(fallbackBytes));
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('SoundService: $e');
        }
      }
    }
  }

  /// Gera um beep WAV mínimo (fallback quando assets não existem).
  Uint8List _buildBeepBytes(int hz, double sec) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * sec).round();
    final dataSize = numSamples * 2; // 16-bit
    final fileSize = 36 + dataSize;

    final b = ByteData(44 + dataSize);
    var i = 0;

    void write4(String s) {
      for (var j = 0; j < 4; j++) {
        b.setUint8(i++, s.codeUnitAt(j));
      }
    }

    void write16(int v) {
      b.setUint16(i, v, Endian.little);
      i += 2;
    }

    void write32(int v) {
      b.setUint32(i, v, Endian.little);
      i += 4;
    }

    write4('RIFF');
    write32(fileSize);
    write4('WAVE');
    write4('fmt ');
    write32(16);
    write16(1);
    write16(1);
    write32(sampleRate);
    write32(sampleRate * 2);
    write16(2);
    write16(16);
    write4('data');
    write32(dataSize);

    const ampl = 8000.0;
    for (var s = 0; s < numSamples; s++) {
    final t = s / sampleRate;
      final sample = (ampl * _sin(2 * 3.14159 * hz * t) * (1 - s / numSamples)).round().clamp(-32768, 32767);
      b.setInt16(i, sample, Endian.little);
      i += 2;
    }

    return b.buffer.asUint8List();
  }

  double _sin(double x) {
    x = x % 6.28318;
    if (x > 3.14159) x -= 6.28318;
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }
}
