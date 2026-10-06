# Code Graph — lib/features (124 files, 14,410 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/features/agent/data/provider_tool_call_normalizer.dart (68 lines)
- L9  class ProviderToolCallNormalizer (ProviderToolCallNormalizer, _registry, _fallbackEncoder) — ProviderToolCallNormalizer(…) L10, normalize(ModelResponse response) L26, _safeSummary(String value) L53, _invalid(String code) L60

## lib/features/agent/data/strict_json_schema_encoder.dart (261 lines)
- L10  class StrictJsonSchemaEncoder (_registry, _maxBodyLength, _maxSummaryLength) — StrictJsonSchemaEncoder(…) L11, encode(…) L18, decode(String body) L47, _safeSummary(String value) L106, _exactKeys(Map<String, Object?> value, Set<String> expected) L111, _invalid(String code) L114
- L126  class _DuplicateKeyDetector (source, _offset, _maximumJsonDepth) — _DuplicateKeyDetector(this.source) L127, check() L132, _value(int depth) L138, _object(int depth) L166, _array(int depth) L185, _string() L198, _literal(String value) L228, _number() L233, _checkDepth(int depth) L241, _space() L245, _take(int unit) L253

## lib/features/agent/domain/entities/edit_plan.dart (215 lines)
- L4  enum EditPlanStatus — draft L5, valid L6, rejected L7, approved L8, applied L9, cancelled L10, revised L11, failed L12
- L15  class EditPlan (id, summary, baseProjectId, baseRevision, status, findings, payload) — EditPlan L16, EditPlan L26, EditPlan L39, EditPlan L56, EditPlan L71, planId L94, validate(ValidatedPlanPayload value) L96, approve() L107, apply() L112, reject(Iterable<ValidationFinding> value) L117, cancel() L126, revise() L135, fail(Iterable<ValidationFinding> value) L145, _copy(…) L161, _requireStatus(Set<EditPlanStatus> allowed) L176, _withoutPayload(…) L182, _identity(String value, [int maxLength = 500]) L199, _revision(int value) L208

## lib/features/agent/domain/entities/editor_tool_definition.dart (23 lines)
- L3  class EditorToolDefinition (name, description, inputSchema) — EditorToolDefinition(…) L4, schema L21

## lib/features/agent/domain/entities/normalized_planning_output.dart (28 lines)
- L6  class NormalizedPlanningOutput (summary, calls, findings) — NormalizedPlanningOutput(…) L7, toolCalls L18, validationFindings L19, isValid L20, NormalizedPlanningOutput L22

## lib/features/agent/domain/entities/safe_json_value.dart (74 lines)
- L8  function copySafeJsonValue
- L11  function immutableSafeJsonMap
- L14  function _copyJsonValue
- L34  function _copyList
- L45  function _copyMap
- L69  function _enter

## lib/features/agent/domain/entities/sanitized_project_snapshot.dart (113 lines)
- L10  class SanitizedProjectSnapshot (_providerJson) — SanitizedProjectSnapshot L11, SanitizedProjectSnapshot L16, toProviderJson() L91, projectId L93, projectName L94, baseRevision L95, _sortedIds(Iterable<String> values) L97, _safeDisplayLabel(String value, String fallback) L102

## lib/features/agent/domain/entities/tool_call.dart (35 lines)
- L3  class ToolCall (callId, name, arguments) — ToolCall(…) L4, id L16, canonicalName L17, _nonEmpty(String value) L19, _canonicalName(String value) L28

## lib/features/agent/domain/entities/tool_call_validation_result.dart (41 lines)
- L7  class ToolCallValidationResult (commands, findings, payload, candidate) — ToolCallValidationResult L8, ToolCallValidationResult L16, ToolCallValidationResult L24, candidateState L37, validatedPayload L38, isValid L39

## lib/features/agent/domain/entities/validated_plan_payload.dart (18 lines)
- L6  class ValidatedPlanPayload (commands, candidateState, summaries) — ValidatedPlanPayload(…) L7

## lib/features/agent/domain/entities/validation_finding.dart (52 lines)
- L1  class ValidationFinding (code, message, callId, argumentPath) — ValidationFinding(…) L2, _code(String value) L17, _safeText(String value, int maxLength) L24, _callId(String? value) L33, _argumentPath(String? value) L38, _hasControl(String value) L49

## lib/features/agent/domain/registry/editor_tool_registry.dart (315 lines)
- L6  class EditorToolRegistry (maxToolCalls, definitions, _byName) — EditorToolRegistry L7, byName(String name) L23, tools L24, lookup(String name) L25, toModelToolDefinitions() L27, toProviderToolDefinitions() L37, EditorToolRegistry L40
- L74  function _tool
- L84  function _object
- L96  function _id
- L102  function _integer
- L109  function _number
- L115  function _clipRange
- L124  function _arrangeClips
- L143  function _speed
- L151  function _muted
- L159  function _volume
- L164  function _transform
- L178  function _brightness
- L186  function _textOverlay
- L202  function _imageOverlay
- L225  function _tagCreate
- L237  function _tagUpdate
- L250  function _tagDelete
- L253  function _tagAssignment
- L265  function _color
- L270  function _marker
- L313  function _markerDelete

## lib/features/agent/domain/services/agent_planning_service.dart (222 lines)
- L19  class AgentPlanningRequest (providerId, modelId, userCommand, document, cancellationToken, idempotencyKey) — AgentPlanningRequest(…) L20
- L39  class AgentPlanningService (_registry, _normalizer, _validator, _complete) — AgentPlanningService(…) L40, AgentPlanningService L56, Function() _planIdFactory L69, Function() _repairPolicyFactory L70, plan(AgentPlanningRequest submission) L72, _modelRequest(AgentPlanningRequest submission) L161, _valid(…) L185, _rejected(…) L198, _safeCommand(String value) L210, _safeIdentity(String value) L214, _summary(String _) L218, _finding(String code, String message) L219

## lib/features/agent/domain/services/legacy_operation_normalizer.dart (410 lines)
- L10  class LegacyOperationNormalizer (_registry) — LegacyOperationNormalizer(…) L11, normalize(Iterable<Object?> values) L16, _asMap(Object? raw) L55, _legacyFailureCode(Map<String, Object?> map) L70, _id(Map<String, Object?> map, int index) L99, _convert(Map<String, Object?> map, String id) L110, _canonicalEnvelope(Map<String, Object?> map, String name) L169, _clipRange(Object? clipId, Map<String, Object?> args) L184, _removeClipRange(…) L200, _brightness(Object? clipId, Map<String, Object?> args) L217, _transform(Object? clipId, Map<String, Object?> args) L228, _with(…) L241, _only(Map<String, Object?> args, List<String> fields) L252, _directArguments(Map<String, Object?> map) L259, _withoutIds(Map<String, Object?> args) L268, _oneValue(…) L275, _oneString(Map<String, Object?> map, List<String> keys) L290, _oneMap(Map<String, Object?> map, List<String> keys) L300, _call(String id, String name, Map<String, Object?>? args) L311, _argumentsMatch(String name, Map<String, Object?> value) L320, _matches(Object? value, Map<String, Object?> schema) L325, _inRange(num value, Map<String, Object?> schema) L394, _finding(String code) L401, _invalid(String code) L405

