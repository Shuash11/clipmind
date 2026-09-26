# ClipMind Integration and Verification Plan

**Goal:** Compose completed features, retire active legacy execution only after migration, generate outputs through tooling, and let the controller prove a Windows release smoke run.  
**Architecture:** one injected composition root; explicit local smoke route with offline provider state; coordinator receives widget-render callbacks; Dart harness owns process/report cleanup.  
**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, existing build_runner/Drift/Freezed/json_serializable, integration_test, `dart:io`.  
**Prerequisites:** exits from project foundation, provider platform, agent tools, and tagging/markers.  
**Links:** [spec](../specs/2026-07-27-clipmind-ai-editor-foundation-design.md) · [master](2026-07-27-clipmind-ai-editor-foundation-master-plan.md).

## File-responsibility map

| Path | Responsibility |
|---|---|
| `lib/main.dart`, `lib/app.dart` | dependency graph and explicit smoke routing. |
| `lib/core/runtime/local_smoke_launch_configuration.dart`, `local_smoke_coordinator.dart`, `local_smoke_reporter.dart` | validated inputs, rendered flags, redacted error report. |
| `lib/features/projects/presentation/smoke_fixture_loader.dart`, `local_smoke_screen.dart` | fixture migration/load and deterministic smoke layout. |
| provider screen/form, editor timeline, marker ruler | explicit rendered callbacks and stable test keys. |
| `test/fixtures/projects/legacy_v1_smoke_project.cmproj` | existing legacy v1 input fixture. |
| `integration_test/windows_milestone_smoke_test.dart` | normal-app navigation/interaction regression. |
| `tool/smoke/windows_release_smoke.dart` | release process harness without UI automation. |

## Tasks (4)

### 1. Compose features and validate smoke boundaries

**Create:** runtime configuration/reporter/coordinator, fixture loader/screen, composition and launch-config tests. **Modify:** main/app and feature provider composition only. **Test:** `foundation_composition_test.dart`, `local_smoke_launch_configuration_test.dart`, `local_smoke_coordinator_test.dart`.

**Test first — controller command:** `flutter test test/features/integration/foundation_composition_test.dart test/features/integration/local_smoke_launch_configuration_test.dart test/features/integration/local_smoke_coordinator_test.dart`.

**Expected RED:** smoke can overwrite a file, use a missing/nonabsolute fixture, initialize provider networking, or report before all widgets render.

```dart
// test/features/integration/local_smoke_coordinator_test.dart
// LocalSmokeCoordinator is created by this task at the mapped runtime path.
test('writes once only after every required rendered callback', () async {
  final reporter = MemorySmokeReporter(); // declared in this test and implements LocalSmokeReporter.
  final coordinator = LocalSmokeCoordinator(reporter);
  coordinator.projectLoaded(); coordinator.timelineRendered();
  expect(reporter.reports, isEmpty);
  await coordinator.providersRendered();
  expect(reporter.reports.single, {'projectLoaded': true, 'providersRendered': true, 'timelineRendered': true, 'flutterError': null});
});
```

`LocalSmokeLaunchConfiguration.parse` requires `--clipmind-local-smoke`, exactly one existing absolute `.cmproj` fixture, and exactly one nonexisting absolute `.json` report whose parent is exactly `Directory.systemTemp.absolute`. Reporter creates with `exclusive:true`, writes with flush, and emits only the three booleans plus null/redacted Flutter error code. `main` parses before routing; only valid smoke mode uses `ProviderPlatformBootstrap.initialize(networkEnabled:false)`.

**GREEN command:** rerun RED. **Expected behavior:** invalid inputs fail before routing; no report overwrite; all callbacks required; errors become redacted codes. **Exit:** smoke path has no network dependency.

### 2. Render dedicated smoke layout and retire active legacy routes

**Create:** `LocalSmokeScreen` tests and inspected-defect/suggested-prompt regression tests. **Modify:** app routing, active legacy facades, chat prompts only. **Test:** smoke-screen widget test, defect regression, suggested prompt scope test.

**Test first — controller command:** `flutter test test/features/integration/local_smoke_screen_test.dart test/features/integration/inspected_defects_regression_test.dart test/features/integration/suggested_prompt_scope_test.dart`.

