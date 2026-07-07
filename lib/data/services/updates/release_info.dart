class ReleaseInfo {
  final String tagName;
  final int major;
  final int minor;
  final int patch;
  final String releaseNotes;
  final String downloadUrl;
  final String assetType;
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.major,
    required this.minor,
    required this.patch,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.assetType,
    required this.publishedAt,
  });
}
