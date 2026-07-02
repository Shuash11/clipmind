import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:path_provider/path_provider.dart';

class SettingsRepository {
  AppSettings? _cached;
  final _controller = StreamController<AppSettings>.broadcast();
  bool _disposed = false;

  Stream<AppSettings> get stream => _controller.stream;

  Future<AppSettings> load() async {
    if (_cached != null) return _cached!;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/settings.json');
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        _cached = AppSettings.fromJson(json as Map<String, dynamic>);
        return _cached!;
      }
    } catch (_) {}
    _cached = const AppSettings();
    return _cached!;
  }

  Future<void> save(AppSettings settings) async {
    _cached = settings;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/settings.json');
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (_) {}
    if (!_disposed) _controller.add(settings);
  }

  Future<String?> getActiveProviderId() async {
    final s = await load();
    return s.activeProviderId;
  }

  Future<String?> getActiveModel() async {
    final s = await load();
    return s.activeModel;
  }

  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
