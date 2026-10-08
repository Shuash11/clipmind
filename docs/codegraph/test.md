# Code Graph — test (169 files, 44,995 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## test/features/agent/data/provider_tool_call_normalizer_test.dart (237 lines)
- L8  function main
- L232  function _strictBodyWithNestedArrays

## test/features/agent/domain/editor_tool_registry_test.dart (312 lines)
- L4  function main
- L234  function _names
- L237  function _properties
- L240  function _required
- L243  function _property
- L251  function _expectNumber
- L258  function _assertClosedObjects
- L273  function _assertCamelCasePropertyNames
- L291  function _propertyNames

## test/features/agent/domain/legacy_operation_normalizer_test.dart (140 lines)
- L4  function main

## test/features/agent/domain/malformed_output_repair_policy_test.dart (542 lines)
- L23  function main
- L423  function _finding
- L429  function _request
- L440  function _validResponse
- L452  function _service
- L466  function _submission
- L480  function _success
- L482  function _expectSafeProviderJson
- L517  function _expectSafeRepairJson

## test/features/agent/domain/malicious_tool_call_test.dart (81 lines)
- L11  function main

## test/features/agent/domain/sanitized_project_snapshot_test.dart (210 lines)
- L14  function main
- L103  function _sensitiveDocument
- L183  function _allKeys
- L196  function _allText

## test/features/agent/domain/tool_argument_shape_test.dart (393 lines)
- L17  function main
- L293  function _argumentErrorText
- L311  function _with

## test/features/agent/domain/tool_call_validator_test.dart (355 lines)
- L12  function main

## test/features/agent/domain/validated_plan_payload_test.dart (297 lines)
- L15  function main
- L271  function _argumentErrorText
- L280  function _payload
- L295  function _finding

## test/features/agent/presentation/edit_plan_card_test.dart (205 lines)
- L14  function main
- L188  function _preview

## test/features/agent/presentation/edit_plan_notifier_test.dart (683 lines)
- L21  function main
- L584  function _notifier
- L592  function _payload
- L604  function _plan
- L613  class _Gateway (document, transaction, applyCalls, coherentOutcome) — _Gateway(this.document) L614, currentDocument L621, apply(…) L624
- L640  class _NullableGateway (applyCalls) — currentDocument L643, apply(…) L645
- L654  class _BlockingGateway (document, _result, applyCalls, transaction) — _BlockingGateway(this.document) L655, currentDocument L661, apply(…) L663, complete() L672

## test/features/agent/presentation/edit_plan_payload_integrity_test.dart (146 lines)
- L17  function main
- L99  function _notifier
- L108  function _payload
- L120  class _CapturingGateway (document, preflightDocument, transaction, applyCalls) — _CapturingGateway(this.document) L121, currentDocument L127, apply(…) L129

## test/features/agent/regression/canonical_schema_case_test.dart (82 lines)
- L4  function main
- L62  function _expectClosedCamelCaseObjects

## test/features/agent/regression/deferred_tools_test.dart (89 lines)
- L14  function main

## test/features/agent/regression/preview_transaction_history_test.dart (99 lines)
- L16  function main
- L71  function _notifier
- L79  function _plan
- L88  function _payload

## test/features/integration/foundation_composition_test.dart (157 lines)
- L14  function main
- L110  class _RecordingProviderInitializer (result, networkEnabled) — _RecordingProviderInitializer(…) L111, initialize(…) L123
- L131  class _EmptyProviderRegistry — adapterFor(String providerId) L133, definitionFor(String providerId) L136, definitions L139
- L142  function _unusedSystemTempFile
- L154  function _deleteIfPresent

## test/features/integration/inspected_defects_regression_test.dart (156 lines)
- L16  function main
- L132  function _expectCamelCasePropertyNames

## test/features/integration/local_smoke_coordinator_test.dart (64 lines)
- L5  function main
- L56  class _MemoryLocalSmokeReporter (reports) — write(Map<String, Object?> report) L60

## test/features/integration/local_smoke_launch_configuration_test.dart (214 lines)
- L11  function main
- L193  function _unusedSystemTempFile
- L204  function _tempStem
- L207  function _deleteIfPresent
- L211  function _deleteDirectoryIfPresent

## test/features/integration/local_smoke_screen_test.dart (245 lines)
- L28  function main
- L151  function _offlineProviderInitialization
- L171  class _FakeSmokeFixtureLoader (_FakeSmokeFixtureLoader, _document, _failure) — _FakeSmokeFixtureLoader(this._document) : _failure = false L172, load(File fixture) L179
- L184  class _MemoryLocalSmokeReporter (reports) — write(Map<String, Object?> report) L188
- L193  class _LocalSmokeFiles (fixture, report, configuration) — _LocalSmokeFiles(…) L194, create() L204, delete() L222
- L228  function _unusedSystemTempFile
- L240  function _pumpSmokeFrames

## test/features/integration/suggested_prompt_scope_test.dart (102 lines)
- L5  function main

## test/features/integration/windows_release_smoke_harness_test.dart (67 lines)
- L5  function main
- L61  function _successfulReport

## test/features/projects/compatibility/legacy_public_import_test.dart (42 lines)
- L6  function main

## test/features/projects/data/app_database_migration_test.dart (53 lines)
- L7  function main

## test/features/projects/data/atomic_project_file_store_test.dart (174 lines)
- L9  function main

## test/features/projects/data/import_export_asset_resolution_test.dart (47 lines)
- L9  function main

## test/features/projects/data/project_document_migrator_test.dart (83 lines)
- L10  function fixture
- L13  function main

## test/features/projects/data/project_index_repair_test.dart (66 lines)
- L6  function main

## test/features/projects/data/project_repository_impl_test.dart (98 lines)
- L11  function main

## test/features/projects/data/project_repository_migration_test.dart (64 lines)
- L12  function fixtureJson
- L15  function main

## test/features/projects/domain/cancellation_token_test.dart (27 lines)
- L4  function main

## test/features/projects/domain/command_invariants_regression_test.dart (116 lines)
- L11  function main

## test/features/projects/domain/id_generator_test.dart (65 lines)
- L5  function main

## test/features/projects/domain/project_command_executor_test.dart (55 lines)
- L8  function main

## test/features/projects/domain/project_command_factory_test.dart (110 lines)
- L7  function main

## test/features/projects/domain/project_document_test.dart (64 lines)
- L9  function main

