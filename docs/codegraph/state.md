# Code Graph — lib/state (15 files, 2,960 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/state/agent_analysis_providers.dart (70 lines)
- L14  class AgentAnalysisPort (db, projectId, _cache) — AgentAnalysisPort(…) L15, read(String kind) L26, write(String kind, Map<String, dynamic> payload) L29, warmUp(List<String> clipIds) L35, _persist(String kind) L49

## lib/state/agent_providers.dart (188 lines)
- L152  class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> — ChatMessagesNotifier() : super([]) L153, add(ChatMessage message) L155, replaceAll(List<ChatMessage> messages) L160, addAgentResult(…) L165, clear() L183

## lib/state/agent_run_providers.dart (604 lines)
- L29  enum AgentRunState
- L42  class AgentConfirmEditsFlag extends StateNotifier<bool> (_ref) — AgentConfirmEditsFlag(this._ref) : super(false) L43, _syncFromSettings(AppSettings? settings) L53, state(bool value) L60, _persist(bool value) L66
- L84  class PendingConfirmation — PendingConfirmation() : super(null) L85, set(ConfirmationRequest request) L87, clear() L91
- L98  class PendingPlan (command, projectId, steps, calls) — PendingPlan(…) L104
- L117  class PendingPlanHolder — PendingPlanHolder() : super(null) L118, set(PendingPlan plan) L120, clear() L124
- L131  class AgentConfirmationGate (_ref, perEdit, _completer) — AgentConfirmationGate(this._ref,…) L136, requiresPerEditApproval L139, ask(ConfirmationRequest request) L142, resolve(bool approved) L155
- L170  class AgentRunController extends StateNotifier<AgentRunState> (_ref, _uuid, _cancel, _feedSub, _gate) — AgentRunController(this._ref) : super(AgentRunState.idle) L177, isBusy L179, loadHistory(String projectId) L183, submit(String command) L203, _completeAsPlan(…) L332, _postReply(…) L379, approvePlan() L415, discardPlan() L468, approvePendingConfirmation(bool approved) L493, cancel() L501, _toolKinds L517, _toChatStep(AgentToolCallRecord record) L522, _recentHistory() L537, _replyError(Project? project, String text) L557
- L583  class AgentActivityFeed extends StateNotifier<List<AgentActivityEvent>> (maxEvents) — AgentActivityFeed() : super(const []) L586, push(AgentActivityEvent event) L588, clear() L595

## lib/state/export_providers.dart (14 lines)

## lib/state/ffmpeg_providers.dart (34 lines)
- L19  class ActiveJobsNotifier extends StateNotifier<List<FfmpegJob>> — ActiveJobsNotifier() : super([]) L20, add(FfmpegJob job) L22, remove(String jobId) L26, clear() L30

## lib/state/import_providers.dart (22 lines)

## lib/state/manual_edit_providers.dart (1313 lines)
- L25  class ManualCutResult (success, message, outputPath) — ManualCutResult(…) L30, ManualCutResult L36, ManualCutResult L41, ManualCutResult L48, ManualCutResult L56
- L106  class ManualEditController (_ref, _uuid) — ManualEditController(this._ref) L110, submitCut(…) L132, submitRecipe(…) L254, submitAdjustments(…) L416, submitTransition(…) L626, submitOverlayText(…) L855, submitSound(…) L976, submitTrim(…) L1106, submitSplit(…) L1151, _recipeJournalType(String opType) L1194, _adjustmentsJournalType(String opType) L1208, _resolveTarget(…) L1224, _sourceHasAudioFor(…) L1254, _clipPathMap(Project project) L1270, _defaultPath(…) L1284, _findClip(Project project, String clipId) L1297, _toSeconds(int ms) L1307

## lib/state/player_providers.dart (32 lines)

## lib/state/project_command_gateway_providers.dart (57 lines)
- L26  class TaggingProjectCommandGateway (_providers) — TaggingProjectCommandGateway(this._providers, this._nextTransactionId) L27, Function() _nextTransactionId L30, snapshot() L33, applyCommands(…) L42

## lib/state/project_providers.dart (242 lines)
- L27  class ProjectSaveFailure (message, failedAt) — ProjectSaveFailure(…) L28
- L51  function persistProject
- L71  function _recordSaveFailure
- L80  class ProjectNotifier — ProjectNotifier() : super(const AsyncValue.data(null)) L81, setProject(Project project) L83, clearProject() L87, applyEdit(…) L120, applyStructuralEdit(EditOperation operation) L174, _newRange(EditOperation operation) L193, _repinned(List<Clip> clips) L207, _asInt(Object? value) L218, _isFirstClip(Project project, String clipId) L227, _firstClipId(Project project) L233

## lib/state/settings_providers.dart (53 lines)
- L19  class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> (_repository, ready) — SettingsNotifier(this._repository) : super(const AsyncValue.loading()) L28, _load() L32, update(AppSettings settings) L38

## lib/state/status_providers.dart (86 lines)

## lib/state/structural_edit_providers.dart (55 lines)
- L21  class StructuralEditApplier (_ref) — StructuralEditApplier(this._ref) L24, apply(EditOperation operation) L26

## lib/state/undo_redo_providers.dart (114 lines)
- L8  class UndoRedoState (canUndo, canRedo, historyCount, position) — UndoRedoState(…) L14
- L22  class UndoRedoNotifier extends StateNotifier<UndoRedoState> (_useCase, _ref) — Function(Project project) _onRestore L25, UndoRedoNotifier(this._useCase, this._ref,…) L27, useCase L37, pushEdit(Project projectBefore, EditOperation operation) L41, pushStructural(Project projectBefore) L47, undo() L54, redo() L71, clear() L87, _emitState() L92

## lib/state/update_providers.dart (76 lines)
- L6  enum UpdateStatus
- L8  class UpdateState (status, release, errorMessage) — UpdateState(…) L13, copyWith(…) L19
- L32  class UpdateNotifier extends StateNotifier<UpdateState> (_checker) — UpdateNotifier(this._checker) : super(const UpdateState()) L35, checkForUpdate(…) L37, dismiss() L64
