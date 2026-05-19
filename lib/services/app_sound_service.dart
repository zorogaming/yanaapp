import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppSoundService {
  AppSoundService._();

  static final AppSoundService instance = AppSoundService._();

  AudioPlayer? _player;
  int _lastNotificationSoundAtMs = 0;

  Future<void> playNotificationSound() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotificationSoundAtMs < 900) return;
    _lastNotificationSoundAtMs = now;

    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(1.0);
      final bytes = await rootBundle.load('assets/ordersound.mp3');
      await _player!.play(BytesSource(bytes.buffer.asUint8List()));
    } catch (error, stackTrace) {
      debugPrint('[APP_SOUND] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
