# Code Graph — lib/domain (24 files, 7,290 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/domain/agent/agent_activity.dart (42 lines)
- L5  enum AgentActivityKind — runStarted L6, llmRoundStarted L7, llmRoundCompleted L8, toolCallStarted L9, toolCallCompleted L10, toolCallFailed L11, confirmationRequested L12, confirmationResolved L13, runCompleted L14, runFailed L15, runCancelled L16
- L19  class AgentActivityEvent (kind, round, toolCallId, toolName, args, summary, success, durationMs) — AgentActivityEvent(…) L30

## lib/domain/agent/agent_confirmation.dart (44 lines)
- L4  enum ConfirmationKind
- L11  class ConfirmationRequest (round, toolCalls, kind) — ConfirmationRequest(…) L16
- L37  class ConfirmationGate — requiresPerEditApproval L39, ask(ConfirmationRequest request) L42

## lib/domain/agent/agent_edit_applier.dart (49 lines)
- L14  typedef ApplyEditCallback — operation L15, newSourcePath L16, removeClipIds L17
- L24  class AgentEditApplier (onApply) — AgentEditApplier(…) L27, apply(…) L30, applyAll(…) L39

## lib/domain/agent/agent_turn.dart (95 lines)
- L8  enum AgentTurnRole
- L11  enum AgentTurnStopReason
- L15  class AgentToolCall — AgentToolCall(…) L16, AgentToolCall L22
- L35  class AgentTurnMessage — AgentTurnMessage(…) L36, AgentTurnMessage L45
- L52  class AgentTurnRequest — AgentTurnRequest(…) L53, AgentTurnRequest L62
- L68  class AgentToolCallRecord — AgentToolCallRecord(…) L69, AgentToolCallRecord L78
- L84  class AgentTurnResult — AgentTurnResult(…) L85, AgentTurnResult L92

## lib/domain/agent/nl2vec_pipeline.dart (733 lines)
- L28  enum PipelineStage — error L29
- L32  enum SubmitStatus
- L34  class SubmitResult (status, message, appliedOperations, outputPath, records) — SubmitResult(…) L43
- L52  class PipelineEvent (stage, message, progress, outputPath) — PipelineEvent(this.stage, this.message, [this.progress, this.outputPath]) L57
- L60  class Nl2VecPipeline (ffmpegService, ffprobeService, _events) — events L65, _agentActivity L69, agentActivity L72, Nl2VecPipeline(…) L74, submitCommand(…) L79, executePlanned(…) L321, _toolContext(…) L426, _runToolPath(…) L465, _executeWithEvents(…) L537, _clipSnapshotsOf(Project project) L570, _buildClipPathMap(Project project) L587, _resolveDefaultPath(Project project, Map<String, String> clipPathMap) L599, _dirOf(String path) L609, _toEditOperations(…) L620, _parseType(String type) L641, _buildSchemaJson() L682, _serializeToJson(EditOperationSet set) L714, dispose() L718
- L724  class PipelineException (message) — PipelineException(this.message) L726, toString() L729

## lib/domain/agent/operation_schema.dart (83 lines)
- L7  class EditOperationSet — EditOperationSet(…) L8, EditOperationSet L14
- L19  class EditOperationRequest — EditOperationRequest(…) L20, EditOperationRequest L27
- L32  class ValidatedCommand — ValidatedCommand(…) L33
- L41  class ProjectSnapshot — ProjectSnapshot(…) L42
- L55  class ClipSnapshot — ClipSnapshot(…) L56
- L67  class AgentRequest — AgentRequest(…) L68
- L77  class ClarificationNeeded — ClarificationNeeded(…) L78

## lib/domain/agent/stage_1_input_validation.dart (57 lines)
- L6  class InputValidator (maxPromptLength) — validate(…) L9

## lib/domain/agent/stage_2_prompt_construction.dart (146 lines)
- L4  class PromptConstructor — _operationList L5

## lib/domain/agent/stage_3_intent_parsing.dart (37 lines)
- L6  class IntentParser — Future L7

## lib/domain/agent/stage_4_output_validation.dart (191 lines)
- L5  class OutputValidator — validTypes L6, requiredParams L13, validateJson(String rawJson) L30, validate(…) L122, buildRetryPrompt(String originalCommand, List<String> errors) L160

## lib/domain/agent/stage_5_command_mapping.dart (939 lines)
- L9  class CommandMappingException (message) — CommandMappingException(this.message) L11, toString() L14
- L17  class CommandMapper — _composableTypes L18, _singlePassTypes L24, _structuralTypes L32, mapOperations(…) L61, _clipIdOf(EditOperationRequest op) L147, _composeMultiOp(…) L154, _composeFilterGraph(…) L207, _buildMergeJob(…) L485, _mergeAudioFlags(Object? raw, int n, String opId) L552, _mergeDurations(Object? raw, int n, String opId) L566, _buildTransitionJob(…) L582, _buildSingleJob(…) L637, _str(Map<String, dynamic> params, String key, String fallback) L852, _num(Map<String, dynamic> params, String key, double fallback) L859, _int(Map<String, dynamic> params, String key, int fallback) L866, _numOrNull(Map<String, dynamic> params, String key) L874, _firstRangedRestriction(…) L887, _cutRangeParam(Map<String, dynamic> params, String key) L902, _validatedColor(String color) L909, _outputPathFor(…) L917, _dirOf(String path) L928