## test/features/projects/domain/project_immutability_test.dart (60 lines)
- L9  function main

## test/features/projects/domain/project_transaction_service_test.dart (195 lines)
- L13  function brightnessTransaction
- L38  function multiCommandTransaction
- L61  function main

## test/features/projects/domain/remove_clip_range_test.dart (161 lines)
- L12  function main

## test/features/projects/domain/result_contract_test.dart (23 lines)
- L4  class ExternalProjectFailure extends AppFailure — ExternalProjectFailure() L5
- L9  function main

## test/features/projects/presentation/timeline_transaction_bridge_test.dart (27 lines)
- L8  function main

## test/features/projects/support/legacy_v1_database.dart (107 lines)
- L10  class LegacyV1ProjectIndexFixture (executor, _directory) — LegacyV1ProjectIndexFixture(…) L11, dispose() L19
- L23  function legacyV1ProjectIndexFixture
- L46  class _LegacyV1Seeder — schemaVersion L48, beforeOpen(QueryExecutor executor, OpeningDetails _) L51

## test/features/projects/support/project_fakes.dart (174 lines)
- L13  class SequenceIdGenerator (_values) — SequenceIdGenerator(Iterable<String> values) : _values = values.iterator L14, next() L19
- L25  enum FileIoFailure
- L27  class MemoryProjectFileIo (files, failurePoints, operations) — MemoryProjectFileIo([Map<String, String>? initial]) : files = L28, exists(String path) L34, read(String path) L37, writeAndFlush(String path, String content) L40, copy(String from, String to) L49, rename(String from, String to) L58, delete(String path) L77
- L86  class FakeProjectIndex (failUpsert, upsertCalls, documents) — upsert(ProjectDocument document) L91, clear() L98, projectPaths() L101
- L104  class RecordingProjectRepository (document, failSave, nextWarnings, saveCalls) — RecordingProjectRepository(this.document) L105, save(ProjectDocument candidate) L111, load(String path) L123
- L127  class RecordingProjectDocumentPublisher (document, warnings, publishCalls) — publish(…) L133
- L143  class FakeProjectDocumentLocator (documentsByPath) — FakeProjectDocumentLocator(this.documentsByPath) L144, listProjectPaths() L147, readDocument(String path) L151
- L155  class RecordingRenderGateway (inputPaths, renderCalls) — render(List<String> paths) L159
- L165  class RecordingProjectTransactionGateway (transactions, directRepositorySaves) — apply(EditTransaction transaction) L170

## test/features/projects/support/project_test_data.dart (120 lines)
- L14  function stateWithOneClip
- L70  function documentWithOneClip
- L90  function recordFor
- L111  function textOverlayFixture

## test/features/providers/data/adapters/anthropic_adapter_test.dart (292 lines)
- L16  function _adapter
- L26  function _page
- L31  function _modelPage
- L43  function main

## test/features/providers/data/adapters/gemini_adapter_test.dart (127 lines)
- L13  function main

## test/features/providers/data/adapters/ollama_adapter_test.dart (109 lines)
- L12  function main

## test/features/providers/data/adapters/openai_compatible_adapter_test.dart (215 lines)
- L15  function main

## test/features/providers/data/legacy_provider_settings_migration_test.dart (263 lines)
- L10  function main
- L185  function _migration
- L202  class _Storage (value, failAtWrite, writes) — read() L207, write(String contents) L209
- L216  class _Settings (value) — _Settings(this.value) L217, load() L220
- L224  class _LegacyCredentials (values, failDelete) — _LegacyCredentials(this.values) L225, deleteApiKey(String providerId) L229, readApiKey(String providerId) L236
- L240  class _Credentials (values, writes, failWrite) — delete(String credentialId) L245, read(String credentialId) L251, write(String credentialId, String secret) L254

## test/features/providers/data/provider_catalog_test.dart (54 lines)
- L5  function main

## test/features/providers/data/provider_endpoint_resolver_test.dart (32 lines)
- L4  function main

## test/features/providers/data/provider_http_transport_test.dart (249 lines)
- L10  function main
- L232  class _FakeClient (_results, attempts) — _FakeClient(this._results) L233, send(ProviderHttpRequest request) L239

## test/features/providers/data/provider_platform_bootstrap_test.dart (223 lines)
- L17  function main
- L152  class _Profiles (events, document, resumeFailure) — _Profiles(this.events) L153, deleteProfile(…) L159, load() L165, resumePendingDeletions(…) L171, save(ProviderProfilesDocument document) L180
- L184  function _document
- L200  class _Credentials — delete(String credentialId) L202, read(String credentialId) L205, write(String credentialId, String secret) L208
- L212  class _Transport (calls) — send(…) L215

## test/features/providers/data/provider_profile_deletion_test.dart (208 lines)
- L11  function main
- L142  function _document
- L166  class _Storage (value, failWrite, failAtWrite, writes) — read() L172, write(String contents) L174
- L183  class _Credentials (values, failDelete, failAtDelete, deleted) — _Credentials(this.values) L184, delete(String credentialId) L190, read(String credentialId) L200, write(String credentialId, String secret) L203

## test/features/providers/data/provider_profile_repository_test.dart (256 lines)
- L12  function main
- L212  function _metadataProfile
- L223  function _profileJson
- L244  class _MemoryStorage (value, writes) — _MemoryStorage([this.value]) L245, read() L249, write(String contents) L251

## test/features/providers/data/provider_redactor_test.dart (64 lines)
- L6  function main
- L53  class _FailingBackend — delete(…) L55, read(…) L58, write(…) L61

## test/features/providers/data/provider_url_policy_test.dart (55 lines)
- L5  function main

## test/features/providers/domain/provider_contract_test.dart (281 lines)
- L21  function main
- L218  function _payload
- L224  class _ProfileScopedAdapter — complete(…) L226, discoverModels(…) L237, testConnection(…) L245
- L255  class _NetworkAwareBootstrap (networkEnabled) — initialize(…) L259
- L271  class _EmptyRegistry — adapterFor(String providerId) L273, definitionFor(String providerId) L276, definitions L279

## test/features/providers/presentation/ai_providers_screen_test.dart (217 lines)
- L17  function main
- L209  class _SettingsPlaceholder extends StatelessWidget — _SettingsPlaceholder() L210, build(BuildContext context) L212

## test/features/providers/presentation/dynamic_model_selector_test.dart (1139 lines)
- L19  function main

