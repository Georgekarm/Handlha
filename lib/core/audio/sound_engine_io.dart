import 'package:flutter/services.dart';

/// Native implementation for Android/iOS via the `com.handelha.app/audio` channel.
class PlatformAudioPlayer {
  static const MethodChannel _channel = MethodChannel('com.handelha.app/audio');
  bool _isAlarm = false;

  void playWavBase64(
    String base64Wav, {
    String key = 'tone',
    bool loop = false,
    double volume = 0.6,
    bool isAlarm = false,
  }) {
    _isAlarm = isAlarm;
    _invoke('playWavBase64', {
      'base64Wav': base64Wav,
      'key': key,
      'loop': loop,
      'volume': volume.clamp(0.0, 1.0),
      'isAlarm': isAlarm,
    });
  }

  void setVolume(double volume) {
    _invoke('setVolume', {
      'volume': volume.clamp(0.0, 1.0),
      'isAlarm': _isAlarm,
    });
  }

  void stop() {
    _invoke('stop', {'isAlarm': _isAlarm});
  }

  Future<void> _invoke(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod<dynamic>(method, args);
    } catch (_) {
      // Safe fallback in headless widget tests or platforms without the plugin.
    }
  }
}