## lib/domain/agent/stage_6_execution.dart (219 lines)
- L6  class ExecutionProgress (jobId, operationType, percent, status, message) — ExecutionProgress(…) L13
- L22  class ExecutionResult (success, summary, outputPaths, appliedOps, errorMessage) — ExecutionResult(…) L29
- L38  class ExecutionEngine (_ffmpegService) — _progressCtrl L40, progress L43, ExecutionEngine(this._ffmpegService) L45, execute(…) L47, _extractOpType(FfmpegJob job) L138, _parseOpType(FfmpegJob job) L177, cancel() L205, dispose() L209

## lib/domain/agent/tool_calling_agent.dart (600 lines)
- L16  enum AgentRunStatus
- L19  class AgentRunResult (status, message, appliedOperations, outputPath, records) — AgentRunResult(…) L30
- L46  class ToolCallingAgent (provider, registry, context) — _activity L50, activityEvents L53, ToolCallingAgent(…) L55, run(…) L62, _maybeBulkConfirm(…) L251, _confirmOne(…) L285, _askGate(…) L319, _isEditTool(String name) L332, _bulkSummary(List<AgentToolCall> edits) L336, _recordSkipped(…) L342, _executeOne(…) L387, _handleToolLoad(…) L475, _toolNamesArg(Map<String, dynamic> args) L531, _cancelled(…) L542, _recentHistoryLines(List<AgentRequest>? recentHistory) L565, _emit(…) L574, dispose() L596

## lib/domain/agent/tools/project_command_gateway.dart (24 lines)

## lib/domain/agent/tools/tool_definition.dart (117 lines)
- L2  enum ToolCategory
- L10  enum ToolExposure
- L21  class ToolDefinition (name, description, inputSchema, category, exposure) — ToolDefinition(…) L28, toJson() L36, ToolDefinition L44
- L63  class ToolCall (id, name, args) — ToolCall(…) L68
- L79  class ToolResult (success, data, error, summary) — ToolResult(…) L85, ToolResult L92, ToolResult L99
- L114  class ToolExecutor — execute(ToolCall call) L115

## lib/domain/agent/tools/tool_executors.dart (1995 lines)
- L34  class ToolExecutionContext (outputDir, projectDir, applier, ffmpegService, ffprobeService, sceneDetectionService, whisperService, maxJobs) — Function() project L35, Function(String kind)? readAnalysis L57, Function(String kind, Map<String, dynamic> payload)? writeAnalysis L58, Function()? whisperConfig L64, Function(String familyId)? resolveFont L72, ToolExecutionContext(…) L92, resetRun() L115
- L123  class ReadToolExecutor (_ctx, maxTranscriptResultSegments) — ReadToolExecutor(this._ctx) L126, execute(ToolCall call) L129, _listClips() L159, _listTagsAndMarkers() L183, _probeVideo(Map<String, dynamic> args) L254, _editHistory() L287, _detectScenes(Map<String, dynamic> args) L304, _storyboard(Map<String, dynamic> args) L387, _transcript(Map<String, dynamic> args) L451, _segmentsFromCache(Object? raw) L566, _transcriptResult(…) L569, _intList(dynamic raw) L596
- L604  class EditToolExecutor (_ctx, _strictTimecode) — EditToolExecutor(this._ctx) L607, execute(ToolCall call) L610, _trim(ToolCall call) L657, _cut(ToolCall call) L682, _merge(ToolCall call) L730, _changeSpeed(ToolCall call) L801, _mute(ToolCall call) L821, _overlayText(ToolCall call) L834, _normalizeFontFamily(String raw) L904, _resize(ToolCall call) L908, _rotate(ToolCall call) L933, _brightness(ToolCall call) L952, _volume(ToolCall call) L972, _extractAudio(ToolCall call) L992, supportedEffects L1014, _applyEffect(ToolCall call) L1024, supportedTransitions L1095, _addTransition(ToolCall call) L1116, _burnCaptions(ToolCall call) L1260, _runSingleOp(…) L1358, _executeSet(…) L1383, _requireTimecode(String? value, String field) L1482, _requireOrder(…) L1492, _hasFilterBreakout(String text) L1506, _trimNewRange(String startTc, String endTc) L1516, _cutNewRange(…) L1535, _requireClip(String? clipId) L1553, _budgetMessage L1564, _operationType(String type) L1568
- L1609  class CommandToolExecutor (_ctx) — CommandToolExecutor(this._ctx) L1610, _failureHints L1616, _doneLabels L1641, execute(ToolCall call) L1653, _buildCommand(…) L1707, _markerCommand(…) L1772, _requiredCommandString(…) L1817, _targetKind(Object? raw) L1826, _invalidArgs(String tool, String expected) L1834, _failureMessage(String tool, String message) L1837, _successSummary(…) L1844, _targetIds(ProjectCommand command) L1855
- L1871  function createToolRegistry
- L1914  function transcriptSegmentsFromCache
- L1931  function _stringArg
- L1938  function _lowerFirst
- L1943  function _numArg
- L1950  function _unknownClip
- L1957  function _clipPathMap
- L1969  function _clipPath
- L1987  function _defaultPath