## lib/features/agent/domain/services/malformed_output_repair_policy.dart (72 lines)
- L10  typedef PlanningCompletion
- L19  class MalformedOutputRepairPolicy (_used) — callbackCount L21, canRepair L22, repair(…) L24

## lib/features/agent/domain/services/tool_call_validator.dart (648 lines)
- L15  class ToolCallValidator (_registry, _commandFactory, _commandExecutor) — ToolCallValidator(…) L16, ToolCallValidator L22, validate(…) L32, _validateSchema(…) L127, _schemaValue(…) L135, _validateTargets(…) L228, _validateClipRange(…) L412, _validateTiming(ToolCall call, List<ValidationFinding> findings) L447, _validateTagName(…) L462, _validateAssignment(…) L479, _validateMarkerTiming(ToolCall call, List<ValidationFinding> findings) L510, _validateConflicts(…) L521, _matchesOneOf(Map<String, Object?> value, Map<String, Object?> schema) L579, _deduplicate(Iterable<ValidationFinding> findings) L588, _invalidArguments(…) L599, _conflict(…) L611, _finding(…) L623, pathFor(String base, String key) L634, _safeString(String value) L635, _unsafeId(String value) L637
- L645  extension _FirstOrNull — firstOrNull L646

## lib/features/agent/presentation/providers/edit_plan_notifier.dart (411 lines)
- L14  typedef EditPlanSubmitter
- L19  typedef EditPlanReplanner
- L25  typedef EditPlanCancellationControllerFactory
- L28  class EditPlanNotifier extends StateNotifier<EditPlanState> (_submitter, _replanner, _transactionGateway, _cancellationControllerFactory, _cancellation, _epoch, _isDisposed) — EditPlanNotifier(…) L29, EditPlanNotifier L44, submit(String command) L60, approve(String planId) L105, apply(String planId) L113, cancel(String planId) L188, cancelActivePlanning() L216, revise(String planId, String instruction) L230, _beginRequest() L300, _accepts(int epoch, CancellationController controller) L308, _matchingPlan(String planId) L314, _failPlan(EditPlan plan, String message) L319, _revisionFailure(EditPlan plan, String message) L341, _isAcceptedPlanningPlan(EditPlan plan) L361, _isAcceptedReplan(EditPlan plan, Object? oldPayload) L367, _hasConsistentStatusPayload(EditPlan plan) L375, _isCoherentOutcome(…) L387, _safeInstruction(String value) L398, dispose() L404

## lib/features/agent/presentation/providers/edit_plan_providers.dart (44 lines)

## lib/features/agent/presentation/providers/edit_plan_state.dart (45 lines)
- L4  enum EditPlanAction
- L7  class EditPlanState (plan, priorRevisedPlans, action, failureMessage, saveOutcome) — EditPlanState(…) L8, priorPlans L22, isBusy L23, isPlanning L24, copyWith(…) L26

## lib/features/agent/presentation/providers/edit_plan_transaction_gateway.dart (75 lines)
- L17  class ProjectTransactionEditPlanGateway (_service) — ProjectTransactionEditPlanGateway(…) L19, ProjectTransactionEditPlanGateway L24, Function() _currentDocumentReader L30, currentDocument L33, apply(…) L36
- L60  class UnavailableEditPlanTransactionGateway — UnavailableEditPlanTransactionGateway() L62, currentDocument L65, apply(…) L68

## lib/features/agent/presentation/widgets/edit_plan_card.dart (257 lines)
- L10  class EditPlanCard extends StatelessWidget (plan, action, failureMessage, saveOutcome, onApply, onCancel, onRevise) — EditPlanCard(…) L11, build(BuildContext context) L31, _statusLabel(EditPlanStatus status, EditPlanAction action) L196, _statusColor(EditPlanStatus status, bool warning) L211, _safeText(String value) L225, _opaque(String value) L230, _isPathLike(String value) L235
- L241  class _Notice extends StatelessWidget (color, message) — _Notice(…) L242, build(BuildContext context) L247

## lib/features/agent/presentation/widgets/edit_plan_operation_row.dart (48 lines)
- L6  class EditPlanOperationRow extends StatelessWidget (summary) — EditPlanOperationRow(…) L7, build(BuildContext context) L12, _humanize(String value) L27, _targets(List<String> ids) L33, _opaque(String value) L37, _isPathLike(String value) L43

## lib/features/agent/presentation/widgets/revise_plan_dialog.dart (80 lines)
- L5  class RevisePlanDialog extends StatefulWidget (onRevise) — RevisePlanDialog(…) L6, createState() L10
- L13  class _RevisePlanDialogState extends State<RevisePlanDialog> (_controller, _focusNode, _error) — initState() L19, dispose() L27, _submit() L33, build(BuildContext context) L46

## lib/features/projects/data/atomic_project_file_store.dart (171 lines)
- L6  class ProjectReadResult (json, recoveredFromRollback, warnings) — ProjectReadResult(…) L7
- L18  class AtomicProjectFileStore (_io, validator) — AtomicProjectFileStore(this._io,…) L19, writeJson(…) L23, recover(…) L102

## lib/features/projects/data/ids/uuid_id_generator.dart (12 lines)
- L5  class UuidIdGenerator (_uuid) — UuidIdGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid() L6, next() L10

## lib/features/projects/data/project_document_codec.dart (70 lines)
- L13  class ProjectDocumentCodec (currentSchemaVersion) — encodeJson(ProjectDocument document) L16, decodeJson(String source) L29, validateJson(String json) L63

## lib/features/projects/data/project_document_migrator.dart (133 lines)
- L13  class ProjectDocumentMigrator (_codec) — ProjectDocumentMigrator(this._codec) L14, migrateJson(String source) L17, validateJson(String json) L117, _stableHash(String value) L124

## lib/features/projects/data/project_file_io.dart (41 lines)
- L12  class DartProjectFileIo — DartProjectFileIo() L13, exists(String path) L16, read(String path) L19, writeAndFlush(String path, String content) L22, copy(String from, String to) L29, rename(String from, String to) L34, delete(String path) L39

