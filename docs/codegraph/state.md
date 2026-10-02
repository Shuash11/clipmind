# Code Graph — lib/state (13 files, 2,762 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/state/agent_analysis_providers.dart (70 lines)
- L14  class AgentAnalysisPort (db, projectId, _cache) — AgentAnalysisPort(…) L15, read(String kind) L26, write(String kind, Map<String, dynamic> payload) L29, warmUp(List<String> clipIds) L35, _persist(String kind) L49

## lib/state/agent_providers.dart (191 lines)
- L155  class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> — ChatMessagesNotifier() : super([]) L156, add(ChatMessage message) L158, replaceAll(List<ChatMessage> messages) L163, addAgentResult(…) L168, clear() L186

## lib/state/agent_run_providers.dart (597 lines)
- L27  enum AgentRunState
- L40  class AgentConfirmEditsFlag extends StateNotifier<bool> (_ref) — AgentConfirmEditsFlag(this._ref) : super(false) L41, _syncFromSettings(AppSettings? settings) L51, state(bool value) L58, _persist(bool value) L64
- L82  class PendingConfirmation — PendingConfirmation() : super(null) L83, set(ConfirmationRequest request) L85, clear() L89
- L96  class PendingPlan (command, projectId, steps, calls) — PendingPlan(…) L102
- L115  class PendingPlanHolder — PendingPlanHolder() : super(null) L116, set(PendingPlan plan) L118, clear() L122
- L129  class AgentConfirmationGate (_ref, perEdit, _completer) — AgentConfirmationGate(this._ref,…) L134, requiresPerEditApproval L137, ask(ConfirmationRequest request) L140, resolve(bool approved) L153
- L168  class AgentRunController extends StateNotifier<AgentRunState> (_ref, _uuid, _cancel, _feedSub, _gate) — AgentRunController(this._ref) : super(AgentRunState.idle) L175, isBusy L177, loadHistory(String projectId) L181, submit(String command) L201, _completeAsPlan(…) L329, _postReply(…) L376, approvePlan() L412, discardPlan() L464, approvePendingConfirmation(bool approved) L489, cancel() L497, _toolKinds L511, _toChatStep(AgentToolCallRecord record) L515, _recentHistory() L530, _replyError(Project? project, String text) L550
- L576  class AgentActivityFeed extends StateNotifier<List<AgentActivityEvent>> (maxEvents) — AgentActivityFeed() : super(const []) L579, push(AgentActivityEvent event) L581, clear() L588

## lib/state/export_providers.dart (14 lines)

## lib/state/ffmpeg_providers.dart (34 lines)
- L19  class ActiveJobsNotifier extends StateNotifier<List<FfmpegJob>> — ActiveJobsNotifier() : super([]) L20, add(FfmpegJob job) L22, remove(String jobId) L26, clear() L30

## lib/state/manual_edit_providers.dart (1248 lines)
- L25  class ManualCutResult (success, message, outputPath) — ManualCutResult(…) L30, ManualCutResult L36, ManualCutResult L41, ManualCutResult L48, ManualCutResult L56
- L106  class ManualEditController (_ref, _uuid) — ManualEditController(this._ref) L110, submitCut(…) L132, submitRecipe(…) L243, submitAdjustments(…) L381, submitTransition(…) L590, submitOverlayText(…) L817, submitSound(…) L936, submitTrim(…) L1064, submitSplit(…) L1109, _recipeJournalType(String opType) L1152, _adjustmentsJournalType(String opType) L1166, _resolveTarget(…) L1182, _clipPathMap(Project project) L1205, _defaultPath(…) L1219, _findClip(Project project, String clipId) L1232, _toSeconds(int ms) L1242

## lib/state/player_providers.dart (32 lines)

## lib/state/project_providers.dart (187 lines)
- L25  class ProjectNotifier — ProjectNotifier() : super(const AsyncValue.data(null)) L26, setProject(Project project) L28, clearProject() L32, applyEdit(…) L65, applyStructuralEdit(EditOperation operation) L119, _newRange(EditOperation operation) L138, _repinned(List<Clip> clips) L152, _asInt(Object? value) L163, _isFirstClip(Project project, String clipId) L172, _firstClipId(Project project) L178

## lib/state/settings_providers.dart (53 lines)
- L19  class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> (_repository, ready) — SettingsNotifier(this._repository) : super(const AsyncValue.loading()) L28, _load() L32, update(AppSettings settings) L38

## lib/state/status_providers.dart (86 lines)

## lib/state/structural_edit_providers.dart (58 lines)
- L21  class StructuralEditApplier (_ref) — StructuralEditApplier(this._ref) L24, apply(EditOperation operation) L26

## lib/state/undo_redo_providers.dart (116 lines)
- L8  class UndoRedoState (canUndo, canRedo, historyCount, position) — UndoRedoState(…) L14
- L22  class UndoRedoNotifier extends StateNotifier<UndoRedoState> (_useCase, _ref) — Function(Project project) _onRestore L25, UndoRedoNotifier(this._useCase, this._ref,…) L27, useCase L37, pushEdit(Project projectBefore, EditOperation operation) L41, pushStructural(Project projectBefore) L47, undo() L54, redo() L71, clear() L87, _emitState() L92

## lib/state/update_providers.dart (76 lines)
- L6  enum UpdateStatus
- L8  class UpdateState (status, release, errorMessage) — UpdateState(…) L13, copyWith(…) L19
- L32  class UpdateNotifier extends StateNotifier<UpdateState> (_checker) — UpdateNotifier(this._checker) : super(const UpdateState()) L35, checkForUpdate(…) L37, dismiss() L64