## lib/domain/agent/tools/tool_prompts.dart (124 lines)
- L9  class ProjectContextWriter — write(ProjectSnapshot project) L10
- L32  class ToolPromptBuilder — _deferredHints L36, buildSystemPrompt(…) L68
- L96  function commands

## lib/domain/agent/tools/tool_registry.dart (828 lines)
- L14  class ToolRegistry (maxToolRounds, maxEditJobsPerRun, validName, _byName, _executors) — ToolRegistry(…) L29, defaultDefinitions() L38, definitions() L40, definitionFor(String name) L42, executorFor(String name) L44, hasAllExecutors L46, _validate() L49, _validateStrictSchema(ToolDefinition def) L62, _catalog L85

## lib/domain/agent/tools/tool_selection.dart (180 lines)
- L9  class ToolLoadResult (loaded, unknown, alreadyAvailable, validDeferred, limitReached) — ToolLoadResult(…) L25, success L33, message L40
- L67  class ToolSelection (loadToolsName, maxToolLoads, registry, _loaded, _loadsUsed) — loadToolsDefinition L76, ToolSelection(this.registry) L101, loadsUsed L104, loadsRemaining L107, isActive(String name) L112, activeDefinitions() L117, deferredNames() L123, loaderAvailable L129, roundDefinitions() L136, load(List<String> names) L148

## lib/domain/usecases/export_project_usecase.dart (247 lines)
- L9  class ExportResult (success, outputPath, error) — ExportResult(…) L14
- L21  class ExportProjectUseCase (_ffmpegService, _uuid, _cancelled) — _progressController L24, ExportProjectUseCase(…) L28, progressStream L31, cancel() L33, dispose() L38, execute(…) L42, _buildExportArgs(Project project, ExportOptions options) L122, _codecsForFormat(String format) L217, _resolutionDims(String resolution) L232

## lib/domain/usecases/import_video_usecase.dart (100 lines)
- L8  class ImportVideoResult (success, filePath, metadata, thumbnailPath, error) — ImportVideoResult(…) L15
- L24  class ImportVideoUseCase (_ffprobeService, _thumbnailService, _uuid) — ImportVideoUseCase(this._ffprobeService, this._thumbnailService) L29, execute(String filePath,…) L32, createClipFromResult(…) L52, addClipToProject(Project project, Clip clip) L69

## lib/domain/usecases/run_agent_command_usecase.dart (94 lines)
- L17  class RunAgentCommandUseCase (_pipeline) — RunAgentCommandUseCase(this._pipeline) L20, execute(…) L22, executePlanned(…) L66

## lib/domain/usecases/structural_edit_usecase.dart (262 lines)
- L31  class StructuralEditUseCase (minClipDurationMs, originalStartKey, originalEndKey) — StructuralEditUseCase() L32, apply(EditOperation op, Project project) L49, _delete(String? clipId, Project project) L86, _copy(String? clipId, String? newClipId, Project project) L95, _move(String? clipId, String? afterClipId, Project project) L113, _trim(…) L140, _split(String? clipId, int? atMs, Project project) L178, _originalBound(Clip clip, String key, int fallback) L198, _repinned(List<Clip> clips) L204, _durationMs(Clip clip) L214, _locate(Project project, String clipId) L220, _freshCopyId(Project project, String clipId) L230, _withClips(Project project, int trackIndex, List<Clip> clips) L238, _stringParam(EditOperation op, String key) L244, _intParam(EditOperation op, String key) L251, _asInt(Object? value) L253

## lib/domain/usecases/undo_redo_usecase.dart (84 lines)
- L6  typedef UndoEntry
- L9  typedef RedoEntry
- L25  class UndoRedoUseCase (maxHistorySize, _undoStack, _redoStack) — canUndo L31, canRedo L32, undoDepth L35, pushEdit(Project projectBefore, EditOperation operation) L39, pushStructural(Project projectBefore) L47, undo(Project projectNow) L56, redo(Project projectNow) L66, _trim() L73, clear() L79
