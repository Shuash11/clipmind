import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/data/local/database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final repo = SettingsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final SettingsRepository _repository;

  /// Completes with the loaded settings. Await this before reading
  /// settings-dependent flags on cold start (first submit would otherwise
  /// see defaults while the JSON file is still loading). Cached: awaiting
  /// after the first load returns immediately.
  late final Future<AppSettings> ready;

  SettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    ready = _load();
  }

  Future<AppSettings> _load() async {
    final settings = await _repository.load();
    state = AsyncValue.data(settings);
    return settings;
  }

  Future<void> update(AppSettings settings) async {
    await _repository.save(settings);
    state = AsyncValue.data(settings);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
      return SettingsNotifier(ref.read(settingsRepositoryProvider));
    });

final activeProviderIdProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.value?.activeProviderId ?? 'ollama';
});