## test/features/providers/presentation/model_selector_dropdown_test.dart (27 lines)
- L7  function main

## test/features/providers/presentation/provider_profile_form_test.dart (510 lines)
- L20  function main
- L494  function _draft

## test/features/providers/security/key_egress_canary_test.dart (991 lines)
- L72  function _containsCanary
- L74  function _metadataProfile
- L90  function _turnRequest
- L95  function _requestContextFailure
- L115  function _stubPostFailure
- L136  class _GenAErrorCase (withQueryParameters) — _GenAErrorCase(…) L137, Function(Dio dio) build L143, Function() failure L144
- L148  class _MockDio extends Mock implements Dio
- L150  class _StubSettingsRepository extends SettingsRepository — load() L152, save(AppSettings settings) L154
- L159  class _CanaryKeyStore extends SecureKeyStore — readApiKey(String provider) L161
- L164  class _MemorySecureBackend (values) — delete(…) L167, read(…) L169, write(…) L171
- L178  class _FailingSecureBackend — delete(…) L180, read(…) L182, write(…) L184
- L188  class _MemoryProfileStorage (value) — read() L191, write(String contents) L193
- L196  class _FixedLegacySettings (value) — _FixedLegacySettings(this.value) L197, load() L200
- L204  class _MapLegacyCredentials (values) — _MapLegacyCredentials(this.values) L205, deleteApiKey(String providerId) L208, readApiKey(String providerId) L214
- L218  class _MapCredentialStore (values, failWrite) — delete(String credentialId) L222, read(String credentialId) L228, write(String credentialId, String secret) L231
- L240  class _ScriptedClient (_results) — _ScriptedClient(this._results) L241, send(ProviderHttpRequest request) L244
- L253  function main

