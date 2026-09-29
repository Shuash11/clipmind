# Code Graph — lib/state (13 files, 1,553 lines; generated 2026-09-29T15:29; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/state/agent_analysis_providers.dart (70 lines)
- L14  class AgentAnalysisPort (db, projectId, _cache) — AgentAnalysisPort(…) L15, read(String kind) L26, write(String kind, Map<String, dynamic> payload) L29, warmUp(List<String> clipIds) L35, _persist(String kind) L49

## lib/state/agent_providers.dart (163 lines)
- L127  class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> — ChatMessagesNotifier() : super([]) L128, add(ChatMessage message) L130, replaceAll(List<ChatMessage> messages) L135, addAgentResult(…) L140, clear() L158

## lib/state/agent_run_providers.dart (585 lines)
- L25  enum AgentRunState
- L38  class AgentConfirmEditsFlag extends StateNotifier<bool> (_ref) — AgentConfirmEditsFlag(this._ref) : super(false) L39, _syncFromSettings(AppSettings? settings) L49, state(bool value) L56, _persist(bool value) L62
- L80  class PendingConfirmation — PendingConfirmation() : super(null) L81, set(ConfirmationRequest request) L83, clear() L87
- L94  class PendingPlan (command, projectId, steps, calls) — PendingPlan(…) L100
- L113  class PendingPlanHolder — PendingPlanHolder() : super(null) L114, set(PendingPlan plan) L116, clear() L120
- L127  class AgentConfirmationGate (_ref, perEdit, _completer) — AgentConfirmationGate(this._ref,…) L132, requiresPerEditApproval L135, ask(ConfirmationRequest request) L138, resolve(bool approved) L151
- L166  class AgentRunController extends StateNotifier<AgentRunState> (_ref, _uuid, _cancel, _feedSub, _gate) — AgentRunController(this._ref) : super(AgentRunState.idle) L173, isBusy L175, loadHistory(String projectId) L179, submit(String command) L199, _completeAsPlan(…) L318, _postReply(…) L365, approvePlan() L401, discardPlan() L452, approvePendingConfirmation(bool approved) L477, cancel() L485, _toolKinds L499, _toChatStep(AgentToolCallRecord record) L503, _recentHistory() L518, _replyError(Project? project, String text) L538
- L564  class AgentActivityFeed extends StateNotifier<List<AgentActivityEvent>> (maxEvents) — AgentActivityFeed() : super(const []) L567, push(AgentActivityEvent event) L569, clear() L576

## lib/state/export_providers.dart (18 lines)

## lib/state/ffmpeg_providers.dart (33 lines)
- L18  class ActiveJobsNotifier extends StateNotifier<List<FfmpegJob>> — ActiveJobsNotifier() : super([]) L19, add(FfmpegJob job) L21, remove(String jobId) L25, clear() L29

## lib/state/manual_edit_providers.dart (171 lines)
- L14  class ManualCutResult (success, message, outputPath) — ManualCutResult(…) L19, ManualCutResult L25, ManualCutResult L31
- L46  class ManualEditController (_ref, _uuid) — ManualEditController(this._ref) L50, submitCut(…) L53, _findClip(Project project, String clipId) L155, _toSeconds(int ms) L165

## lib/state/player_providers.dart (12 lines)

## lib/state/project_providers.dart (114 lines)
- L24  class ProjectNotifier — ProjectNotifier() : super(const AsyncValue.data(null)) L25, setProject(Project project) L27, clearProject() L31, applyEdit(…) L46, applyStructuralEdit(EditOperation operation) L84, _isFirstClip(Project project, String clipId) L99, _firstClipId(Project project) L105

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