## lib/features/projects/data/project_index_repair_service.dart (79 lines)
- L9  class ProjectIndexRepairResult (documents, repairedPaths, warnings) — ProjectIndexRepairResult(…) L10
- L23  class ProjectIndexRepairService (_index, _documents) — ProjectIndexRepairService(…) L24, rebuildRecent() L33, loadRecent() L48, _load(…) L50

## lib/features/projects/data/project_repository_impl.dart (114 lines)
- L15  class ProjectRepositoryImpl (_fileStore, _codec, _index, _migrator) — ProjectRepositoryImpl(…) L16, Function(ProjectDocument document) _pathFor L31, save(ProjectDocument candidate) L34, load(String path) L60, _legacySchema(String json) L105

## lib/features/projects/domain/commands/clip_commands.dart (113 lines)
- L4  class TrimClipCommand extends ProjectCommand (clipId, startMs, endMs) — TrimClipCommand(…) L5, type L16
- L19  class RemoveClipRangeCommand extends ProjectCommand (clipId, startMs, endMs, rightClipId) — RemoveClipRangeCommand(…) L20, type L33
- L36  class ClipPlacement (clipId, trackId, positionMs) — ClipPlacement(…) L37
- L48  class ArrangeClipsCommand extends ProjectCommand (placements) — ArrangeClipsCommand(…) L49, type L55
- L58  class SetClipSpeedCommand extends ProjectCommand (clipId, speed) — SetClipSpeedCommand(…) L59, type L65
- L68  class SetClipMutedCommand extends ProjectCommand (clipId, muted) — SetClipMutedCommand(…) L69, type L75
- L78  class SetClipVolumeCommand extends ProjectCommand (clipId, volume) — SetClipVolumeCommand(…) L79, type L85
- L88  class SetClipTransformCommand extends ProjectCommand (clipId, transform) — SetClipTransformCommand(…) L89, type L98
- L101  class SetClipBrightnessCommand extends ProjectCommand (clipId, brightness) — SetClipBrightnessCommand(…) L102, type L111

## lib/features/projects/domain/commands/marker_commands.dart (53 lines)
- L3  class CreateMarkerCommand extends ProjectCommand (markerId, label, color, atMs, startMs, endMs) — CreateMarkerCommand(…) L4, type L21
- L24  class UpdateMarkerCommand extends ProjectCommand (markerId, label, color, atMs, startMs, endMs) — UpdateMarkerCommand(…) L25, type L42
- L45  class DeleteMarkerCommand extends ProjectCommand (markerId) — DeleteMarkerCommand(…) L46, type L51

## lib/features/projects/domain/commands/overlay_commands.dart (52 lines)
- L3  class AddTextOverlayCommand extends ProjectCommand (overlayId, trackId, startMs, endMs, text, x, y) — AddTextOverlayCommand(…) L4, type L23
- L26  class AddImageOverlayCommand extends ProjectCommand (overlayId, trackId, assetId, startMs, endMs, x, y, width) — AddImageOverlayCommand(…) L27, type L50

## lib/features/projects/domain/commands/project_command.dart (63 lines)
- L5  enum TransactionSourceKind
- L7  class ProjectCommand (type) — ProjectCommand() L8
- L12  class CanonicalCommandSummary (type, targetIds) — CanonicalCommandSummary(…) L13, toJson() L19, CanonicalCommandSummary L21, operator L28, hashCode L34
- L45  class CommandExecution (candidateState, summaries) — CommandExecution(…) L46
- L55  function findClip

## lib/features/projects/domain/commands/project_command_executor.dart (102 lines)
- L14  class ProjectCommandExecutor (_clipHandler, _overlayHandler, _tagHandler, _markerHandler) — ProjectCommandExecutor(…) L15, ProjectCommandExecutor L25, _supportedTypes L37, supportedTypes L58, applyAll(…) L60, _dispatch(…) L81

## lib/features/projects/domain/commands/project_command_factory.dart (468 lines)
- L11  class ProjectCommandFactory (_ids) — ProjectCommandFactory(this._ids) L12, trimClip(…) L16, removeClipRange(…) L22, arrangeClips(…) L33, setSpeed(…) L36, setMuted(…) L41, setVolume(…) L44, setTransform(…) L49, setBrightness(…) L65, addTextOverlay(…) L70, addImageOverlay(…) L87, createTag(…) L108, updateTag(…) L111, deleteTag(…) L117, assignTag(…) L120, unassignTag(…) L130, createMarker(…) L140, updateMarker(…) L155, deleteMarker(…) L171, fromCanonicalArguments(…) L174, _assignment(…) L353, _marker(…) L381, _placements(Map<String, Object?> arguments) L420, _require(Map<String, Object?> map, Set<String> keys) L444, _allow(Map<String, Object?> map, Set<String> keys) L449, _valueMatches(Object? value) L452, _string(Map<String, Object?> map, String key) L453, _int(Map<String, Object?> map, String key) L456, _nullableInt(Map<String, Object?> map, String key) L459, _double(Map<String, Object?> map, String key) L462, _invalid(String type) L465

## lib/features/projects/domain/commands/tag_commands.dart (73 lines)
- L3  enum AssignmentTargetKind
- L5  class CreateTagCommand extends ProjectCommand (tagId, name, color) — CreateTagCommand(…) L6, type L17
- L20  class UpdateTagCommand extends ProjectCommand (tagId, name, color) — UpdateTagCommand(…) L21, type L32
- L35  class DeleteTagCommand extends ProjectCommand (tagId) — DeleteTagCommand(…) L36, type L41
- L44  class AssignTagCommand extends ProjectCommand (tagId, targetKind, targetId) — AssignTagCommand(…) L45, type L56
- L59  class UnassignTagCommand extends ProjectCommand (tagId, targetKind, targetId) — UnassignTagCommand(…) L60, type L71

## lib/features/projects/domain/entities/clip_transform.dart (41 lines)
- L1  enum ClipFit
- L3  class ClipTransform (width, height, fit, rotationDegrees) — ClipTransform(…) L4, toJson() L16, ClipTransform L23, operator L31, hashCode L39

## lib/features/projects/domain/entities/media_asset.dart (57 lines)
- L3  class MediaAsset (id, sourcePath, displayName, durationMs, tagIds) — MediaAsset(…) L4, copyWith(…) L18, toJson() L26, MediaAsset L34, operator L45, hashCode L54

## lib/features/projects/domain/entities/persisted_transaction_record.dart (82 lines)
- L4  class PersistedTransactionRecord (planId, beforeState, afterState, commands, appliedAt, sourceKind) — PersistedTransactionRecord(…) L5, toJson() L20, PersistedTransactionRecord L29, operator L52, hashCode L62
- L72  function _commandsEqual

## lib/features/projects/domain/entities/project_clip.dart (129 lines)
- L4  class ProjectClip (id, assetId, trackId, startMs, endMs, positionMs, tagIds, transform) — ProjectClip(…) L5, durationMs L33, copyWith(…) L35, toJson() L63, ProjectClip L78, operator L98, hashCode L114

