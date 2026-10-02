# Code Graph — lib/core (14 files, 1,154 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/core/async/cancellation_token.dart (34 lines)
- L3  class CancellationToken (CancellationToken, _whenCancelled) — Function() _isCancelled L5, isCancelled L8, whenCancelled L9, throwIfCancelled() L11
- L16  class CancellationController (_cancelled, _completer) — token L19, cancel() L24
- L31  class CancelledException — CancelledException() L32

## lib/core/constants/app_constants.dart (39 lines)
- L1  class AppConstants (AppConstants, appName, projectExtension, maxPromptLength, cloudTimeoutSeconds, localTimeoutSeconds, minSpeedFactor, maxSpeedFactor) — supportedVideoFormats L15, supportedImageFormats L24

## lib/core/constants/effect_presets.dart (151 lines)
- L9  class EffectPresetStep (opType, params) — EffectPresetStep(…) L16
- L19  class EffectPreset (id, label, icon, recipe) — EffectPreset(…) L28

## lib/core/constants/release_notes.dart (99 lines)

## lib/core/constants/transition_presets.dart (130 lines)
- L11  class TransitionPresetStep (opType, params) — TransitionPresetStep(…) L18
- L21  class TransitionPreset (id, label, icon, recipe) — TransitionPreset(…) L30

## lib/core/errors/failures.dart (37 lines)
- L1  class AppFailure (message, cause) — AppFailure(this.message, [this.cause]) L4
- L7  class Stage1Failure extends AppFailure — Stage1Failure(super.message, [super.cause]) L8
- L11  class Stage4Failure extends AppFailure — Stage4Failure(super.message, [super.cause]) L12
- L15  class ParseFailure extends AppFailure — ParseFailure(super.message, [super.cause]) L16
- L19  class FfmpegFailure extends AppFailure (exitCode, stderr) — FfmpegFailure(super.message, [this.exitCode, this.stderr, super.cause]) L22
- L25  class ProviderFailure extends AppFailure (providerId) — ProviderFailure(this.providerId, super.message, [super.cause]) L27
- L30  class ImportFailure extends AppFailure — ImportFailure(super.message, [super.cause]) L31
- L34  class PersistenceFailure extends AppFailure — PersistenceFailure(super.message, [super.cause]) L35

## lib/core/results/result.dart (38 lines)
- L1  class Result — Result() L2
- L5  class Success (value) — Success(this.value) L6
- L10  class Failure (error) — Failure(this.error) L11
- L15  class AppFailure (code, message) — AppFailure(this.code, this.message) L16, toString() L21
- L24  class ProjectValidationFailure extends AppFailure — ProjectValidationFailure(String message) L25
- L29  class ProjectPersistenceFailure extends AppFailure — ProjectPersistenceFailure(String message) L30
- L34  class ProjectRecoveryFailure extends AppFailure — ProjectRecoveryFailure(String message) L35

## lib/core/router/app_router.dart (46 lines)

## lib/core/runtime/foundation_composition.dart (56 lines)
- L6  class FoundationComposition (FoundationComposition, _providerInitializer) — FoundationComposition(…) L7, prepare(List<String> arguments) L15
- L47  class FoundationPreparation (localSmokeConfiguration, providerInitialization) — FoundationPreparation(…) L48

## lib/core/runtime/local_smoke_coordinator.dart (55 lines)
- L3  class LocalSmokeCoordinator (LocalSmokeCoordinator, _reporter, _projectLoaded, _providersRendered, _timelineRendered, _terminal) — LocalSmokeCoordinator(…) L4, onProjectLoaded() L15, onProvidersRendered() L21, onTimelineRendered() L27, onFlutterError(Object error) L33, _writeSuccessIfReady() L38, _write(…) L44

## lib/core/runtime/local_smoke_launch_configuration.dart (119 lines)
- L5  class LocalSmokeLaunchConfiguration (fixture, report) — LocalSmokeLaunchConfiguration(…) L6, parse(List<String> arguments) L14, _parse(List<String> arguments) L22, _hasExtension(String path, String extension) L67, _isExistingRegularFile(File file) L70, _isExistingFileSystemEntity(File file) L79, _hasDirectSystemTempParent(String reportPath) L88, _normalizeLexicalPath(String path) L99, _failure() L108
- L112  class LocalSmokeLaunchFailure extends AppFailure — LocalSmokeLaunchFailure() L113

## lib/core/runtime/local_smoke_reporter.dart (64 lines)
- L8  class FileLocalSmokeReporter (_file) — FileLocalSmokeReporter(this._file) L9, write(Map<String, Object?> report) L14, _validate(Map<String, Object?> report) L26

## lib/core/theme/clipmind_theme.dart (217 lines)
- L3  class ClipMindColors (ClipMindColors, bgBase, bgSurface, bgElevated, accentPrimary, accentHover, accentSoft, textPrimary)
- L35  class ClipMindTheme (ClipMindTheme, _radiusSmall, _radius, _radiusLarge) — dark L44

## lib/core/utils/timecode_utils.dart (69 lines)
- L1  class TimecodeUtils (TimecodeUtils) — _timecodePattern L4, _secondsPattern L8, _minutesPattern L12, parseToMilliseconds(String input) L16, formatMs(int ms) L44, formatShort(int ms) L61
