import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AppSoundService {
  AppSoundService._();

  static final AppSoundService instance = AppSoundService._();

  AudioPlayer? _player;
  AudioPlayer? _splashPlayer;
  bool _audioContextReady = false;
  int _lastNotificationSoundAtMs = 0;
  static const Duration _audioStartupTimeout = Duration(seconds: 2);

  Future<void> playSplashSound() async {
    try {
      _splashPlayer ??= AudioPlayer();
      await _splashPlayer!.stop().timeout(_audioStartupTimeout);
      await _splashPlayer!
          .setReleaseMode(ReleaseMode.stop)
          .timeout(_audioStartupTimeout);
      await _splashPlayer!
          .setPlayerMode(PlayerMode.mediaPlayer)
          .timeout(_audioStartupTimeout);
      await _ensureAudibleContext(_splashPlayer!).timeout(
        _audioStartupTimeout,
      );
      await _splashPlayer!.setVolume(1.0).timeout(_audioStartupTimeout);
      await _splashPlayer!
          .play(AssetSource('Yana.mp3'))
          .timeout(_audioStartupTimeout);
    } catch (error, stackTrace) {
      debugPrint('[APP_SOUND][SPLASH] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> stopSplashSound() async {
    try {
      await _splashPlayer?.stop();
      await _splashPlayer?.dispose();
    } catch (_) {
      // Sound cleanup should never block navigation.
    } finally {
      _splashPlayer = null;
    }
  }

  Future<void> playNotificationSound() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotificationSoundAtMs < 900) return;
    _lastNotificationSoundAtMs = now;

    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setPlayerMode(PlayerMode.mediaPlayer);
      await _ensureAudibleContext(_player!);
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('ordersound.mp3'));
    } catch (error, stackTrace) {
      debugPrint('[APP_SOUND] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _ensureAudibleContext(AudioPlayer player) async {
    final context = AudioContextConfig(
      route: AudioContextConfigRoute.speaker,
      focus: AudioContextConfigFocus.gain,
      respectSilence: false,
    ).build();

    if (!_audioContextReady) {
      await AudioPlayer.global.setAudioContext(context);
      _audioContextReady = true;
    }
    await player.setAudioContext(context);
  }
}
