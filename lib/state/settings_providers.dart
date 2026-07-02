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

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return SettingsNotifier(ref);
});

final activeProviderIdProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.valueOrNull?.activeProviderId ?? 'ollama';
});

final activeModelProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.valueOrNull?.activeModel ?? '';
});

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final repo = _ref.read(settingsRepositoryProvider);
    state = AsyncValue.data(await repo.load());
  }

  Future<void> update(AppSettings settings) async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.save(settings);
    state = AsyncValue.data(settings);
  }
}