## lib/features/projects/domain/entities/project_document.dart (76 lines)
- L5  class ProjectDocument (schemaVersion, id, name, createdAt, updatedAt, outputDirectory, currentState, revision) — ProjectDocument(…) L6, copyWith(…) L29, operator L49, hashCode L63

## lib/features/projects/domain/entities/project_overlay.dart (131 lines)
- L1  enum ProjectOverlayKind
- L3  class ProjectOverlay (id, kind, trackId, startMs, endMs, text, assetId, x) — ProjectOverlay L4, ProjectOverlay L18, ProjectOverlay L37, toJson() L72, ProjectOverlay L86, operator L102, hashCode L117

## lib/features/projects/domain/entities/project_state_snapshot.dart (108 lines)
- L8  class ProjectStateSnapshot (assets, tracks, tags, markers, overlays) — ProjectStateSnapshot(…) L9, assetById(String id) L27, copyWith(…) L29, toJson() L43, ProjectStateSnapshot L51, operator L87, hashCode L96
- L105  extension _FirstOrNull — firstOrNull L106

## lib/features/projects/domain/entities/project_track.dart (47 lines)
- L4  enum ProjectTrackKind
- L6  class ProjectTrack (id, kind, clips) — ProjectTrack(…) L7, copyWith(…) L17, toJson() L20, ProjectTrack L26, operator L38, hashCode L45

## lib/features/projects/domain/entities/tag_definition.dart (30 lines)
- L1  class TagDefinition (id, name, color) — TagDefinition(…) L2, toJson() L12, TagDefinition L14, operator L21, hashCode L28

## lib/features/projects/domain/entities/timeline_marker.dart (49 lines)
- L1  class TimelineMarker (id, label, color, atMs, startMs, endMs) — TimelineMarker(…) L2, toJson() L18, TimelineMarker L27, operator L37, hashCode L47

## lib/features/projects/domain/entities/value_utils.dart (18 lines)

## lib/features/projects/domain/handlers/clip_command_handler.dart (305 lines)
- L10  class ClipCommandHandler — ClipCommandHandler() L11, handles(ProjectCommand command) L13, apply(…) L23, _trim(…) L85, _removeRange(…) L104, _arrange(…) L169, _updateClip(…) L232, _locateClip(ProjectStateSnapshot state, String clipId) L269, _clipId(ProjectCommand command) L278, _validTransform(SetClipTransformCommand command) L288, _finite(double value) L296
- L299  class _LocatedClip (track, clip) — _LocatedClip(this.track, this.clip) L300

## lib/features/projects/domain/handlers/command_handler_result.dart (10 lines)
- L4  class CommandHandlerResult (state, summary) — CommandHandlerResult(…) L5

## lib/features/projects/domain/handlers/marker_command_handler.dart (142 lines)
- L9  class MarkerCommandHandler — MarkerCommandHandler() L10, handles(ProjectCommand command) L12, apply(…) L17, _create(…) L29, _update(…) L66, _delete(…) L103, _valid(…) L125

## lib/features/projects/domain/handlers/overlay_command_handler.dart (106 lines)
- L9  class OverlayCommandHandler — OverlayCommandHandler() L10, handles(ProjectCommand command) L12, apply(…) L15, _text(…) L26, _image(…) L59, _trackExists(ProjectStateSnapshot state, String trackId) L97, _overlayIdExists(ProjectStateSnapshot state, String id) L100, _validTiming(int startMs, int endMs) L103, _unit(double value) L104

## lib/features/projects/domain/handlers/tag_command_handler.dart (214 lines)
- L9  class TagCommandHandler — TagCommandHandler() L10, handles(ProjectCommand command) L12, apply(…) L19, _create(…) L35, _update(…) L66, _delete(…) L100, _assignment(…) L137, _normalized(String value) L209, _validName(String value) L210, _validColor(String value) L211

## lib/features/projects/domain/ids/id_generator.dart (4 lines)

## lib/features/projects/domain/repositories/project_document_locator.dart (7 lines)

## lib/features/projects/domain/repositories/project_repository.dart (15 lines)

## lib/features/projects/domain/services/project_import_service.dart (69 lines)
- L9  class ProjectImportService (_ids) — ProjectImportService(this._ids) L10, addLocalMedia(…) L14

## lib/features/projects/domain/services/project_render_input_resolver.dart (31 lines)
- L9  class ProjectRenderInputResolver (_gateway) — ProjectRenderInputResolver(this._gateway) L10, resolveAndRender(ProjectDocument document) L14

## lib/features/projects/domain/transactions/edit_transaction.dart (24 lines)
- L4  class EditTransaction (planId, expectedRevision, beforeState, candidateState, commands, summaries, sourceKind) — EditTransaction(…) L5

## lib/features/projects/domain/transactions/project_document_publisher.dart (10 lines)

## lib/features/projects/domain/transactions/project_file_write_outcome.dart (19 lines)
- L1  class ProjectSaveWarning (code, message) — ProjectSaveWarning(this.code, this.message) L2
- L7  class ProjectFileWarning extends ProjectSaveWarning — ProjectFileWarning(super.code, super.message) L8
- L11  class ProjectIndexWarning extends ProjectSaveWarning — ProjectIndexWarning(super.code, super.message) L12
- L15  class ProjectFileWriteOutcome (warning) — ProjectFileWriteOutcome(…) L16

## lib/features/projects/domain/transactions/project_save_outcome.dart (14 lines)
- L6  class ProjectSaveOutcome (document, warnings) — ProjectSaveOutcome(…) L7

## lib/features/projects/domain/transactions/project_transaction_gateway.dart (6 lines)

## lib/features/projects/domain/transactions/project_transaction_service.dart (96 lines)
- L13  class ProjectTransactionService (_repository, _publisher) — ProjectTransactionService(…) L14, Function() _now L24, apply(…) L26, undo(ProjectDocument current) L55, redo(ProjectDocument current) L70, _saveAndPublish(…) L86

## lib/features/projects/presentation/local_smoke_screen.dart (291 lines)
- L22  class LocalSmokeScreen extends StatefulWidget (configuration, loader, coordinator, providerInitialization) — LocalSmokeScreen(…) L23, LocalSmokeScreen L31, createState() L51
- L54  class _LocalSmokeScreenState extends State<LocalSmokeScreen> (_status, _document, _previousFlutterErrorHandler) — initState() L60, dispose() L71, _loadFixture() L76, build(BuildContext context) L108, _statusMessage L126, _hasRenderableClip(ProjectDocument document) L130
- L140  enum _LocalSmokeScreenStatus
- L142  class _LocalSmokeStatus extends StatelessWidget (message) — _LocalSmokeStatus(…) L143, build(BuildContext context) L148
- L167  class _LoadedLocalSmokeLayout extends StatelessWidget (document, providerInitialization, onTimelineRendered, onProvidersRendered) — _LoadedLocalSmokeLayout(…) L168, build(BuildContext context) L181, _localProviderResult(…) L220, _legacyProject(ProjectDocument document) L244

