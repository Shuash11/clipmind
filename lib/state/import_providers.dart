import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/import/url_import_service.dart';
import 'package:clipmind/data/services/import/youtube_import_service.dart';

/// Factory providers for the hub's URL import services.
///
/// The hub calls a factory once per import, so every download gets a fresh
/// service with its own stream controllers and child handle — the same
/// lifecycle the hub had when it constructed them directly. Living in
/// `state/` mirrors `ffmpeg_providers.dart`: presentation reads services
/// through providers, and widget tests can `overrideWithValue` a factory
/// returning fakes (controlled availability probe, progress stream, and
/// cancel accounting).
final youtubeImportServiceFactoryProvider =
    Provider<YouTubeImportService Function()>(
      (ref) => YouTubeImportService.new,
    );

final urlImportServiceFactoryProvider = Provider<UrlImportService Function()>(
  (ref) => UrlImportService.new,
);
