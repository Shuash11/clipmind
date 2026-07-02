import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

enum ThemeModePreference { dark, light, system }

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default('ollama') String activeProviderId,
    @Default('') String activeModel,
    @Default('http://localhost:11434') String ollamaEndpoint,
    @Default(ThemeModePreference.dark) ThemeModePreference theme,
    @Default({}) Map<String, String> outputFormatDefaults,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}
