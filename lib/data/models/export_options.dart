class ExportOptions {
  final String format;
  final String resolution;
  final String quality;
  final int crf;
  final String outputPath;

  const ExportOptions({
    required this.format,
    required this.resolution,
    required this.quality,
    required this.crf,
    required this.outputPath,
  });

  static const Map<String, (int, int)> resolutionMap = {
    'source': (0, 0),
    '480p': (854, 480),
    '720p': (1280, 720),
    '1080p': (1920, 1080),
    '4K': (3840, 2160),
  };

  static const Map<String, int> qualityCrfMap = {
    'low': 28,
    'medium': 23,
    'high': 18,
    'ultra': 15,
  };

  static const List<String> formats = ['mp4', 'mov', 'webm', 'gif'];
  static const List<String> resolutions = [
    'source',
    '480p',
    '720p',
    '1080p',
    '4K',
  ];
  static const List<String> qualities = ['low', 'medium', 'high', 'ultra'];

  static int crfForQuality(String quality) {
    return qualityCrfMap[quality] ?? 23;
  }

  factory ExportOptions.defaults() {
    return const ExportOptions(
      format: 'mp4',
      resolution: 'source',
      quality: 'high',
      crf: 18,
      outputPath: '',
    );
  }

  ExportOptions copyWith({
    String? format,
    String? resolution,
    String? quality,
    int? crf,
    String? outputPath,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      quality: quality ?? this.quality,
      crf: crf ?? this.crf,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}