## lib/features/projects/presentation/smoke_fixture_loader.dart (54 lines)
- L12  class FileSmokeFixtureLoader (FileSmokeFixtureLoader, _codec, _migrator) — FileSmokeFixtureLoader(…) L13, load(File fixture) L30, _failure() L43
- L47  class LocalSmokeFixtureFailure extends AppFailure — LocalSmokeFixtureFailure() L48

## lib/features/projects/presentation/timeline_project_controller.dart (55 lines)
- L13  class TimelineProjectController (_factory, _transactions, _document) — TimelineProjectController(…) L14, removeRange(…) L26

## lib/features/providers/data/adapters/anthropic_adapter.dart (227 lines)
- L12  class AnthropicAdapter extends ProviderAdapterBase (_discoveryPageLimit, _maxDiscoveryPages) — AnthropicAdapter(…) L13, discoverModels(…) L20, _modelsUri(ProviderProfile profile,…) L92, complete(…) L104, testConnection(…) L195

## lib/features/providers/data/adapters/gemini_adapter.dart (229 lines)
- L11  class GeminiAdapter extends ProviderAdapterBase — GeminiAdapter(…) L12, discoverModels(…) L16, complete(…) L79, _uriAndHeaders(…) L193
- L224  class _GeminiRequest (uri, headers) — _GeminiRequest(this.uri, this.headers) L225

## lib/features/providers/data/adapters/ollama_adapter.dart (159 lines)
- L11  class OllamaAdapter extends ProviderAdapterBase — OllamaAdapter(…) L12, discoverModels(…) L16, complete(…) L68

## lib/features/providers/data/adapters/openai_compatible_adapter.dart (196 lines)
- L12  class OpenAiCompatibleAdapter extends ProviderAdapterBase — OpenAiCompatibleAdapter(…) L13, discoverModels(…) L32, complete(…) L89, _needsApiKey(ProviderProfile profile) L192

## lib/features/providers/data/adapters/provider_adapter_support.dart (256 lines)
- L19  class ProviderAdapterBase (transport, credentials, providerIds) — ProviderAdapterBase(…) L20, validation L30, cancelled L33, validateProfile L35, headersFor(…) L71, apiKeyFor(ProviderProfile profile) L138, endpoint(ProviderProfile profile, String relative) L178, send(…) L181, testConnection(…) L196, objectMap(Object? value) L209, arguments(Object? value) L219, toolCall(…) L230, manualModels(ProviderProfile profile) L243

## lib/features/providers/data/catalog/provider_catalog.dart (102 lines)
- L5  class ProviderCatalog (ProviderCatalog) — List L8, presets L9, _compatible(…) L79, byId(String providerId) L95

## lib/features/providers/data/http/provider_http_transport.dart (289 lines)
- L11  enum ProviderHttpMethod
- L13  class ProviderHttpRequest (method, uri, headers, body, timeout, isDiscovery, idempotencyKey, permitRetry) — ProviderHttpRequest(…) L14, permitsRetry L35
- L42  class ProviderHttpResponse (statusCode, headers, body) — ProviderHttpResponse(…) L43
- L55  enum ProviderHttpExceptionKind — connectionTimeout L56, sendTimeout L57, receiveTimeout L58, connectionReset L59, other L60
- L63  class ProviderHttpException (kind) — ProviderHttpException(this.kind) L64
- L82  typedef ProviderRetryDelay
- L85  class RetryingProviderHttpTransport (_client, _retryDelay, _redactor, maxRetries, initialRetryDelay) — RetryingProviderHttpTransport(…) L86, _wait(Duration duration) L101, send(…) L105, _delayFor(int retry) L180, _raceCancellation L182, _isSuccess(int statusCode) L190, _isTransientStatus(int statusCode) L192, _isTransientException(ProviderHttpExceptionKind kind) L195, _dioExceptionKind(DioException error) L201, _failureFor(…) L223
- L236  class DioProviderHttpClient (_dio) — DioProviderHttpClient(this._dio) L237, send(ProviderHttpRequest request) L242
- L266  class DioProviderHttpTransport (_delegate) — DioProviderHttpTransport(…) L267, send(…) L284

## lib/features/providers/data/migration/legacy_provider_settings_migration.dart (249 lines)
- L14  class LegacyProviderSettings (activeProviderId, activeModel, ollamaEndpoint) — LegacyProviderSettings(…) L15
- L36  class AppSettingsLegacyProviderSettingsSource (_settings) — AppSettingsLegacyProviderSettingsSource(this._settings) L38, load() L43
- L61  class LegacySecureCredentialSource (_backend) — LegacySecureCredentialSource(…) L63, deleteApiKey(String providerId) L69, readApiKey(String providerId) L81, _keyFor(String providerId) L91
- L102  class LegacyProviderSettingsMigration (_repository, _settings, _legacyCredentials, _credentials) — LegacyProviderSettingsMigration(…) L103, LegacyProviderSettingsMigration L115, migrate() L127, _migrate() L135, _profile(…) L192, _complete(…) L222, _document(…) L235, _failure() L247

## lib/features/providers/data/network_disabled_provider_http_transport.dart (24 lines)
- L7  class NetworkDisabledProviderHttpTransport — NetworkDisabledProviderHttpTransport() L9, send(…) L12

## lib/features/providers/data/policy/provider_endpoint_resolver.dart (15 lines)
- L1  class ProviderEndpointResolver (ProviderEndpointResolver) — resolve(Uri base, String relative) L5

## lib/features/providers/data/policy/provider_url_policy.dart (74 lines)
- L4  enum ProviderUrlWarning
- L6  class ProviderUrlValidation (uri, warnings) — ProviderUrlValidation(this.uri, Iterable<ProviderUrlWarning> warnings) L7
- L14  class ProviderUrlPolicy (ProviderUrlPolicy) — parseAndValidate(String value) L17, validate(Uri uri) L27, _invalid() L48, _isSafeHttpHost(String host) L53