**Expected RED:** smoke needs user navigation or provider network, and legacy direct execution remains active.

```dart
// test/features/integration/local_smoke_screen_test.dart
// FakeSmokeFixtureLoader and offlineProviderState are declared in this test file.
testWidgets('local screen loads fixture and renders both required regions', (tester) async {
  final coordinator = LocalSmokeCoordinator(MemorySmokeReporter());
  await tester.pumpWidget(LocalSmokeScreen(loader: FakeSmokeFixtureLoader.legacyOneClip(), providerState: offlineProviderState(), coordinator: coordinator));
  expect(find.byKey(const ValueKey('timeline-data')), findsOneWidget);
  expect(find.byKey(const ValueKey('custom-provider-form')), findsOneWidget);
});
```

`LocalSmokeScreen` automatically loads/migrates the supplied fixture, renders timeline clip data and the Custom OpenAI-compatible form in one deterministic layout, and passes callbacks from the actual project/timeline/providers widgets to the coordinator. It displays offline fake/no-network provider state. A Flutter error listener calls coordinator failure with a redacted error code. Normal app interaction is separate: integration test opens settings → AI Providers and the custom form; it does not use smoke route. Remove a legacy file only after no active imports; otherwise retain a deprecated forwarding façade with no direct FFmpeg/path execution.

**GREEN command:** rerun RED. **Expected behavior:** no interaction/network required for smoke; normal navigation still works; unsupported analysis/output prompts absent. **Exit:** dedicated local route is deterministic and bounded.

### 3. Add legacy fixture, interaction test, and process harness

**Create:** legacy fixture, Windows integration test, harness. **Modify:** stable widget test keys/callback plumbing only. **Test:** integration test plus harness unit tests where platform-independent.

**Test first — controller command:** `flutter test integration_test/windows_milestone_smoke_test.dart -d windows`.

**Expected RED:** no existing v1 fixture proves migration/timeline/provider form interaction.

```dart
// tool/smoke/windows_release_smoke.dart: core assertion
final report = File('${Directory.systemTemp.path}${Platform.pathSeparator}clipmind-${DateTime.now().microsecondsSinceEpoch}.json');
if (report.existsSync()) throw StateError('report path must be new');
final process = await Process.start(exe.path, ['--clipmind-local-smoke', '--fixture=${fixture.absolute.path}', '--report=${report.absolute.path}']);
try {
  final json = jsonDecode(await waitForSmokeReport(report)) as Map<String, Object?>;
  if (json['projectLoaded'] != true || json['providersRendered'] != true || json['timelineRendered'] != true || json['flutterError'] != null) throw StateError('invalid smoke report');
} finally {
  process.kill();
  if (report.existsSync()) await report.delete();
}
```

The full harness defines `exe`, `fixture`, and `waitForSmokeReport`: fixture is an existing absolute v1 `.cmproj`; report is a direct system-temp child; waiting has a fixed deadline; `finally` terminates process and deletes report. Fixture contains v1 `sourceMediaPaths`, one legacy clip, and timeline data. It is distinct from schema2 tags/markers fixture. Integration verifies normal interaction; harness verifies release process health without UI automation.

**GREEN command:** after release build, `dart run tool/smoke/windows_release_smoke.dart`. **Expected behavior:** exact report assertion, process termination, cleanup. **Exit:** exact master smoke assertion is mechanically represented.

### 4. Generate and execute controller-only native gate chain

**Create:** none. **Modify:** tool-generated annotated source outputs only. **Test:** all named feature/integration suites.

**Test first — controller command:** run each child plan’s focused command; a failure returns to that child before generation.

**Controller-only GREEN chain:**

```text
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter test test/features/projects test/features/providers test/features/agent test/features/tagging test/features/integration
flutter analyze
flutter test
flutter build windows --release
flutter test integration_test/windows_milestone_smoke_test.dart -d windows
dart run tool/smoke/windows_release_smoke.dart
```

Controller confirms generated files are current, every command exits zero, report is valid/cleaned, scope excludes OpenCode runtime/dependency and forbidden files, and all master traceability rows have behavioral evidence. **Exit criteria:** local verified foundation only. **Exclusions:** publication, CI changes, release/version files, installers, dependency upgrades, automatic media analysis. **Next plan:** none; controller issues the local verdict.