## test/features/providers/support/provider_adapter_fakes.dart (54 lines)
- L7  class RecordingTransport (responses, requests) — RecordingTransport(this.responses) L8, send(…) L13
- L22  class MemoryCredentials (values) — MemoryCredentials([Map<String, String> values = const <String, String>…) L23, delete(String credentialId) L28, read(String credentialId) L34, write(String credentialId, String secret) L38
- L44  function testProfile

## test/features/providers/support/provider_presentation_fakes.dart (187 lines)
- L18  class MemoryProfileRepository (document, saveFailure, deleteFailure) — MemoryProfileRepository(this.document) L19, load() L24, save(ProviderProfilesDocument value) L26, deleteProfile(…) L33, resumePendingDeletions(…) L45
- L50  class MemoryCredentialStore (values, writeFailure, deleteFailure, writes, deletes) — delete(String credentialId) L57, read(String credentialId) L65, write(String credentialId, String secret) L68
- L76  class FakeProviderRegistry (_definitions, adapter, _adapters) — FakeProviderRegistry(…) L77, definitions L87, adapterFor(String providerId) L89, definitionFor(String providerId) L92
- L100  class DiscoveringAdapter (models) — DiscoveringAdapter(this.models) L101, discoverModels(…) L104, testConnection(…) L109, complete(…) L114
- L124  class CountingDiscoveryAdapter (models, holdDiscovery, discoveryCalls, _pending) — CountingDiscoveryAdapter(this.models,…) L125, releaseDiscovery() L133, discoverModels(…) L139, testConnection(…) L153, complete(…) L158
- L166  class FailingDiscoveryAdapter — FailingDiscoveryAdapter() L167, discoverModels(…) L169, testConnection(…) L176, complete(…) L181

## test/features/tagging/domain/marker_layout_test.dart (186 lines)
- L6  function main
- L175  function _point
- L178  function _range

## test/features/tagging/domain/tag_marker_command_invariants_test.dart (239 lines)
- L14  function main
- L237  function _factory

## test/features/tagging/domain/tag_query_test.dart (89 lines)
- L5  function main
- L77  function _asset

## test/features/tagging/domain/tagging_controller_test.dart (96 lines)
- L9  function main

## test/features/tagging/integration/ai_tag_marker_plan_test.dart (82 lines)
- L16  function main

## test/features/tagging/integration/tag_marker_reopen_test.dart (78 lines)
- L9  function _fixtureJson
- L13  function main
- L68  function _containsKey

## test/features/tagging/presentation/clip_tag_inspector_test.dart (116 lines)
- L11  function main
- L107  function _stateWithClipTags

## test/features/tagging/presentation/marker_editor_dialog_test.dart (98 lines)
- L5  function main
- L82  function _dialogHost

## test/features/tagging/presentation/marker_ruler_test.dart (190 lines)
- L13  function main
- L162  function _markerHarness

## test/features/tagging/presentation/media_panel_test.dart (140 lines)
- L14  function main
- L103  function _mediaDocument

## test/features/tagging/presentation/tag_editor_dialog_test.dart (92 lines)
- L5  function main
- L74  function _dialogHost

## test/features/tagging/presentation/timeline_bridge_test.dart (107 lines)
- L15  function main

## test/features/tagging/presentation/tool_rail_tagging_test.dart (50 lines)
- L10  function main

## test/features/tagging/regression/no_automatic_analysis_test.dart (61 lines)
- L5  function main

## test/features/tagging/support/tagging_widget_harness.dart (82 lines)
- L14  class TaggingWidgetHarness (document, repository, publisher, transactions, controller, providers) — TaggingWidgetHarness(…) L15
- L58  function taggingTestApp
- L66  class UpdatingProjectDocumentPublisher (publishCalls) — UpdatingProjectDocumentPublisher(this._onPublish) L68, Function(ProjectDocument document) _onPublish L70, publish(…) L74

## test/integration/core_path_seam_test.dart (218 lines)
- L33  function _synthAv
- L64  function _mockPathProvider
- L84  function main

## test/integration/integration_test.dart (68 lines)
- L8  function _testApp
- L21  function main

## test/integration/url_import_seam_test.dart (179 lines)
- L19  function main
- L175  function _parentName

## test/tool/grapify_test.dart (125 lines)
- L8  class ActiveLlmConfig (providerId, model) — ActiveLlmConfig(…) L12, describe() L14, label L15
- L18  typedef ActiveProfileResolver
- L20  class Base extends Super with Mixin implements Face — run() L21
- L24  function topLevelFn
- L29  function main
- L77  function real

## test/unit/agent/agent_confirmation_test.dart (418 lines)
- L20  class _ScriptProvider extends LlmProvider (script, calls) — _ScriptProvider(this.script) L24, id L27, supportsToolCalling L30, chatWithTools(AgentTurnRequest request) L33, availableModels() L38, parseCommand(AgentRequest request) L41, watchConnection() L45
- L49  class _CountingExecutor (calls, seenIds) — execute(ToolCall call) L54
- L61  class _BulkGate (approve, calls, seen) — _BulkGate(…) L66, requiresPerEditApproval L69, ask(ConfirmationRequest request) L72
- L79  class _PerEditGate (approve, calls, seen) — _PerEditGate(…) L84, requiresPerEditApproval L87, ask(ConfirmationRequest request) L90
- L97  class _CancelGate (controller, calls) — _CancelGate(this.controller) L101, requiresPerEditApproval L104, ask(ConfirmationRequest request) L107
- L117  function _registryWith
- L124  function _validated
- L142  function _context
- L179  function _edit
- L185  function main

## test/unit/agent/filter_escaping_test.dart (124 lines)
- L4  function main

## test/unit/agent/nl2vec_pipeline_test.dart (752 lines)
- L16  class _StubProvider extends LlmProvider (response) — _StubProvider(this.response) L18, id L21, availableModels() L24, parseCommand(AgentRequest request) L27, watchConnection() L30
- L35  class _ScriptToolProvider extends LlmProvider (script, calls) — _ScriptToolProvider(this.script) L39, id L42, supportsToolCalling L45, chatWithTools(AgentTurnRequest request) L48, availableModels() L52, parseCommand(AgentRequest request) L55, watchConnection() L59
- L63  class _FakeFfmpegService extends FfmpegService — _FakeFfmpegService() : super(tempDir: Directory.systemTemp.path) L64, runSync(FfmpegJob job) L67
- L75  function _projectWithClip
- L108  function main

## test/unit/agent/ollama_tool_calling_smoke_test.dart (172 lines)
- L22  class _MockDio extends Mock implements Dio
- L24  class _MockKeyStore extends Mock implements SecureKeyStore
- L26  class _OkExecutor — execute(ToolCall call) L28
- L34  function main

## test/unit/agent/stage_5_composed_audio_test.dart (162 lines)
- L14  function main

## test/unit/agent/timecode_utils_test.dart (106 lines)
- L4  function main
- L103  function _tc

## test/unit/agent/tool_calling_agent_test.dart (1150 lines)
- L29  class _ScriptProvider extends LlmProvider (script, seen, calls) — _ScriptProvider(this.script) L34, id L37, supportsToolCalling L40, chatWithTools(AgentTurnRequest request) L43, availableModels() L49, parseCommand(AgentRequest request) L52, watchConnection() L56
- L62  class _NimScriptProvider extends _ScriptProvider — _NimScriptProvider(super.script) L63, id L66
- L73  class _GeminiScriptProvider extends _ScriptProvider — _GeminiScriptProvider(super.script) L74, id L77
- L82  class _SlowLocalScriptProvider extends _ScriptProvider — _SlowLocalScriptProvider(super.script) L83, id L86, suggestedRoundTimeoutSeconds L89
- L92  class _OkExecutor — execute(ToolCall call) L94
- L100  class _FailExecutor — execute(ToolCall call) L102
- L107  class _RecordingGate (approve, calls, seen) — _RecordingGate(…) L112, requiresPerEditApproval L115, ask(ConfirmationRequest request) L118
- L127  class _JournalAndCancel (ctx, controller) — _JournalAndCancel(this.ctx, this.controller) L128, execute(ToolCall call) L134
- L147  function _registryWith
- L156  function _validated
- L175  function _loadTurn
- L187  function _context
- L229  function main

## test/unit/agent/tools/add_transition_test.dart (589 lines)
- L20  class _MockFfprobe extends Mock implements FfprobeService
- L22  class _FakeFfmpeg extends FfmpegService (jobs) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L23, runSync(FfmpegJob job) L28
- L41  class _Applied (op, path, removeClipIds) — _Applied(this.op, this.path, this.removeClipIds) L45
- L68  function _project
- L103  function main

## test/unit/agent/tools/apply_effect_test.dart (352 lines)
- L19  class _MockFfprobe extends Mock implements FfprobeService
- L21  class _FakeFfmpeg extends FfmpegService (jobs) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L22, runSync(FfmpegJob job) L27
- L40  function _project
- L68  function main

## test/unit/agent/tools/burn_captions_test.dart (467 lines)
- L22  class _MockFfprobe extends Mock implements FfprobeService
- L24  class _FakeFfmpeg extends FfmpegService (_failStderr, jobs) — _FakeFfmpeg(…) L25, runSync(FfmpegJob job) L31
- L52  function _project
- L80  function main

## test/unit/agent/tools/command_tool_executor_test.dart (450 lines)
- L19  function _project
- L45  function _ctx
- L64  function _stateWithFreeAsset
- L71  function main

## test/unit/agent/tools/edit_tool_executor_test.dart (846 lines)
- L18  class _MockFfprobe extends Mock implements FfprobeService
- L23  class _RecordingFfprobe extends FfprobeService (hasAudio, throwOnProbe, probedPaths) — _RecordingFfprobe(…) L24, extractMetadata(String filePath) L31
- L52  class _MergeFfprobe extends FfprobeService (audioByPath, durationMsByPath, throwOnProbe, probedPaths) — _MergeFfprobe(…) L53, extractMetadata(String filePath) L65
- L81  class _FakeFfmpeg extends FfmpegService (lastJob) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L84, runSync(FfmpegJob job) L87
- L96  class _Applied (op, path) — _Applied(this.op, this.path) L99
- L102  function _project
- L139  function _rangedProject
- L151  function main

## test/unit/agent/tools/overlay_text_font_test.dart (267 lines)
- L17  class _MockFfprobe extends Mock implements FfprobeService
- L19  class _FakeFfmpeg extends FfmpegService (lastJob) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L22, runSync(FfmpegJob job) L25
- L34  class _Applied (op, path) — _Applied(this.op, this.path) L37
- L41  function _fakeResolve
- L54  function _project
- L82  function main

## test/unit/agent/tools/read_tool_executor_test.dart (146 lines)
- L13  class _MockFfprobe extends Mock implements FfprobeService
- L15  function _project
- L59  function _ctx
- L71  function main

## test/unit/agent/tools/read_tools_phase6_test.dart (529 lines)
- L18  class _MockFfprobe extends Mock implements FfprobeService
- L24  class _FakeResolver extends FfmpegBinaryResolver — resolveFfmpeg(…) L26
- L29  class _NoWhisper extends WhisperTranscriptionService — findBinary(…) L31
- L34  class _FakeFfmpeg extends FfmpegService (wavExtracts) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L37, runSync(FfmpegJob job) L40
- L53  function _project
- L88  function main

## test/unit/agent/tools/support/fake_project_command_gateway.dart (46 lines)
- L11  class FakeProjectCommandGateway (state, batches, nextResult) — FakeProjectCommandGateway(…) L12, appliedCommands L18, snapshot() L23, applyCommands(…) L26

## test/unit/agent/tools/tool_prompts_test.dart (100 lines)
- L5  function _def
- L17  function main

## test/unit/agent/tools/tool_registry_test.dart (271 lines)
- L11  class _StubExecutor — execute(ToolCall call) L13
- L17  function main

## test/unit/agent/tools/tool_selection_test.dart (302 lines)
- L6  class _StubExecutor — execute(ToolCall call) L8
- L12  function _selection
- L56  function main

## test/unit/core/effect_presets_test.dart (101 lines)
- L15  function main

## test/unit/core/transition_presets_test.dart (127 lines)
- L26  function main

## test/unit/data/chat_step_test.dart (100 lines)
- L5  function main

## test/unit/data/media_analysis_dao_test.dart (146 lines)
- L5  function main

## test/unit/data/project_file_store_test.dart (128 lines)
- L13  function main
- L88  function _project
- L118  function _tempFiles

## test/unit/data/project_repository_load_test.dart (98 lines)
- L16  function main
- L71  function _project

## test/unit/data/project_repository_persistence_test.dart (136 lines)
- L17  function _mockPathProvider
- L40  function main
- L98  function _project
- L126  function _tempFiles

## test/unit/domain/usecases/export_args_test.dart (422 lines)
- L21  class _CapturingFfmpeg extends FfmpegService (_tmp, jobs, createTempPathCalls, _counter) — _CapturingFfmpeg(this._tmp) : super(tempDir: _tmp.path) L22, lastJob L29, createTempPath(…) L32, run(FfmpegJob job) async* L39, cancel() L59
- L62  function _clip
- L81  function _project
- L107  function _joined
- L112  function _export
- L128  function main

## test/unit/domain/usecases/export_flow_test.dart (302 lines)
- L17  class _FlowFfmpeg extends FfmpegService (_tmp, script, createFile, delay, shouldThrow, jobs, tempCalls, cancelCalled) — _FlowFfmpeg(…) L18, Function()? onCreateTempPath L30, createTempPath(…) L37, run(FfmpegJob job) async* L44, cancel() L75
- L80  function _project
- L107  function _options
- L133  function main

## test/unit/domain/usecases/structural_edit_usecase_test.dart (551 lines)
- L8  function _clip
- L19  function _project
- L39  function _op
- L51  function _ids
- L54  function _positions
- L57  function main

## test/unit/domain/usecases/undo_redo_usecase_test.dart (187 lines)
- L6  function _project
- L19  function _op
- L27  function main

## test/unit/ffmpeg/add_sound_routing_test.dart (255 lines)
- L12  class _FakeFfmpeg extends FfmpegService — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L13, runSync(FfmpegJob job) L16
- L28  function _op
- L42  function main

## test/unit/ffmpeg/combo_live_gates_test.dart (356 lines)
- L32  function _synthAv
- L48  function _mapSingleJob
- L61  function _runJob
- L69  function main

## test/unit/ffmpeg/command_builder_test.dart (890 lines)
- L4  function main

## test/unit/ffmpeg/command_mapper_restriction_test.dart (453 lines)
- L9  function main

## test/unit/ffmpeg/composed_watermark_mapping_test.dart (347 lines)
- L14  function main

## test/unit/ffmpeg/effect_range_preset_test.dart (196 lines)
- L11  function main

## test/unit/ffmpeg/export_live_gates_test.dart (423 lines)
- L36  function _synthAv
- L56  function _synthDark
- L68  function _frameRgb
- L98  function _stripMean
- L111  function main

## test/unit/ffmpeg/procedural_sound_service_test.dart (146 lines)
- L8  class _NoFfmpeg extends FfmpegBinaryResolver — resolveFfmpeg(…) L10
- L17  class _FakeResolver extends FfmpegBinaryResolver — resolveFfmpeg(…) L19
- L22  function main

## test/unit/ffmpeg/scene_detection_service_test.dart (176 lines)
- L7  class _NoFfmpeg extends FfmpegBinaryResolver — resolveFfmpeg(…) L9
- L16  class _FakeResolver extends FfmpegBinaryResolver — resolveFfmpeg(…) L18
- L29  function main

## test/unit/ffmpeg/service_timeout_test.dart (496 lines)
- L10  class _FakeResolver extends FfmpegBinaryResolver — resolveFfmpeg(…) L12, resolveFfprobe(…) L15
- L18  function _neverCompletes
- L24  function _neverCompletesJob
- L35  function main
- L457  function _neverListStream
- L462  class _FakeStreamingProcess (stdoutStream, stderrStream, exitCodeFuture, killed) — _FakeStreamingProcess(…) L463, stdout L476, stderr L479, exitCode L482, pid L485, stdin L488, kill([ProcessSignal signal = ProcessSignal.sigterm]) L491

## test/unit/ffmpeg/transition_live_gates_test.dart (113 lines)
- L31  function _synthAv
- L45  function main

## test/unit/ffmpeg/watermark_live_gates_test.dart (328 lines)
- L29  function _synthAv
- L47  function _synthWatermark
- L61  function _mapSingleJob
- L79  function _runJob
- L87  function main

## test/unit/fonts/font_resolver_test.dart (134 lines)
- L7  function main

## test/unit/import/url_import_service_test.dart (613 lines)
- L11  class _MockDio extends Mock implements Dio
- L13  function _noopProgress
- L34  function _headers
- L45  function _stubDownload
- L77  function _stubDioFailure
- L88  function _verifyNoDownload
- L99  function _basename
- L101  function _parentName
- L111  function _expectStoredAs
- L124  function main

## test/unit/import/youtube_import_service_test.dart (812 lines)
- L15  function main
- L711  function _createTempOutputDir
- L723  function _outputFolderOf
- L726  function _normalize
- L728  function _basename
- L755  function _neverListStream
- L761  class _FakeYtDlpProcess (stdoutStream, stderrStream, killExitCode, _exitCompleter, killed) — _FakeYtDlpProcess(…) L762, pid L783, stdout L786, stderr L789, exitCode L792, stdin L795, kill([ProcessSignal signal = ProcessSignal.sigterm]) L798, completeExit(int code) L808

## test/unit/llm/anthropic_provider_tools_test.dart (278 lines)
- L8  class _MockDio extends Mock implements Dio
- L10  function _request
- L33  function main

## test/unit/llm/custom_openai_compatible_provider_test.dart (329 lines)
- L17  function _interceptingDio
- L35  function _toolCallsResponse
- L63  function _request
- L85  function main

## test/unit/llm/gemini_provider_tools_test.dart (456 lines)
- L11  class _MockDio extends Mock implements Dio
- L13  class _MockKeyStore extends Mock implements SecureKeyStore
- L24  function _request
- L40  function _provider
- L50  function _partsResponse
- L67  function main

## test/unit/llm/nvidia_nim_provider_tools_test.dart (432 lines)
- L13  class _MockDio extends Mock implements Dio
- L15  class _MockKeyStore extends Mock implements SecureKeyStore
- L17  function _request
- L40  function _provider
- L50  function _textResponse
- L65  function main

## test/unit/llm/ollama_provider_tools_test.dart (359 lines)
- L13  class _MockDio extends Mock implements Dio
- L15  class _MockKeyStore extends Mock implements SecureKeyStore
- L17  function _request
- L40  function _provider
- L55  function _textResponse
- L70  function main

## test/unit/llm/openai_provider_tools_test.dart (292 lines)
- L11  class _MockDio extends Mock implements Dio
- L13  function _request
- L36  function main

## test/unit/llm/provider_conformance_test.dart (330 lines)
- L24  class _MockDio extends Mock implements Dio
- L26  class _MockKeyStore extends Mock implements SecureKeyStore
- L28  class _Captured (path, body, headers)
- L34  function _nullKeys
- L40  function _scriptedDio
- L61  function _answer
- L79  function _request
- L101  function _openAiToolResponse
- L123  function _anthropicToolResponse
- L136  function _geminiToolResponse
- L155  class _TransportSpec (path, auth, extras, absent) — _TransportSpec(…) L156
- L169  function main

## test/unit/state/agent_analysis_port_test.dart (91 lines)
- L8  function main

## test/unit/state/agent_run_controller_test.dart (1333 lines)
- L39  class _LegacyStub extends LlmProvider (response) — _LegacyStub(this.response) L41, id L44, availableModels() L47, parseCommand(AgentRequest request) L50, watchConnection() L54
- L58  class _ScriptTools extends LlmProvider (script, gate, calls) — _ScriptTools(this.script, [Completer<void>? gate]) L63, id L67, supportsToolCalling L70, chatWithTools(AgentTurnRequest request) L73, availableModels() L80, parseCommand(AgentRequest request) L83, watchConnection() L87
- L91  class _FakeRegistry extends ProviderRegistry (active) — _FakeRegistry(this.active) L93, getActiveProvider() L96
- L99  class _CapturingPipeline extends Nl2VecPipeline (seenHistory, seenDryRun) — Function(String kind)? seenReadAnalysis L102, Function(String kind, Map<String, dynamic> payload)? seenWriteAnalysis L103, Function()? seenWhisperConfig L104, Function(String familyId)? seenResolveFont L105, Function(String familyId)? seenPlannedResolveFont L106, result L107, _CapturingPipeline() : super(ffmpegService: FfmpegService()) L110, submitCommand(…) L113, executePlanned(…) L140
- L157  class _GatedSettingsRepo extends SettingsRepository (gate) — _GatedSettingsRepo(this.gate) L159, load() L162
- L173  class _TestSettingsRepository extends SettingsRepository (saved) — load() L177, save(AppSettings settings) L180
- L185  class _FakeFfmpeg extends FfmpegService (cancelCalls) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L188, runSync(FfmpegJob job) L191, cancel() L199
- L205  function _project
- L233  function main

## test/unit/state/cut_range_test.dart (523 lines)
- L27  class _RecordingRepository extends ProjectRepository (saves) — _RecordingRepository(super.db) L30, save(Project project) L33
- L38  class _FakeFfmpeg extends FfmpegService (lastJob) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L41, runSync(FfmpegJob job) L44
- L53  function _project
- L91  function _trimmedProject
- L105  function _rangedProject
- L116  function _cutOp
- L129  function _clips
- L136  function _clip
- L141  function _flagValue
- L148  function _betweenValues
- L158  function main

## test/unit/state/export_after_manual_edit_test.dart (275 lines)
- L34  class _RecordingRepository extends ProjectRepository — _RecordingRepository(super.db) L35, save(Project project) L38
- L41  class _EditExportFfmpeg extends FfmpegService (_tmp, exportJobs, lastCutJob, _counter) — _EditExportFfmpeg(this._tmp) : super(tempDir: _tmp.path) L42, createTempPath(…) L50, runSync(FfmpegJob job) L56, run(FfmpegJob job) async* L69, cancel() L83
- L86  function _project
- L124  function _joined
- L126  function main

## test/unit/state/manual_edit_adjustments_test.dart (593 lines)
- L20  class _RecordingRepository extends ProjectRepository (saves) — _RecordingRepository(super.db) L23, save(Project project) L26
- L31  class _FakeFfmpeg extends FfmpegService (jobs) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L34, runSync(FfmpegJob job) L37
- L46  class _FakeFfprobe extends FfprobeService — extractMetadata(String filePath) L48
- L53  class _RecordingFfprobe extends FfprobeService (hasAudio, probedPaths) — _RecordingFfprobe(…) L54, extractMetadata(String filePath) L60
- L74  function _project
- L108  function _clipOf
- L115  function main

## test/unit/state/manual_edit_panels_test.dart (424 lines)
- L23  class _RecordingRepository extends ProjectRepository (saves) — _RecordingRepository(super.db) L26, save(Project project) L29
- L34  class _FakeFfmpeg extends FfmpegService (jobs) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L37, runSync(FfmpegJob job) L40
- L49  class _FakeFfprobe extends FfprobeService (meta, probedPaths) — _FakeFfprobe(this.meta) L50, extractMetadata(String filePath) L56
- L62  class _FakeSound extends ProceduralSoundService (tmpDir, generatedFor) — _FakeSound(this.tmpDir) L63, generate(…) L69
- L83  function _meta
- L93  function _project
- L122  function _sourceOf
- L130  function main

## test/unit/state/manual_edit_recipe_range_test.dart (208 lines)
- L20  class _RecordingRepository extends ProjectRepository — _RecordingRepository(super.db) L21, save(Project project) L24
- L27  class _FakeFfmpeg extends FfmpegService (jobs) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L30, runSync(FfmpegJob job) L33
- L42  class _FakeFfprobe extends FfprobeService — extractMetadata(String filePath) L44
- L55  function _project
- L84  function _clipOf
- L97  function main

## test/unit/state/manual_edit_transition_test.dart (353 lines)
- L20  class _RecordingRepository extends ProjectRepository (saves) — _RecordingRepository(super.db) L23, save(Project project) L26
- L31  class _FakeFfmpeg extends FfmpegService (jobs) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L34, runSync(FfmpegJob job) L37
- L46  class _FakeFfprobe extends FfprobeService — _FakeFfprobe(this.resolve) L47, Function(String path) resolve L49, extractMetadata(String filePath) L52
- L56  function _meta
- L73  function _project
- L116  function main

## test/unit/state/manual_trim_split_test.dart (331 lines)
- L26  class _RecordingRepository extends ProjectRepository (saves) — _RecordingRepository(super.db) L29, save(Project project) L32
- L37  function _project
- L74  function _clips
- L81  function _lastJournaled
- L87  function main

## test/unit/state/player_provider_test.dart (72 lines)
- L14  function main

## test/unit/state/project_command_gateway_test.dart (137 lines)
- L11  function main

## test/unit/state/project_providers_test.dart (121 lines)
- L9  function _project
- L58  function _op
- L65  function main

## test/unit/state/project_save_failure_test.dart (163 lines)
- L16  class _ToggleableProjectRepository extends ProjectRepository (failSave, saveCalls) — _ToggleableProjectRepository(…) L17, failure L20, save(Project project) L25
- L31  function _project
- L59  function main

## test/unit/state/provider_registry_profile_resolution_test.dart (309 lines)
- L20  class _StubSettingsRepository extends SettingsRepository — load() L22, save(AppSettings settings) L24
- L27  function main

## test/unit/state/runtime_provider_wiring_test.dart (307 lines)
- L33  class _FakeGenBRegistry — definitions L35, definitionFor(String providerId) L38, adapterFor(String providerId) L41
- L44  class _FakeRepository (document) — _FakeRepository(this.document) L45, load() L50, save(ProviderProfilesDocument document) L54, deleteProfile(…) L58, resumePendingDeletions(…) L64
- L69  class _FakeCredentials — read(String credentialId) L71, write(String credentialId, String secret) L75, delete(String credentialId) L79
- L83  class _StubSettingsRepository extends SettingsRepository — load() L85, save(AppSettings settings) L88
- L91  function main
- L292  class _WritingFfmpeg extends FfmpegService — _WritingFfmpeg() : super(tempDir: Directory.systemTemp.path) L293, runSync(FfmpegJob job) L296

## test/unit/state/status_providers_test.dart (307 lines)
- L24  class _ScriptProvider extends LlmProvider — health L25, id L29, availableModels() L32, parseCommand(AgentRequest request) L35, watchConnection() L39
- L42  class _FakeRegistry extends ProviderRegistry (active) — _FakeRegistry(this.active) L44, getActiveProvider() L47
- L50  class _FakeGenBRegistry — definitions L52, definitionFor(String providerId) L55, adapterFor(String providerId) L58
- L61  class _FakeProfileRepository (document) — _FakeProfileRepository(this.document) L62, load() L67, save(ProviderProfilesDocument document) L71, deleteProfile(…) L75, resumePendingDeletions(…) L81
- L86  class _FakeCredentials — read(String credentialId) L88, write(String credentialId, String secret) L92, delete(String credentialId) L96
- L100  class _StubResolver extends FfmpegBinaryResolver (value, throws) — _StubResolver(…) L103, resolveFfmpeg(…) L106
- L112  function main

## test/unit/state/structural_edit_flow_test.dart (342 lines)
- L20  class _RecordingRepository extends ProjectRepository (saves) — _RecordingRepository(super.db) L23, save(Project project) L26
- L31  class _FakeFfmpeg extends FfmpegService (lastJob) — _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path) L34, runSync(FfmpegJob job) L37
- L46  function _project
- L83  function _op
- L96  function _clipIds
- L110  function _betweenValues
- L119  function main

