class AppConstants {
  AppConstants._();

  static const String appName = 'ClipMind';
  static const String projectExtension = 'cmproj';
  static const int maxPromptLength = 2000;
  static const int cloudTimeoutSeconds = 30;
  static const int localTimeoutSeconds = 60;
  static const double minSpeedFactor = 0.25;
  static const double maxSpeedFactor = 4.0;
  static const double minBrightness = -1.0;
  static const double maxBrightness = 1.0;
  static const double defaultVolume = 1.0;

  static const List<String> supportedVideoFormats = [
    'mp4',
    'mov',
    'avi',
    'webm',
    'mkv',
    'm4v',
  ];

  static const List<String> supportedImageFormats = [
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  static const String ollamaDefaultEndpoint = 'http://localhost:11434';
  static const String defaultTempDir = '.clipmind_temp';
  static const String thumbnailSuffix = '_thumb.jpg';
  static const String defaultExportDir = 'exports';
  static const int thumbnailQuality = 2;
  static const Duration seekSkipDuration = Duration(seconds: 10);
  static const int maxRecentProjects = 20;
}
