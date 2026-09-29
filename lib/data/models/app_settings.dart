import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

enum ThemeModePreference { dark, light, system }

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default('ollama') String activeProviderId,
    @Deprecated('Unused since the provider-profile system; model selection '
        'lives in the provider profile (selectedModelId). Kept for the '
        'legacy-settings migration and JSON round-trip.')
    @Default('')
    String activeModel,
    @Default('http://localhost:11434') String ollamaEndpoint,
    @Default(ThemeModePreference.dark) ThemeModePreference theme,
    @Default({}) Map<String, String> outputFormatDefaults,
    @Default(false) bool confirmAgentEdits,
    @Default(false) bool planEditsBeforeApply,
    @Default('') String whisperBinaryPath,
    @Default('') String whisperModelPath,
    @Default('') String lastSeenVersion,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}