## test/unit/state/undo_redo_flow_test.dart (179 lines)
- L15  class _RecordingRepository extends ProjectRepository (saves, lastSaved) — _RecordingRepository(super.db) L19, save(Project project) L22
- L28  function _project
- L56  function _trimOp
- L64  function _sourceOf
- L74  function main
- L172  function _sourceOfProject

## test/unit/updates/asset_verifier_test.dart (112 lines)
- L8  function main

## test/unit/updates/release_digest_live_gate_test.dart (112 lines)
- L26  function main

## test/unit/updates/update_downloader_test.dart (443 lines)
- L8  class _StarterCall (executable, arguments) — _StarterCall(this.executable, this.arguments) L9
- L20  class _MarkerWritingStarter (calls) — Function()? onMarker L22, _MarkerWritingStarter(…) L24, call(String executable, List<String> arguments) L26
- L40  class _RecordingStarter (calls) — call(String executable, List<String> arguments) L43
- L49  function _serveBytes
- L59  function _updateTempDirs
- L66  function main

## test/unit/updates/update_result_reader_test.dart (93 lines)
- L8  function main

## test/widget/agent_chat_panel_test.dart (1061 lines)
- L40  class _StubProvider extends LlmProvider — id L42, availableModels() L45, parseCommand(AgentRequest request) L48, watchConnection() L52
- L56  class _FakeRegistry extends ProviderRegistry (active) — _FakeRegistry(this.active) L58, getActiveProvider() L61
- L66  class _GatePipeline extends Nl2VecPipeline (gate, result, calls) — _GatePipeline(…) L71, submitCommand(…) L76
- L108  class _ConfirmingPipeline extends Nl2VecPipeline (request, result, calls) — _ConfirmingPipeline(…) L113, submitCommand(…) L117
- L148  class _PlanningPipeline extends Nl2VecPipeline (dryRunResult, plannedResult, planned) — _PlanningPipeline(…) L153, submitCommand(…) L157, executePlanned(…) L178
- L197  class _FakeSettingsRepository extends SettingsRepository (saves, settings) — _FakeSettingsRepository(…) L202, load() L205, save(AppSettings settings) L208
- L211  function _project
- L241  function _settle
- L247  function main

