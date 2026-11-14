/// Stub implementation for platforms without audio and widget tests.
class PlatformAudioPlayer {
  void playWavBase64(
    String base64Wav, {
    String key = 'tone',
    bool loop = false,
    double volume = 0.6,
    bool isAlarm = false,
  }) {}

  void setVolume(double volume) {}

  void stop() {}
}