## lib/features/providers/data/profiles/provider_profiles_codec.dart (296 lines)
- L11  class ProviderProfilesCodec (currentSchemaVersion) — _identifier L13, encode(ProviderProfilesDocument document) L17, decode(String source) L39, _encodeProfile(…) L76, _hasSecretInMetadata(ProviderProfile profile) L94, _hasUniqueProfileIds(Iterable<ProviderProfile> profiles) L138, _hasUniqueCaseInsensitive(Iterable<String> values) L146, _isSensitiveHeaderName(String name) L154, _hasSensitiveEndpointQuery(Uri endpoint) L169, _sortedMap(Map<String, String> value) L188, _decodeProfile(Map<String, Object?> value) L194, _stringMap(Object? value) L254, _stringList(Object? value) L264, _migrationState(Object? value) L269, _persistence() L277, _unsupported() L280, _malformed() L285, _unsupportedDocument() L289

## lib/features/providers/data/profiles/provider_profiles_storage.dart (25 lines)
- L10  class FileProviderProfilesStorage (_file) — FileProviderProfilesStorage(this._file) L11, read() L16, write(String contents) L22

## lib/features/providers/data/provider_platform_bootstrap_impl.dart (118 lines)
- L14  typedef ProviderMigrationRunner
- L15  typedef ProviderRegistryFactory
- L20  class ProviderPlatformBootstrapImpl (_profiles, _credentials, _migrate, _transport, _registryFactory, _registries, _migrationCompleted) — ProviderPlatformBootstrapImpl(…) L21, ProviderPlatformBootstrapImpl L37, initialize(…) L61, _fail(Object error) L111

## lib/features/providers/data/provider_platform_riverpod.dart (152 lines)
- L104  class _UnavailableRepository — _UnavailableRepository() L105, _failure L106, deleteProfile(…) L112, load() L117, resumePendingDeletions(…) L120, save(ProviderProfilesDocument document) L124
- L128  class _UnavailableCredentials — _UnavailableCredentials() L129, _failure L130, delete(String credentialId) L134, read(String credentialId) L136, write(String credentialId, String secret) L139
- L143  class _UnavailableRegistry — _UnavailableRegistry() L144, definitions L146, adapterFor(String providerId) L148, definitionFor(String providerId) L150

## lib/features/providers/data/provider_platform_startup.dart (66 lines)
- L18  class ProviderPlatformStartup (ProviderPlatformStartup) — initialize(…) L21
- L57  class ProviderPlatformStartupBootstrap — ProviderPlatformStartupBootstrap() L59, initialize(…) L62

## lib/features/providers/data/provider_profile_repository_impl.dart (170 lines)
- L11  class ProviderProfileRepositoryImpl (ProviderProfileRepositoryImpl, _storage, _codec) — ProviderProfileRepositoryImpl(…) L12, deleteProfile(…) L26, load() L79, resumePendingDeletions(…) L101, save(ProviderProfilesDocument document) L125, _credentialReferences(ProviderProfile profile) L140

## lib/features/providers/data/provider_registry_impl.dart (105 lines)
- L14  class ProviderRegistryImpl (_definitions, _adapters) — ProviderRegistryImpl(…) L15, ProviderRegistryImpl L35, definitions L92, adapterFor(String providerId) L95, definitionFor(String providerId) L98

## lib/features/providers/data/security/provider_redactor.dart (94 lines)
- L1  class ProviderRedactor (_secretValues, _sensitiveHeaderNames) — ProviderRedactor(…) L2, redact(String value) L25, redactUri(Uri uri) L63, redactHeaders(Map<String, String> headers) L74, _isSensitiveName(String name) L84

## lib/features/providers/data/security/secure_credential_store.dart (152 lines)
- L14  class FlutterSecureStorageBackend (_storage) — FlutterSecureStorageBackend([FlutterSecureStorage? storage]) L15, delete(…) L21, read(…) L24, write(…) L27
- L33  class SecureCredentialStore (_backend) — SecureCredentialStore(…) L34, apiKeyCredentialId(String profileId) L39, secretHeaderCredentialId(String profileId, String headerName) L42, deleteApiKey(String profileId) L45, deleteSecretHeader(…) L48, readApiKey(String profileId) L53, readSecretHeader(…) L56, writeApiKey(String profileId, String secret) L61, writeSecretHeader(…) L64, delete(String credentialId) L71, read(String credentialId) L82, write(String credentialId, String secret) L100, _invalid() L113, _deleteFailure() L117, _deleteFor(String Function() reference) L121, _readFor(String Function() reference) L129, _writeFor(…) L141

## lib/features/providers/domain/contracts/credential_store.dart (8 lines)

## lib/features/providers/domain/contracts/model_provider_adapter.dart (26 lines)

## lib/features/providers/domain/contracts/provider_profile_repository.dart (14 lines)

## lib/features/providers/domain/contracts/provider_registry.dart (9 lines)

## lib/features/providers/domain/entities/immutable_value.dart (73 lines)
- L5  function immutableObjectMap
- L10  function immutableValue
- L13  function _copyJsonValue
- L33  function _copyList
- L44  function _copyMap
- L68  function _enter

## lib/features/providers/domain/entities/model_descriptor.dart (14 lines)
- L1  class ModelDescriptor (id, providerId, displayName, capabilities) — ModelDescriptor(…) L2

## lib/features/providers/domain/entities/model_tool_definition.dart (14 lines)
- L3  class ModelToolDefinition (name, description, inputSchema) — ModelToolDefinition(…) L4

## lib/features/providers/domain/entities/normalized_model_tool_call.dart (14 lines)
- L3  class NormalizedModelToolCall (id, name, arguments) — NormalizedModelToolCall(…) L4

## lib/features/providers/domain/entities/provider_capabilities.dart (12 lines)
- L1  class ProviderCapabilities (supportsModelDiscovery, supportsTools, supportsStreaming) — ProviderCapabilities(…) L2

## lib/features/providers/domain/entities/provider_connection_result.dart (7 lines)
- L1  class ProviderConnectionResult (isConnected, message) — ProviderConnectionResult(…) L2

## lib/features/providers/domain/entities/provider_definition.dart (27 lines)
- L3  enum ProviderProtocol
- L6  class ProviderDefinition (id, displayName, baseUri, protocol, capabilities, modelDiscoveryRelativePath) — ProviderDefinition(…) L7, modelDiscoveryIsAvailable L25

## lib/features/providers/domain/entities/provider_profile.dart (77 lines)
- L1  class ProviderProfile (id, providerId, displayName, endpoint, credentialId, headers, secretHeaderNames, secretHeaderCredentialIds) — ProviderProfile(…) L2, copyWith(…) L44

## lib/features/providers/domain/entities/provider_profiles_document.dart (69 lines)
- L3  class ProviderProfilesDocument (schemaVersion, profiles, activeProfileId, legacyMigrationState) — ProviderProfilesDocument(…) L4, ProviderProfilesDocument L19, activeProfile L34, withProfiles(…) L41, _resolvedActiveProfileId(…) L52
- L68  enum LegacyMigrationState

