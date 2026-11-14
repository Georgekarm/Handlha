class TtsConfig {
  const TtsConfig({
    this.languageCandidates = const ['ar-EG', 'ar_EG', 'ar-SA', 'ar_SA', 'ar'],
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
  });

  /// Tried in order; Egyptian Arabic first, then any Arabic.
  final List<String> languageCandidates;
  final double speechRate;
  final double pitch;
  final double volume;
}