## test/widget/agent_steps_view_test.dart (482 lines)
- L12  function started
- L27  function completed
- L46  function failed
- L63  function liveStep
- L75  function main

## test/widget/export_dialog_test.dart (349 lines)
- L26  class _GatedFfmpeg extends FfmpegService (lastJob, gate, createdFiles) — _GatedFfmpeg() : super(tempDir: Directory.systemTemp.path) L27, run(FfmpegJob job) async* L34, cancel() L56
- L59  class _FastFfmpeg extends FfmpegService (lastJob, createdFiles) — _FastFfmpeg() : super(tempDir: Directory.systemTemp.path) L60, run(FfmpegJob job) async* L66, cancel() L87
- L92  class _FailingFfmpeg extends FfmpegService — _FailingFfmpeg() : super(tempDir: Directory.systemTemp.path) L93, run(FfmpegJob job) async* L96, cancel() L110
- L113  function _project
- L140  function _pumpDialog
- L155  function _deleteFiles
- L162  function main

## test/widget/left_panel_test.dart (767 lines)
- L33  class _FakeProjectRepository extends ProjectRepository — _FakeProjectRepository(…) L34, save(Project project) L37
- L42  class _FakeFfmpegService extends FfmpegService — _FakeFfmpegService() : super(resolver: _StubResolver('C:/fake/ffmpeg.exe')) L43, runSync(FfmpegJob job) L46, cancel() L57
- L62  class _StubFfprobeService extends FfprobeService — _StubFfprobeService() : super(resolver: _StubResolver('C:/fake/ffprobe.exe')) L63, extractMetadata(String filePath) L66
- L81  class _StubProceduralSoundService extends ProceduralSoundService (_outputDir) — _StubProceduralSoundService(this._outputDir) L82, generate(…) L87
- L98  class _StubResolver extends FfmpegBinaryResolver (path) — _StubResolver(this.path) L99, resolveFfmpeg(…) L104
- L107  function _project
- L137  function _twoClipProject
- L160  function main

