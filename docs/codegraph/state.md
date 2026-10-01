# Code Graph — lib/state (13 files, 2,268 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/state/agent_analysis_providers.dart (70 lines)
- L14  class AgentAnalysisPort (db, projectId, _cache) — AgentAnalysisPort(…) L15, read(String kind) L26, write(String kind, Map<String, dynamic> payload) L29, warmUp(List<String> clipIds) L35, _persist(String kind) L49

## lib/state/agent_providers.dart (195 lines)
- L159  class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> — ChatMessagesNotifier() : super([]) L160, add(ChatMessage message) L162, replaceAll(List<ChatMessage> messages) L167, addAgentResult(…) L172, clear() L190

## lib/state/agent_run_providers.dart (596 lines)
- L26  enum AgentRunState
- L39  class AgentConfirmEditsFlag extends StateNotifier<bool> (_ref) — AgentConfirmEditsFlag(this._ref) : super(false) L40, _syncFromSettings(AppSettings? settings) L50, state(bool value) L57, _persist(bool value) L63
- L81  class PendingConfirmation — PendingConfirmation() : super(null) L82, set(ConfirmationRequest request) L84, clear() L88
- L95  class PendingPlan (command, projectId, steps, calls) — PendingPlan(…) L101
- L114  class PendingPlanHolder — PendingPlanHolder() : super(null) L115, set(PendingPlan plan) L117, clear() L121
- L128  class AgentConfirmationGate (_ref, perEdit, _completer) — AgentConfirmationGate(this._ref,…) L133, requiresPerEditApproval L136, ask(ConfirmationRequest request) L139, resolve(bool approved) L152
- L167  class AgentRunController extends StateNotifier<AgentRunState> (_ref, _uuid, _cancel, _feedSub, _gate) — AgentRunController(this._ref) : super(AgentRunState.idle) L174, isBusy L176, loadHistory(String projectId) L180, submit(String command) L200, _completeAsPlan(…) L328, _postReply(…) L375, approvePlan() L411, discardPlan() L463, approvePendingConfirmation(bool approved) L488, cancel() L496, _toolKinds L510, _toChatStep(AgentToolCallRecord record) L514, _recentHistory() L529, _replyError(Project? project, String text) L549
- L575  class AgentActivityFeed extends StateNotifier<List<AgentActivityEvent>> (maxEvents) — AgentActivityFeed() : super(const []) L578, push(AgentActivityEvent event) L580, clear() L587

## lib/state/export_providers.dart (18 lines)

## lib/state/ffmpeg_providers.dart (33 lines)
- L18  class ActiveJobsNotifier extends StateNotifier<List<FfmpegJob>> — ActiveJobsNotifier() : super([]) L19, add(FfmpegJob job) L21, remove(String jobId) L25, clear() L29

## lib/state/manual_edit_providers.dart (752 lines)
- L20  class ManualCutResult (success, message, outputPath) — ManualCutResult(…) L25, ManualCutResult L31, ManualCutResult L36, ManualCutResult L43, ManualCutResult L51
- L88  class ManualEditController (_ref, _uuid) — ManualEditController(this._ref) L92, submitCut(…) L114, submitRecipe(…) L225, submitOverlayText(…) L339, submitSound(…) L458, submitTrim(…) L586, submitSplit(…) L631, _recipeJournalType(String opType) L674, _resolveTarget(…) L686, _clipPathMap(Project project) L709, _defaultPath(…) L723, _findClip(Project project, String clipId) L736, _toSeconds(int ms) L746

## lib/state/player_providers.dart (31 lines)

## lib/state/project_providers.dart (186 lines)
- L24  class ProjectNotifier — ProjectNotifier() : super(const AsyncValue.data(null)) L25, setProject(Project project) L27, clearProject() L31, applyEdit(…) L64, applyStructuralEdit(EditOperation operation) L118, _newRange(EditOperation operation) L137, _repinned(List<Clip> clips) L151, _asInt(Object? value) L162, _isFirstClip(Project project, String clipId) L171, _firstClipId(Project project) L177

## lib/state/settings_providers.dart (52 lines)
- L18  class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> (_repository, ready) — SettingsNotifier(this._repository) : super(const AsyncValue.loading()) L27, _load() L31, update(AppSettings settings) L37

## lib/state/status_providers.dart (87 lines)

## lib/state/structural_edit_providers.dart (58 lines)
- L21  class StructuralEditApplier (_ref) — StructuralEditApplier(this._ref) L24, apply(EditOperation operation) L26

## lib/state/undo_redo_providers.dart (115 lines)
- L7  class UndoRedoState (canUndo, canRedo, historyCount, position) — UndoRedoState(…) L13
- L21  class UndoRedoNotifier extends StateNotifier<UndoRedoState> (_useCase, _ref) — Function(Project project) _onRestore L24, UndoRedoNotifier(this._useCase, this._ref,…) L26, useCase L36, pushEdit(Project projectBefore, EditOperation operation) L40, pushStructural(Project projectBefore) L46, undo() L53, redo() L70, clear() L86, _emitState() L91

## lib/state/update_providers.dart (75 lines)
- L5  enum UpdateStatus
- L7  class UpdateState (status, release, errorMessage) — UpdateState(…) L12, copyWith(…) L18
- L31  class UpdateNotifier extends StateNotifier<UpdateState> (_checker) — UpdateNotifier(this._checker) : super(const UpdateState()) L34, checkForUpdate(…) L36, dismiss() L63
