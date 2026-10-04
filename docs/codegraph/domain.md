# Code Graph — lib/domain (22 files, 6,253 lines; DO NOT EDIT)
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

## lib/domain/agent/nl2vec_pipeline.dart (722 lines)
- L27  enum PipelineStage — error L28
- L31  enum SubmitStatus
- L33  class SubmitResult (status, message, appliedOperations, outputPath, records) — SubmitResult(…) L42
- L51  class PipelineEvent (stage, message, progress, outputPath) — PipelineEvent(this.stage, this.message, [this.progress, this.outputPath]) L56
- L59  class Nl2VecPipeline (ffmpegService, ffprobeService, _events) — events L64, _agentActivity L68, agentActivity L71, Nl2VecPipeline(…) L73, submitCommand(…) L78, executePlanned(…) L316, _toolContext(…) L419, _runToolPath(…) L456, _executeWithEvents(…) L526, _clipSnapshotsOf(Project project) L559, _buildClipPathMap(Project project) L576, _resolveDefaultPath(Project project, Map<String, String> clipPathMap) L588, _dirOf(String path) L598, _toEditOperations(…) L609, _parseType(String type) L630, _buildSchemaJson() L671, _serializeToJson(EditOperationSet set) L703, dispose() L707
- L713  class PipelineException (message) — PipelineException(this.message) L715, toString() L718

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

## lib/domain/agent/stage_5_command_mapping.dart (937 lines)
- L9  class CommandMappingException (message) — CommandMappingException(this.message) L11, toString() L14
- L17  class CommandMapper — _composableTypes L18, _singlePassTypes L24, _structuralTypes L32, mapOperations(…) L61, _clipIdOf(EditOperationRequest op) L147, _composeMultiOp(…) L154, _composeFilterGraph(…) L207, _buildMergeJob(…) L483, _mergeAudioFlags(Object? raw, int n, String opId) L550, _mergeDurations(Object? raw, int n, String opId) L564, _buildTransitionJob(…) L580, _buildSingleJob(…) L635, _str(Map<String, dynamic> params, String key, String fallback) L850, _num(Map<String, dynamic> params, String key, double fallback) L857, _int(Map<String, dynamic> params, String key, int fallback) L864, _numOrNull(Map<String, dynamic> params, String key) L872, _firstRangedRestriction(…) L885, _cutRangeParam(Map<String, dynamic> params, String key) L900, _validatedColor(String color) L907, _outputPathFor(…) L915, _dirOf(String path) L926

## lib/domain/agent/stage_6_execution.dart (219 lines)
- L6  class ExecutionProgress (jobId, operationType, percent, status, message) — ExecutionProgress(…) L13
- L22  class ExecutionResult (success, summary, outputPaths, appliedOps, errorMessage) — ExecutionResult(…) L29
- L38  class ExecutionEngine (_ffmpegService) — _progressCtrl L40, progress L43, ExecutionEngine(this._ffmpegService) L45, execute(…) L47, _extractOpType(FfmpegJob job) L138, _parseOpType(FfmpegJob job) L177, cancel() L205, dispose() L209

## lib/domain/agent/tool_calling_agent.dart (490 lines)
- L15  enum AgentRunStatus
- L18  class AgentRunResult (status, message, appliedOperations, outputPath, records) — AgentRunResult(…) L29
- L45  class ToolCallingAgent (provider, registry, context) — _activity L49, activityEvents L52, ToolCallingAgent(…) L54, run(…) L61, _maybeBulkConfirm(…) L225, _confirmOne(…) L259, _askGate(…) L293, _isEditTool(String name) L306, _bulkSummary(List<AgentToolCall> edits) L310, _recordSkipped(…) L316, _executeOne(…) L361, _cancelled(…) L432, _recentHistoryLines(List<AgentRequest>? recentHistory) L455, _emit(…) L464, dispose() L486

## lib/domain/agent/tools/tool_definition.dart (99 lines)
- L2  enum ToolCategory
- L10  class ToolDefinition (name, description, inputSchema, category) — ToolDefinition(…) L16, toJson() L23, ToolDefinition L30
- L45  class ToolCall (id, name, args) — ToolCall(…) L50
- L61  class ToolResult (success, data, error, summary) — ToolResult(…) L67, ToolResult L74, ToolResult L81
- L96  class ToolExecutor — execute(ToolCall call) L97