## test/widget/project_hub_test.dart (1253 lines)
- L34  class _FakeProjectRepository extends ProjectRepository (recent, created, createdNames, createdSourceMediaPaths) — _FakeProjectRepository(…) L35, createNew(…) L44, save(Project project) L62, listRecent() L65
- L70  class _FailingSaveProjectRepository extends _FakeProjectRepository — _FailingSaveProjectRepository(…) L71, createNew(…) L74
- L84  function _project
- L96  function _testRouter
- L112  function _useDesktopViewport
- L121  function _pumpHub
- L137  function _mockPackageInfo
- L160  function _mockPathProvider
- L181  class _FailingChecker extends GithubReleaseChecker — checkForUpdate() L183
- L190  class _FakeYouTubeImportService extends YouTubeImportService (availability, availabilityGate, _progress, _errors, checkCalls, importCalls, cancelCalls, lastUrl) — _FakeYouTubeImportService(…) L191, progress L206, errors L209, checkAvailability() L212, import(String url, String outputDir) L220, cancel() L229, emitProgress(double value) L235
- L240  class _FakeUrlImportService extends UrlImportService (_progress, _errors, importCalls, cancelCalls, lastUrl, lastTargetDir, _pending) — progress L251, errors L254, import(String fileUrl, String targetDir) L257, cancel() L266, completeImport(String? path) L274, failImport(String message) L281, emitProgress(double value) L287
- L293  class _FakeFfprobeService extends FfprobeService (metadataGate) — _FakeFfprobeService(…) L294, extractMetadata(String filePath) L299, generateThumbnail(…) L303
- L310  function _importServiceOverrides
- L322  function main
- L1227  function _mockUrlLauncher

