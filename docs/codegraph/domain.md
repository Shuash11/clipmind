# Code Graph — lib/domain (22 files, 5,534 lines; generated 2026-09-29T15:29; DO NOT EDIT)
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

## lib/domain/agent/nl2vec_pipeline.dart (659 lines)
- L26  enum PipelineStage — error L27
- L30  enum SubmitStatus
- L32  class SubmitResult (status, message, appliedOperations, outputPath, records) — SubmitResult(…) L41
- L50  class PipelineEvent (stage, message, progress, outputPath) — PipelineEvent(this.stage, this.message, [this.progress, this.outputPath]) L55
- L58  class Nl2VecPipeline (ffmpegService, ffprobeService, _events) — events L63, _agentActivity L67, agentActivity L70, Nl2VecPipeline(…) L72, submitCommand(…) L77, executePlanned(…) L281, _toolContext(…) L372, _runToolPath(…) L401, _executeWithEvents(…) L463, _clipSnapshotsOf(Project project) L496, _buildClipPathMap(Project project) L513, _resolveDefaultPath(Project project, Map<String, String> clipPathMap) L525, _dirOf(String path) L535, _toEditOperations(…) L546, _parseType(String type) L567, _buildSchemaJson() L608, _serializeToJson(EditOperationSet set) L640, dispose() L644
- L650  class PipelineException (message) — PipelineException(this.message) L652, toString() L655

## lib/domain/agent/operation_schema.dart (83 lines)
- L7  class EditOperationSet — EditOperationSet(…) L8, EditOperationSet L14
- L19  class EditOperationRequest — EditOperationRequest(…) L20, EditOperationRequest L27
- L32  class ValidatedCommand — ValidatedCommand(…) L33
- L41  class ProjectSnapshot — ProjectSnapshot(…) L42
- L55  class ClipSnapshot — ClipSnapshot(…) L56
- L67  class AgentRequest — AgentRequest(…) L68
- L77  class ClarificationNeeded — ClarificationNeeded(…) L78

## lib/domain/agent/stage_1_input_validation.dart (57 lines)
- L6  class InputValidator (maxPromptLength) — static L9

## lib/domain/agent/stage_2_prompt_construction.dart (146 lines)
- L4  class PromptConstructor — _operationList L5

## lib/domain/agent/stage_3_intent_parsing.dart (37 lines)
- L6  class IntentParser — Future L7

## lib/domain/agent/stage_4_output_validation.dart (191 lines)
- L5  class OutputValidator — validTypes L6, requiredParams L13, validateJson(String rawJson) L30, static L122, buildRetryPrompt(String originalCommand, List<String> errors) L160

## lib/domain/agent/stage_5_command_mapping.dart (601 lines)
- L9  class CommandMappingException (message) — CommandMappingException(this.message) L11, toString() L14
- L17  class CommandMapper — _composableTypes L18, _singlePassTypes L24, _structuralTypes L32, mapOperations(…) L44, _clipIdOf(EditOperationRequest op) L118, _composeMultiOp(…) L122, _composeFilterGraph(…) L144, _buildMergeJob(…) L306, _buildTransitionJob(…) L346, _buildSingleJob(…) L392, _str(Map<String, dynamic> params, String key, String fallback) L543, _num(Map<String, dynamic> params, String key, double fallback) L550, _int(Map<String, dynamic> params, String key, int fallback) L557, _numOrNull(Map<String, dynamic> params, String key) L565, _validatedColor(String color) L571, _outputPathFor(…) L579, _dirOf(String path) L590

## lib/domain/agent/stage_6_execution.dart (206 lines)
- L6  class ExecutionProgress (jobId, operationType, percent, status, message) — ExecutionProgress(…) L13
- L22  class ExecutionResult (success, summary, outputPaths, appliedOps, errorMessage) — ExecutionResult(…) L29
- L38  class ExecutionEngine (_ffmpegService) — _progressCtrl L40, progress L43, ExecutionEngine(this._ffmpegService) L45, execute(…) L47, _extractOpType(FfmpegJob job) L138, _parseOpType(FfmpegJob job) L167, cancel() L192, dispose() L196

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