## lib/domain/agent/tools/tool_executors.dart (1620 lines)
- L26  class ToolExecutionContext (outputDir, projectDir, applier, ffmpegService, ffprobeService, sceneDetectionService, whisperService, maxJobs) — Function() project L27, Function(String kind)? readAnalysis L49, Function(String kind, Map<String, dynamic> payload)? writeAnalysis L50, Function()? whisperConfig L56, Function(String familyId)? resolveFont L64, ToolExecutionContext(…) L73, resetRun() L93
- L101  class ReadToolExecutor (_ctx, maxTranscriptResultSegments) — ReadToolExecutor(this._ctx) L104, execute(ToolCall call) L107, _listClips() L134, _probeVideo(Map<String, dynamic> args) L154, _editHistory() L187, _detectScenes(Map<String, dynamic> args) L204, _storyboard(Map<String, dynamic> args) L287, _transcript(Map<String, dynamic> args) L351, _segmentsFromCache(Object? raw) L466, _transcriptResult(…) L469, _intList(dynamic raw) L496
- L504  class EditToolExecutor (_ctx, _strictTimecode) — EditToolExecutor(this._ctx) L507, execute(ToolCall call) L510, _trim(ToolCall call) L557, _cut(ToolCall call) L582, _merge(ToolCall call) L630, _changeSpeed(ToolCall call) L701, _mute(ToolCall call) L721, _overlayText(ToolCall call) L734, _normalizeFontFamily(String raw) L804, _resize(ToolCall call) L808, _rotate(ToolCall call) L833, _brightness(ToolCall call) L852, _volume(ToolCall call) L872, _extractAudio(ToolCall call) L892, supportedEffects L914, _applyEffect(ToolCall call) L924, supportedTransitions L995, _addTransition(ToolCall call) L1016, _burnCaptions(ToolCall call) L1160, _runSingleOp(…) L1258, _executeSet(…) L1283, _requireTimecode(String? value, String field) L1382, _requireOrder(…) L1392, _hasFilterBreakout(String text) L1406, _trimNewRange(String startTc, String endTc) L1416, _cutNewRange(…) L1435, _requireClip(String? clipId) L1453, _budgetMessage L1464, _operationType(String type) L1468
- L1506  function createToolRegistry
- L1539  function transcriptSegmentsFromCache
- L1556  function _stringArg
- L1563  function _lowerFirst
- L1568  function _numArg
- L1575  function _unknownClip
- L1582  function _clipPathMap
- L1594  function _clipPath
- L1612  function _defaultPath

## lib/domain/agent/tools/tool_prompts.dart (78 lines)
- L7  class ProjectContextWriter — write(ProjectSnapshot project) L8
- L30  class ToolPromptBuilder — buildSystemPrompt() L31
- L35  function TOOLS
- L53  function commands

## lib/domain/agent/tools/tool_registry.dart (562 lines)
- L8  class ToolRegistry (maxToolRounds, maxEditJobsPerRun, validName, _byName, _executors) — ToolRegistry(…) L21, defaultDefinitions() L30, definitions() L32, definitionFor(String name) L34, executorFor(String name) L36, hasAllExecutors L38, _validate() L41, _validateStrictSchema(ToolDefinition def) L54, _catalog L77

## lib/domain/usecases/export_project_usecase.dart (247 lines)
- L9  class ExportResult (success, outputPath, error) — ExportResult(…) L14
- L21  class ExportProjectUseCase (_ffmpegService, _uuid, _cancelled) — _progressController L24, ExportProjectUseCase(…) L28, progressStream L31, cancel() L33, dispose() L38, execute(…) L42, _buildExportArgs(Project project, ExportOptions options) L122, _codecsForFormat(String format) L217, _resolutionDims(String resolution) L232

## lib/domain/usecases/import_video_usecase.dart (100 lines)
- L8  class ImportVideoResult (success, filePath, metadata, thumbnailPath, error) — ImportVideoResult(…) L15
- L24  class ImportVideoUseCase (_ffprobeService, _thumbnailService, _uuid) — ImportVideoUseCase(this._ffprobeService, this._thumbnailService) L29, execute(String filePath,…) L32, createClipFromResult(…) L52, addClipToProject(Project project, Clip clip) L69

## lib/domain/usecases/run_agent_command_usecase.dart (89 lines)
- L16  class RunAgentCommandUseCase (_pipeline) — RunAgentCommandUseCase(this._pipeline) L19, execute(…) L21, executePlanned(…) L63

## lib/domain/usecases/structural_edit_usecase.dart (262 lines)
- L31  class StructuralEditUseCase (minClipDurationMs, originalStartKey, originalEndKey) — StructuralEditUseCase() L32, apply(EditOperation op, Project project) L49, _delete(String? clipId, Project project) L86, _copy(String? clipId, String? newClipId, Project project) L95, _move(String? clipId, String? afterClipId, Project project) L113, _trim(…) L140, _split(String? clipId, int? atMs, Project project) L178, _originalBound(Clip clip, String key, int fallback) L198, _repinned(List<Clip> clips) L204, _durationMs(Clip clip) L214, _locate(Project project, String clipId) L220, _freshCopyId(Project project, String clipId) L230, _withClips(Project project, int trackIndex, List<Clip> clips) L238, _stringParam(EditOperation op, String key) L244, _intParam(EditOperation op, String key) L251, _asInt(Object? value) L253

## lib/domain/usecases/undo_redo_usecase.dart (84 lines)
- L6  typedef UndoEntry
- L9  typedef RedoEntry
- L25  class UndoRedoUseCase (maxHistorySize, _undoStack, _redoStack) — canUndo L31, canRedo L32, undoDepth L35, pushEdit(Project projectBefore, EditOperation operation) L39, pushStructural(Project projectBefore) L47, undo(Project projectNow) L56, redo(Project projectNow) L66, _trim() L73, clear() L79