## lib/features/providers/domain/provider_credential_reference.dart (60 lines)
- L4  class ProviderCredentialReference (ProviderCredentialReference, _prefix, _profileId) — _headerName L9, apiKey(String profileId) L13, secretHeader(String profileId, String headerName) L18, isValid(String credentialId) L35, belongsToProfile(String credentialId, String profileId) L42, _validateProfileId(String profileId) L50

## lib/features/providers/domain/provider_failures.dart (63 lines)
- L3  class ProviderValidationFailure extends AppFailure — ProviderValidationFailure(String message) L4
- L8  class ProviderTransportFailure extends AppFailure (statusCode) — ProviderTransportFailure(…) L9
- L17  class ProviderCancellationFailure extends AppFailure — ProviderCancellationFailure() L18
- L22  class ProviderCredentialFailure extends AppFailure — ProviderCredentialFailure(String message) L23
- L27  class ProviderPersistenceFailure extends AppFailure — ProviderPersistenceFailure(String message) L28
- L32  class ProviderDeletionPendingFailure extends AppFailure — ProviderDeletionPendingFailure() L33
- L40  class ProviderMigrationFailure extends AppFailure — ProviderMigrationFailure() L41
- L48  class ProviderRegistryFailure extends AppFailure — ProviderRegistryFailure() L49
- L56  class ProviderNetworkDisabledFailure extends AppFailure — ProviderNetworkDisabledFailure() L57

## lib/features/providers/domain/provider_platform_bootstrap.dart (43 lines)
- L8  class ProviderPlatformBootstrapResult (registry, profiles, activeProfileId, schemaVersion, legacyMigrationState, repository, credentials) — ProviderPlatformBootstrapResult(…) L9, activeProfile L30

## lib/features/providers/domain/provider_service_ids.dart (3 lines)

## lib/features/providers/domain/requests/model_request.dart (20 lines)
- L4  class ModelRequest (providerId, modelId, messages, tools, idempotencyKey) — ModelRequest(…) L5

## lib/features/providers/domain/responses/model_response.dart (21 lines)
- L4  class ModelResponse (modelId, content, toolCalls, metadata) — ModelResponse(…) L5

## lib/features/providers/presentation/providers/provider_profile_notifier.dart (822 lines)
- L17  typedef ProviderIdFactory
- L18  typedef ProviderCancellationControllerFactory
- L21  enum ProviderProfileAction — idle L22, loading L23, saving L24, deleting L25, testing L26, discovering L27
- L30  class ProviderProfileState (profiles, activeProfileId, selectedProfileId, discoveredModels, schemaVersion, legacyMigrationState, action, failure) — ProviderProfileState(…) L31, activeProfile L62, selectedProfile L63, isLoading L64, hasUsableActiveProfile L65, selectedModelId L66, selectedModel L67, manualModels L68, discoveredModelsForActive L70, insecureLocalHttp L73, profileFor(String? id) L83, copyWith(…) L91, _isUsable(ProviderProfile? profile) L127
- L132  class ProviderProfileDraft (id, providerId, displayName, endpoint, enabled, timeout, headers, secretHeaderNames) — ProviderProfileDraft(…) L133
- L166  class ProviderProfileNotifier (_repository, _credentials, _registry, _cancellationControllerFactory, _idFactory, _discoveryCancellation, _requestEpoch) — ProviderProfileNotifier(…) L168, ProviderProfileNotifier L185, load() L202, beginCreate() L233, selectProfile(String profileId) L240, activateProfile(String profileId) L252, saveProfile(ProviderProfileDraft draft) L263, deleteProfile(String profileId) L405, deleteSelectedProfile() L427, testConnection(String profileId) L432, discoverModels(String profileId) L463, addManualModel(String profileId, String value) L501, selectModel(String profileId, String modelId) L519, _replaceProfile(…) L533, _saveDocument(…) L544, _document(…) L568, _commitSaved(…) L578, _finishCredentialMutations(…) L594, _deleteNewReferences(Iterable<String> references) L629, _isCurrentRequest(int request, String profileId) L635, _canRun(ProviderProfile? profile) L638, _supportsDiscovery(ProviderProfile profile) L646, _validateDraft(ProviderProfileDraft draft) L654, _validateNewSecretValues(…) L697, _removedSecretNames(…) L715, _normalizedSecretValues(…) L734, _normalizedModels(Iterable<String> values) L750, _normalizedHeaderNames(Iterable<String> values) L761, _uniqueDescriptors(Iterable<ModelDescriptor> models) L773, _validHeader(String value) L778, _sensitiveHeader(String value) L780, _discoveryUnavailable() L795, _validation(String message) L803, _failure(AppFailure failure,…) L808, dispose() L817

## lib/features/providers/presentation/screens/ai_providers_screen.dart (183 lines)
- L11  class AiProvidersScreen extends ConsumerWidget — AiProvidersScreen(…) L12, build(BuildContext context, WidgetRef ref) L15
- L61  function _navigateBackToSettings
- L69  class _ProfileRail extends ConsumerWidget (state) — _ProfileRail(…) L70, build(BuildContext context, WidgetRef ref) L73
- L126  class _ConfigurationSurface extends ConsumerWidget (state) — _ConfigurationSurface(…) L127, build(BuildContext context, WidgetRef ref) L130
- L154  class _EmptyProfiles extends StatelessWidget — _EmptyProfiles() L155, build(BuildContext context) L157

## lib/features/providers/presentation/widgets/dynamic_model_selector.dart (391 lines)
- L14  class DynamicModelSelector extends ConsumerWidget — DynamicModelSelector(…) L15, build(BuildContext context, WidgetRef ref) L18, _showPicker(BuildContext context, WidgetRef ref) L70
- L82  class _ModelPicker extends ConsumerStatefulWidget (profileId) — _ModelPicker(…) L83, createState() L86
- L89  class _ModelPickerState extends ConsumerState<_ModelPicker> (_manual) — initState() L93, _discoverOnOpen() L102, dispose() L123, build(BuildContext context) L129, _add(String value) L349
- L365  function groupDiscoveredByOrg

## lib/features/providers/presentation/widgets/model_discovery_support.dart (15 lines)
- L11  function modelDiscoverySupported