## lib/domain/agent/tools/tool_executors.dart (1462 lines)
- L26  class ToolExecutionContext (outputDir, projectDir, applier, ffmpegService, ffprobeService, sceneDetectionService, whisperService, maxJobs) — Function() project L27, Function(String kind)? readAnalysis L49, Function(String kind, Map<String, dynamic> payload)? writeAnalysis L50, Function()? whisperConfig L56, ToolExecutionContext(…) L65, resetRun() L84
- L92  class ReadToolExecutor (_ctx, maxTranscriptResultSegments) — ReadToolExecutor(this._ctx) L95, execute(ToolCall call) L98, _listClips() L125, _probeVideo(Map<String, dynamic> args) L145, _editHistory() L178, _detectScenes(Map<String, dynamic> args) L195, _storyboard(Map<String, dynamic> args) L278, _transcript(Map<String, dynamic> args) L342, _segmentsFromCache(Object? raw) L457, _transcriptResult(…) L460, _intList(dynamic raw) L487
- L495  class EditToolExecutor (_ctx, _strictTimecode) — EditToolExecutor(this._ctx) L498, execute(ToolCall call) L501, _trim(ToolCall call) L548, _cut(ToolCall call) L568, _merge(ToolCall call) L589, _changeSpeed(ToolCall call) L636, _mute(ToolCall call) L656, _overlayText(ToolCall call) L669, _resize(ToolCall call) L708, _rotate(ToolCall call) L733, _brightness(ToolCall call) L752, _volume(ToolCall call) L772, _extractAudio(ToolCall call) L792, supportedEffects L814, _applyEffect(ToolCall call) L824, supportedTransitions L895, _addTransition(ToolCall call) L916, _burnCaptions(ToolCall call) L1060, _runSingleOp(…) L1156, _executeSet(…) L1181, _requireTimecode(String? value, String field) L1266, _requireOrder(…) L1276, _hasFilterBreakout(String text) L1290, _requireClip(String? clipId) L1295, _budgetMessage L1306, _operationType(String type) L1310
- L1348  function createToolRegistry
- L1381  function transcriptSegmentsFromCache
- L1398  function _stringArg
- L1405  function _lowerFirst
- L1410  function _numArg
- L1417  function _unknownClip
- L1424  function _clipPathMap
- L1436  function _clipPath
- L1454  function _defaultPath

## lib/domain/agent/tools/tool_prompts.dart (77 lines)
- L7  class ProjectContextWriter — write(ProjectSnapshot project) L8
- L30  class ToolPromptBuilder — buildSystemPrompt() L31
- L35  function TOOLS
- L53  function commands

## lib/domain/agent/tools/tool_registry.dart (554 lines)
- L8  class ToolRegistry (maxToolRounds, maxEditJobsPerRun, validName, _byName, _executors) — ToolRegistry(…) L21, defaultDefinitions() L30, definitions() L32, definitionFor(String name) L34, executorFor(String name) L36, hasAllExecutors L38, _validate() L41, _validateStrictSchema(ToolDefinition def) L54, _catalog L77

## lib/domain/usecases/export_project_usecase.dart (247 lines)
- L9  class ExportResult (success, outputPath, error) — ExportResult(…) L14
- L21  class ExportProjectUseCase (_ffmpegService, _uuid, _cancelled) — _progressController L24, ExportProjectUseCase(…) L28, progressStream L31, cancel() L33, dispose() L38, execute(…) L42, _buildExportArgs(Project project, ExportOptions options) L122

## lib/domain/usecases/import_video_usecase.dart (100 lines)
- L8  class ImportVideoResult (success, filePath, metadata, thumbnailPath, error) — ImportVideoResult(…) L15
- L24  class ImportVideoUseCase (_ffprobeService, _thumbnailService, _uuid) — ImportVideoUseCase(this._ffprobeService, this._thumbnailService) L29, execute(String filePath,…) L32, createClipFromResult(…) L52, addClipToProject(Project project, Clip clip) L69

## lib/domain/usecases/run_agent_command_usecase.dart (67 lines)
- L15  class RunAgentCommandUseCase (_pipeline) — RunAgentCommandUseCase(this._pipeline) L18, execute(…) L20, executePlanned(…) L51

## lib/domain/usecases/structural_edit_usecase.dart (144 lines)
- L19  class StructuralEditUseCase — StructuralEditUseCase() L20, apply(EditOperation op, Project project) L23, _delete(String? clipId, Project project) L44, _copy(String? clipId, String? newClipId, Project project) L55, _move(String? clipId, String? afterClipId, Project project) L73, _repinned(List<Clip> clips) L97, _durationMs(Clip clip) L107, _freshCopyId(Project project, String clipId) L123, _withClips(Project project, int trackIndex, List<Clip> clips) L131, _stringParam(EditOperation op, String key) L137

## lib/domain/usecases/undo_redo_usecase.dart (84 lines)
- L6  typedef UndoEntry
- L9  typedef RedoEntry
- L25  class UndoRedoUseCase (maxHistorySize, _undoStack, _redoStack) — canUndo L31, canRedo L32, undoDepth L35, pushEdit(Project projectBefore, EditOperation operation) L39, pushStructural(Project projectBefore) L47, _trim() L73, clear() L79
