import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  SettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = AsyncValue.data(await _repository.load());
  }

  Future<void> update(AppSettings settings) async {
    await _repository.save(settings);
    state = AsyncValue.data(settings);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return SettingsNotifier(ref.read(settingsRepositoryProvider));
});

final activeProviderIdProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.valueOrNull?.activeProviderId ?? 'ollama';
});

final activeModelProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.valueOrNull?.activeModel ?? '';
});