## lib/features/providers/presentation/widgets/provider_profile_form.dart (642 lines)
- L14  class ProviderProfileForm extends ConsumerStatefulWidget (profile, onRendered) — ProviderProfileForm(…) L15, createState() L21
- L25  class _ProviderProfileFormState extends ConsumerState<ProviderProfileForm> (_formKey, _name, _endpoint, _timeout, _apiKey, _headers, _manualModels, _selectedModel) — didUpdateWidget(covariant ProviderProfileForm oldWidget) L42, initState() L48, dispose() L77, build(BuildContext context) L96, _scheduleRendered() L340, _addSecretRow() L348, _removeSecretRow(_SecretHeaderRow row) L350, _save() L360, _discoverAfterSave() L422, _presetEndpoint(…) L440, _isLocalHttpWarning L451, _endpointValidation(String? value) L457, _split(String value) L464, _parseHeaders(String value) L470, _encodeHeaders(Map<String, String> value) L483
- L487  class _FormHeader extends StatelessWidget (profile) — _FormHeader(…) L488, build(BuildContext context) L493
- L516  class _SecretHeaderEditor extends StatelessWidget (rows, enabled, onAdd, onRemove) — _SecretHeaderEditor(…) L517, build(BuildContext context) L530
- L593  class _SecretHeaderRow (existingName, name, value) — _SecretHeaderRow(…) L594, dispose() L602
- L608  class _StatusChip extends StatelessWidget (profile) — _StatusChip(…) L609, build(BuildContext context) L614
- L625  class _Notice extends StatelessWidget (message, error) — _Notice(…) L626, build(BuildContext context) L632

## lib/features/providers/presentation/widgets/provider_profile_list.dart (87 lines)
- L5  class ProviderProfileList extends StatelessWidget (profiles, activeProfileId, selectedProfileId, onSelected) — ProviderProfileList(…) L6, build(BuildContext context) L20

## lib/features/tagging/domain/marker_filter.dart (41 lines)
- L3  class MarkerFilter (selectedColors, includePoints, includeRanges) — MarkerFilter(…) L4, filter(Iterable<TimelineMarker> markers) L14, _isPoint(TimelineMarker marker) L28, _isRange(TimelineMarker marker) L34

## lib/features/tagging/domain/marker_layout.dart (100 lines)
- L3  class MarkerLayoutEntry (markerId, leftPx, widthPx) — MarkerLayoutEntry(…) L4
- L15  class MarkerLayout — layout(…) L16, _entryFor(…) L42, _isPoint(TimelineMarker marker) L81, _isRange(TimelineMarker marker) L87, _clamp(double value, double minimum, double maximum) L94

## lib/features/tagging/domain/tag_query.dart (22 lines)
- L3  class TagQuery (text, selectedTagIds) — TagQuery(…) L4, filter(Iterable<MediaAsset> assets) L11

## lib/features/tagging/domain/tagging_controller.dart (75 lines)
- L5  class TaggingController (_commandFactory) — TaggingController(this._commandFactory) L6, createTag(…) L10, updateTag(…) L13, deleteTag(…) L19, assignTag(…) L22, unassignTag(…) L32, createMarker(…) L42, updateMarker(…) L56, deleteMarker(…) L72

## lib/features/tagging/presentation/providers/tagging_providers.dart (102 lines)
- L24  class TaggingProviders (controller, _transactions) — TaggingProviders(…) L25, TaggingProviders L37, Function() _currentDocument L45, Function() _manualTransactionId L47, document L49, applyManual(ProjectCommand command) L51

## lib/features/tagging/presentation/widgets/asset_tag_chips.dart (60 lines)
- L6  class AssetTagChips extends ConsumerStatefulWidget (assetId) — AssetTagChips(…) L7, createState() L12
- L15  class _AssetTagChipsState extends ConsumerState<AssetTagChips> (_busy) — _remove(String tagId, TaggingProviders providers) L18, build(BuildContext context) L32

## lib/features/tagging/presentation/widgets/clip_tag_inspector.dart (104 lines)
- L7  class ClipTagInspector extends ConsumerStatefulWidget (clipId) — ClipTagInspector(…) L8, createState() L13
- L16  class _ClipTagInspectorState extends ConsumerState<ClipTagInspector> (_busy) — _apply(…) L19, build(BuildContext context) L42
- L72  class _TagAction extends StatelessWidget (tagName, assigned, busy, clipId, onPressed) — _TagAction(…) L73, build(BuildContext context) L88

## lib/features/tagging/presentation/widgets/marker_editor_dialog.dart (203 lines)
- L4  class MarkerEditorFormValue (label, color, atMs, startMs, endMs) — MarkerEditorFormValue(…) L5, operator L20, hashCode L29
- L32  class MarkerEditorDialog extends StatefulWidget (initialValue) — MarkerEditorDialog(…) L33, createState() L38
- L41  class _MarkerEditorDialogState extends State<MarkerEditorDialog> (_label, _color, _atMs, _startMs, _endMs, _isRange) — initState() L50, dispose() L65, _hasValidLabel L74, _hasValidColor L81, _int(TextEditingController controller) L84, _hasValidShape L87, _isValid L101, _submit() L103, build(BuildContext context) L117

## lib/features/tagging/presentation/widgets/marker_filter_menu.dart (104 lines)
- L6  class MarkerFilterMenu extends ConsumerWidget — MarkerFilterMenu(…) L7, build(BuildContext context, WidgetRef ref) L10, _setFilter(WidgetRef ref, MarkerFilter value) L74
- L79  class _FilterToggle extends StatelessWidget (label, selected, onSelected) — _FilterToggle(…) L80, build(BuildContext context) L91

## lib/features/tagging/presentation/widgets/marker_ruler.dart (275 lines)
- L13  class MarkerRuler extends ConsumerStatefulWidget (durationMs, width, document) — MarkerRuler(…) L14, createState() L26
- L29  class _MarkerRulerState extends ConsumerState<MarkerRuler> (_focusNodes, _busy) — dispose() L34, _focusNodeFor(String markerId) L41, _update(…) L46, _delete(TimelineMarker marker) L67, _edit(TimelineMarker marker) L78, _onKeyEvent(TimelineMarker marker, KeyEvent event) L87, _keyboardForm(…) L113, _isValid(MarkerEditorFormValue value) L161, _formFor(TimelineMarker marker) L182, build(BuildContext context) L192, _semanticLabel(TimelineMarker marker) L251, _isPoint(TimelineMarker marker) L255, _isRange(TimelineMarker marker) L261, _colorFor(String value) L268

## lib/features/tagging/presentation/widgets/media_panel.dart (170 lines)
- L8  class MediaPanel extends ConsumerWidget — MediaPanel(…) L9, build(BuildContext context, WidgetRef ref) L12
- L154  class _MediaPanelMessage extends StatelessWidget (message) — _MediaPanelMessage(this.message) L155, build(BuildContext context) L160

## lib/features/tagging/presentation/widgets/tag_editor_dialog.dart (103 lines)
- L4  class TagEditorFormValue (name, color) — TagEditorFormValue(…) L5, operator L11, hashCode L15
- L18  class TagEditorDialog extends StatefulWidget (initialValue) — TagEditorDialog(…) L19, createState() L24
- L27  class _TagEditorDialogState extends State<TagEditorDialog> (_name, _color) — initState() L32, dispose() L39, _isValid L45, _submit() L53, build(BuildContext context) L61