## test/widget/settings_screen_test.dart (187 lines)
- L13  class _RecordingSettingsRepository extends SettingsRepository (saves, lastSaved) — load() L18, save(AppSettings settings) L21
- L28  function _mockPackageInfo
- L48  function _pumpSettings
- L57  function _settle
- L63  function main

## test/widget/status_bar_test.dart (303 lines)
- L19  class _StubResolver extends FfmpegBinaryResolver (path) — _StubResolver(this.path) L20, resolveFfmpeg(…) L25
- L30  class _RecordingProjectRepository extends ProjectRepository (saveCalls) — _RecordingProjectRepository(…) L31, save(Project project) L36
- L41  function _project
- L50  function _container
- L77  function _pump
- L86  function main

## test/widget/timeline_view_test.dart (859 lines)
- L31  class _FakeProjectRepository extends ProjectRepository — _FakeProjectRepository(…) L32, save(Project project) L35
- L40  class _FakeFfmpegService extends FfmpegService — _FakeFfmpegService() : super(resolver: _StubResolver('C:/fake/ffmpeg.exe')) L41, runSync(FfmpegJob job) L44, cancel() L55
- L58  class _StubResolver extends FfmpegBinaryResolver (path) — _StubResolver(this.path) L59, resolveFfmpeg(…) L64
- L70  class _FakePlayer (seeks) — seek(Duration duration) L74, noSuchMethod(Invocation invocation) L79
- L82  function _project
- L110  function twoClipProject
- L148  function main

## test/widget/update_dialog_test.dart (232 lines)
- L13  class _ThrowingDownloader extends UpdateDownloader (error) — _ThrowingDownloader(this.error) : super(downloadUrl: '') L14, downloadAndInstall() L19
- L22  function _dialog
- L41  function _pumpDialog
- L49  function _driveError
- L56  function main

## test/widget/whats_new_dialog_test.dart (231 lines)
- L19  class _FakeProjectRepository extends ProjectRepository — _FakeProjectRepository(super.db) L20, save(Project project) L23
- L27  class _RecordingSettingsRepository extends SettingsRepository (initial, lastSaved) — _RecordingSettingsRepository(this.initial) L28, load() L34, save(AppSettings settings) L37
- L42  function _mockPackageInfo
- L63  function _testRouter
- L76  function main

## test/widget_test.dart (26 lines)
- L9  function main
