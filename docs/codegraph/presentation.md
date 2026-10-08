# Code Graph — lib/presentation (35 files, 9,066 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/presentation/editor/editor_screen.dart (253 lines)
- L18  class EditorScreen extends ConsumerStatefulWidget (projectId) — EditorScreen(…) L20, createState() L23
- L26  class _EditorScreenState extends ConsumerState<EditorScreen> (_projectState) — initState() L30, didUpdateWidget(covariant EditorScreen oldWidget) L36, _loadProject() L43, build(BuildContext context) L77
- L113  class _EditorShell extends ConsumerWidget — _EditorShell() L114, build(BuildContext context, WidgetRef ref) L117
- L162  class _WorkspaceStack extends StatelessWidget — _WorkspaceStack() L163, build(BuildContext context) L166
- L177  class _EditorPanel extends StatelessWidget (child) — _EditorPanel(…) L180, build(BuildContext context) L183
- L198  class _ProjectStateMessage extends StatelessWidget (icon, title, message, actionLabel, onAction) — _ProjectStateMessage(…) L205, build(BuildContext context) L214

## lib/presentation/editor/providers/left_panel_provider.dart (57 lines)
- L7  enum LeftPanelTab
- L12  class LeftPanelState (open, tab, LeftPanelState) — LeftPanelState(…) L16, operator L21, hashCode L25
- L31  class LeftPanelController extends StateNotifier<LeftPanelState> — LeftPanelController() : super(const LeftPanelState.closed()) L32, open(LeftPanelTab tab) L36, close() L40, toggle(LeftPanelTab tab) L44

## lib/presentation/editor/providers/selected_clip_provider.dart (33 lines)
- L14  function resolveSelectedClip
- L26  function clipDisplayLabel

## lib/presentation/editor/widgets/agent_chat/agent_chat_panel.dart (436 lines)
- L19  class AgentChatPanel extends ConsumerStatefulWidget — AgentChatPanel(…) L20, suggestedPrompts L22, createState() L31
- L34  class _AgentChatPanelState extends ConsumerState<AgentChatPanel> (_controller) — initState() L38, dispose() L48, _submitPrompt(String text) L53, build(BuildContext context) L61
- L248  class _ConfirmBar extends StatelessWidget (request, onAnswer) — _ConfirmBar(…) L249, build(BuildContext context) L255
- L340  class _PlanCard extends StatelessWidget (plan, onApprove, onDiscard) — _PlanCard(…) L341, build(BuildContext context) L352

## lib/presentation/editor/widgets/agent_chat/agent_steps_view.dart (486 lines)
- L12  enum AgentStepStatus
- L16  class AgentStepData (toolCallId, toolName, args, summary, durationMs, round, kind, status) — AgentStepData(…) L26, AgentStepData L38, AgentStepData L52, statusForResult(…) L69, kindForTool(String? toolName) L81, copyWith(…) L93
- L115  function deriveLiveSteps
- L154  class AgentStepLabel (AgentStepLabel) — format(String toolName, Map<String, dynamic> args) L157, _generic(Map<String, dynamic> args) L187
- L198  class AgentStepRow extends StatelessWidget (step) — AgentStepRow(…) L199, build(BuildContext context) L204, _detailLines(bool isRead) L269, _statusIcon(AgentStepStatus status) L284, _kindIcon(bool isRead) L318, _formatMs(int ms) L335
- L344  class AgentLivePipelineView extends ConsumerStatefulWidget (confirmation) — AgentLivePipelineView(…) L345, createState() L352
- L356  class _AgentLivePipelineViewState extends ConsumerState<AgentLivePipelineView> (_scroll, _stepsMaxHeight) — dispose() L362, build(BuildContext context) L368, _statusChip(bool paused) L437, _currentRound(List<AgentActivityEvent> events) L478

## lib/presentation/editor/widgets/agent_chat/chat_bubble.dart (195 lines)
- L10  class ChatBubble extends StatefulWidget (message) — ChatBubble(…) L12, createState() L15
- L18  class _ChatBubbleState extends State<ChatBubble> (_expanded) — build(BuildContext context) L22, _stepsHeader(ThemeData theme, List<ChatStep> steps) L103, _formatMs(int ms) L136, _statusIcon(MessageStatus status) L141, _statusColor(MessageStatus status) L169, _statusLabel(MessageStatus status) L182

## lib/presentation/editor/widgets/agent_chat/model_selector_dropdown.dart (14 lines)
- L6  class ModelSelectorDropdown extends StatelessWidget — ModelSelectorDropdown(…) L7, build(BuildContext context) L10

## lib/presentation/editor/widgets/agent_chat/suggested_prompt_chip.dart (29 lines)
- L4  class SuggestedPromptChip extends StatelessWidget (text, onPressed) — SuggestedPromptChip(…) L7, build(BuildContext context) L10

## lib/presentation/editor/widgets/preview_player.dart (259 lines)
- L9  class PreviewPlayer extends ConsumerStatefulWidget — PreviewPlayer(…) L10, createState() L13
- L16  class _PreviewPlayerState extends ConsumerState<PreviewPlayer> (_player, _controller, _positionSub, _durationSub, _playingSub, _lastPath) — initState() L28, _listenToPlayer() L35, didChangeDependencies() L50, dispose() L61, _togglePlayPause() L70, _skip(int ms) L78, _formatDuration(Duration d) L90, build(BuildContext context) L101

## lib/presentation/editor/widgets/status_bar.dart (263 lines)
- L13  class StatusBar extends ConsumerWidget — StatusBar(…) L14, build(BuildContext context, WidgetRef ref) L17, _providerPill(…) L58, _connectedPill(String? modelName) L94, _truncateModel(String model) L108, _ffmpegPill(AsyncValue<bool> ffmpeg) L114, _agentPill(AgentRunState runState) L142
- L165  class _SaveFailurePill extends ConsumerWidget (failure) — _SaveFailurePill(…) L166, build(BuildContext context, WidgetRef ref) L171, _retry(WidgetRef ref) L198
- L207  class _StatusPill extends StatelessWidget (color, label, spinner, icon) — _StatusPill(…) L213, build(BuildContext context) L222

## lib/presentation/editor/widgets/timeline/clip_block.dart (395 lines)
- L7  class ClipBlock extends StatelessWidget (color, label, durationLabel, width, selected, muted, clipId, onTap) — Function(String clipId, bool isStart, int newLocalMs)? onTrimEdge L19, ClipBlock(…) L21, build(BuildContext context) L38, _withTrimHandles(Widget block) L71, _buildBlock(BuildContext context) L111, _blockRow(Color textColor) L149, _buildGhost() L252, _buildDraggingPlaceholder() L276
- L293  class _TrimHandle extends StatefulWidget (clipId, isStart, currentMs, zoom, onTap) — _TrimHandle(…) L294, Function(String clipId, bool isStart, int newLocalMs)? onTrimEdge L308, createState() L312
- L315  class _TrimHandleState extends State<_TrimHandle> (_pxPerSecondBase, _dragPx, _lastGlobalDx, _dragging) — _onDragStart(DragStartDetails details) L322, _onDragUpdate(DragUpdateDetails details) L334, _onDragEnd(DragEndDetails details) L341, build(BuildContext context) L360, _gripBars() L381

## lib/presentation/editor/widgets/timeline/timeline_view.dart (971 lines)
- L25  class TimelineClipRange (clipId, startMs, endMs) — TimelineClipRange(…) L26
- L41  class TimelineView extends ConsumerStatefulWidget (selectedRange, onRemoveRange, project, projectDocument, onRendered) — TimelineView(…) L42, Function(…) L52, createState() L63
- L66  class _TimelineViewState extends ConsumerState<TimelineView> (_minZoom, _maxZoom, _uuid, _rulerKey, _zoom, _selectedClipId, _isEditing, _rendered) — initState() L84, dispose() L90, didUpdateWidget(covariant TimelineView oldWidget) L98, _showTimelineMessage(String message) L103, _selectClip(String? clipId) L115, _changeZoom(double delta) L120, _onCanvasPointerSignal(PointerSignalEvent event) L127, _syncTrackScrolls() L137, _removeSelectedRange() L174, _rulerBox L206, _onRangeDragStart(DragStartDetails details) L209, _onRangeDragUpdate(DragUpdateDetails details) L218, _onRangeDragEnd(DragEndDetails details) L226, _clearRangeDrag() L252, _clipAt(int timeMs) L260, _rulerRangeDurationMs() L274, _cutRange() L283, _onTrimEdge(String clipId, bool isStart, int newLocalMs) L314, _splitAtPlayhead() L340, _onScrubStart(DragStartDetails details) L369, _onScrubUpdate(DragUpdateDetails details) L377, _onScrubEnd(DragEndDetails details) L390, _scrubAreaPx(double globalDx) L399, _seekToAreaPx(double areaPx) L409, _onRulerTapUp(TapUpDetails details) L423, _deleteSelectedClip() L427, _copySelectedClip() L446, _replaceTrack(…) L474, _selectedClipLocation(Project? project) L506, build(BuildContext context) L526, _buildRulerRow(…) L699, _buildSeekStrip() L744, _playheadOverlay(int rulerDuration, double areaWidth) L777, _buildTrack(TrackTypeDisplay type, Project? project) L812, _moveClip(String clipId, String? afterClipId) L829, _rangeHighlight(int rulerDuration) L854, _clipsForType(Project? project, TrackTypeDisplay type) L886, _modelTypeForDisplay(TrackTypeDisplay type) L895, _fileNameFromPath(String path) L908, _scheduleRendered(Project? project) L914, _rulerDuration(ProjectDocument? document) L926
- L956  class _ClipLocation (trackIndex, clipIndex, track, clip) — _ClipLocation(…) L962
- L970  enum TrackTypeDisplay

## lib/presentation/editor/widgets/timeline/track_row.dart (276 lines)
- L9  class TrackRow extends StatefulWidget (trackType, clips, zoom, selectedClipId, onClipSelected, scrollController) — Function(String clipId, String? afterClipId)? onMoveClip L15, Function(String clipId, bool isStart, int newLocalMs)? onTrimEdge L16, TrackRow(…) L24, createState() L37
- L40  class _TrackRowState extends State<TrackRow> (_ownScrollController) — _scrollController L45, dispose() L49, _trackColor L56, _icon L69, _label L82, build(BuildContext context) L96, _buildClipWidgets() L170, _sorted L205, _afterClipIdFor(double localX) L215, _clipDurationMs(Clip clip) L242, _clipWidth(int durationMs) L250, _gapWidth(int durationMs) L254, _durationLabel(Clip clip) L258, _fileNameFromPath(String path) L270

## lib/presentation/editor/widgets/toolbar/left_panel.dart (141 lines)
- L19  class LeftPanel extends ConsumerStatefulWidget — LeftPanel(…) L20, createState() L23
- L26  class _LeftPanelState extends ConsumerState<LeftPanel> (_tabController) — initState() L31, dispose() L42, _onTabChanged() L50, build(BuildContext context) L59

## lib/presentation/editor/widgets/toolbar/left_tool_rail.dart (168 lines)
- L8  class LeftToolRail extends ConsumerStatefulWidget — LeftToolRail(…) L9, createState() L12
- L15  class _LeftToolRailState extends ConsumerState<LeftToolRail> (_selectedIndex) — _tools L16, _selectTool(int index) L28, _showMessage(String message) L50, build(BuildContext context) L60
- L86  class _ToolItem (icon, label, tab) — _ToolItem(…) L94
- L101  class _ToolButton extends StatelessWidget (icon, label, selected, onPressed) — _ToolButton(…) L107, build(BuildContext context) L115

## lib/presentation/editor/widgets/toolbar/panels/adjustments_tab.dart (295 lines)
- L16  class AdjustmentsTab extends ConsumerStatefulWidget — AdjustmentsTab(…) L17, createState() L20
- L23  class _AdjustmentsTabState extends ConsumerState<AdjustmentsTab> (_neutralBrightness, _neutralContrast, _neutralSaturation, _neutralSpeed, _neutralVolume, _brightness, _contrast, _saturation) — build(BuildContext context) L45, _apply() L171, _reset() L209, _resetSliders() L211, _formatValue(…) L224, _showMessage(String message) L233
- L247  class _AdjustmentSlider extends StatelessWidget (label, value, valueText, min, max, onChanged) — _AdjustmentSlider(…) L255, build(BuildContext context) L265

## lib/presentation/editor/widgets/toolbar/panels/audio_tab.dart (254 lines)
- L17  class AudioTab extends ConsumerStatefulWidget — AudioTab(…) L18, createState() L21
- L24  class _AudioTabState extends ConsumerState<AudioTab> (_volume, _isPicking, _busyPresetId) — _presetIcons L26, _pickSound() L42, _applyPreset(ProceduralSoundPreset preset) L69, build(BuildContext context) L93, _showMessage(String message) L174
- L184  class _SoundCard extends StatelessWidget (preset, icon, busy, enabled, onApply) — _SoundCard(…) L191, build(BuildContext context) L200, _durationLabel(double seconds) L250

## lib/presentation/editor/widgets/toolbar/panels/effects_tab.dart (199 lines)
- L15  class EffectsTab extends ConsumerStatefulWidget — EffectsTab(…) L16, createState() L19
- L22  class _EffectsTabState extends ConsumerState<EffectsTab> (_busyPresetId) — _descriptions L25, _icons L37, build(BuildContext context) L53, _apply(EffectPreset preset) L99, _showMessage(String message) L118
- L128  class _EffectCard extends StatelessWidget (preset, description, icon, busy, enabled, onApply) — _EffectCard(…) L136, build(BuildContext context) L146

## lib/presentation/editor/widgets/toolbar/panels/panel_notice.dart (40 lines)
- L7  class PanelNotice extends StatelessWidget (message) — PanelNotice(…) L10, build(BuildContext context) L13

## lib/presentation/editor/widgets/toolbar/panels/text_tab.dart (328 lines)
- L18  class TextTab extends ConsumerStatefulWidget — TextTab(…) L19, createState() L22
- L25  class _TextTabState extends ConsumerState<TextTab> (_textController, _engineLoaded, _loadedFonts, _unavailableFonts, _fontsLoading, _selectedPresetIndex, _isApplying) — _stylePresets L30, _selectedFont L43, initState() L48, dispose() L54, _loadFonts() L64, build(BuildContext context) L100, _apply() L198, _showMessage(String message) L229
- L239  class _TextStylePreset (label, position, fontSize) — _TextStylePreset(…) L244
- L251  class _FontTile extends StatelessWidget (label, fontFamily, available, pending, selected, onSelect) — _FontTile(…) L259, build(BuildContext context) L269

## lib/presentation/editor/widgets/toolbar/panels/transitions_tab.dart (243 lines)
- L20  class TransitionsTab extends ConsumerStatefulWidget — TransitionsTab(…) L21, createState() L24
- L27  class _TransitionsTabState extends ConsumerState<TransitionsTab> (_busyPresetId) — _descriptions L29, _icons L41, _hasFollowingClip(Project? project, Clip selectedClip) L59, build(BuildContext context) L71, _apply(TransitionPreset preset) L143, _showMessage(String message) L162
- L172  class _TransitionCard extends StatelessWidget (preset, description, icon, busy, enabled, onApply) — _TransitionCard(…) L180, build(BuildContext context) L190

## lib/presentation/editor/widgets/toolbar/top_action_bar.dart (201 lines)
- L12  class TopActionBar extends ConsumerWidget — TopActionBar(…) L13, build(BuildContext context, WidgetRef ref) L16, _openExportDialog(BuildContext context, Project project) L115, _undo(BuildContext context, WidgetRef ref) L123, _redo(BuildContext context, WidgetRef ref) L135, _opLabel(EditOperation op) L147
- L177  class _ChromeIconButton extends StatelessWidget (icon, tooltip, enabled, onPressed) — _ChromeIconButton(…) L183, build(BuildContext context) L191

## lib/presentation/project_hub/project_hub_screen.dart (1191 lines)
- L38  enum _UrlImportFlow
- L43  function _isYouTubeUrl
- L51  class ProjectHubScreen extends ConsumerStatefulWidget — ProjectHubScreen(…) L52, createState() L55
- L58  class _ProjectHubScreenState extends ConsumerState<ProjectHubScreen> (_urlController, _urlFocusNode, _isDragActive, _isImporting, _urlFlow, _importProgress, _importGeneration, _cancelActiveImport) — initState() L76, dispose() L84, _handleUrlChanged() L95, _initUpdateCheck() L99, _checkWhatsNew() L130, _awaitLoadedSettings() L161, _updateSettings(AppSettings Function(AppSettings) mutate) L178, _handleBrowse() L186, _handleImportedFiles(List<PlatformFile> files) L194, _handleDrop(DropDoneDetails details) L204, _openProjectForMedia(…) L212, _readMediaDetails(String path) L251, _handleUploadUrl() L265, _handleGuidanceLaunchFailed() L304, _startImport(…) L316, _handleCancelImport() L417, _getImportDir() L435, _fileNameFromPath(String path) L444, _showImportError(String message) L450, _createBlankProject() L457, _showImportUrlDialog(String sourceType) L481, _showAllProjects() L529, build(BuildContext context) L631, _buildImportSources(BoxConstraints constraints) L745, _buildRecentProjects(List<dynamic> projects) L784, _buildRecentError(ThemeData theme) L804, _buildEmptyRecent(ThemeData theme) L817
- L827  class _HubIntro extends StatelessWidget (theme) — _HubIntro(…) L830, build(BuildContext context) L833
- L876  class _SectionHeader extends StatelessWidget (title, actionLabel, onAction) — _SectionHeader(…) L881, build(BuildContext context) L884
- L911  class _UrlImportBar extends StatelessWidget (controller, focusNode, isImporting, urlFlow, progress, hasUrl, onClear, onImport) — _UrlImportBar(…) L922, build(BuildContext context) L935, _buildSubmitButton(…) L1000, _buildProgressCluster(ThemeData theme) L1027
- L1079  class _CompactMessage extends StatelessWidget (icon, title, message, action) — _CompactMessage(…) L1085, build(BuildContext context) L1093
- L1126  class _RecentSkeleton extends StatelessWidget (compact) — _RecentSkeleton(…) L1129, build(BuildContext context) L1132
- L1185  class _MediaDetails (durationMs, thumbnailPath) — _MediaDetails(…) L1189

## lib/presentation/project_hub/widgets/blank_project_card.dart (94 lines)
- L7  class BlankProjectCard extends StatefulWidget (onTap) — BlankProjectCard(…) L10, createState() L13
- L16  class _BlankProjectCardState extends State<BlankProjectCard> (_isHovering) — build(BuildContext context) L20

## lib/presentation/project_hub/widgets/hub_top_bar.dart (127 lines)
- L8  class HubTopBar extends StatelessWidget (onSettings, onNewProject) — HubTopBar(…) L12, build(BuildContext context) L19
- L102  class _Wordmark extends StatelessWidget — _Wordmark() L103, build(BuildContext context) L106

## lib/presentation/project_hub/widgets/import_source_card.dart (107 lines)
- L4  class ImportSourceCard extends StatefulWidget (icon, label, source, subtitle, onTap) — ImportSourceCard(…) L11, createState() L21
- L24  class _ImportSourceCardState extends State<ImportSourceCard> (_isHovering) — _accent L27, build(BuildContext context) L39

## lib/presentation/project_hub/widgets/recent_project_card.dart (253 lines)
- L9  class RecentProjectCard extends StatefulWidget (project) — RecentProjectCard(…) L12, createState() L15
- L18  class _RecentProjectCardState extends State<RecentProjectCard> (_isHovering) — _formatDate(DateTime date) L21, _formatDuration(int durationMs) L52, _isImagePath(String path) L63, build(BuildContext context) L72, _buildThumbnail(Project project) L207, _buildPlaceholderThumbnail() L223

## lib/presentation/project_hub/widgets/upload_dropzone.dart (179 lines)
- L6  class UploadDropzone extends StatefulWidget (onBrowse, isDragActive, isBusy) — Function(DropEventDetails)? onDragEntered L8, Function(DropEventDetails)? onDragExited L9, Function(DropDoneDetails)? onDragDone L10, UploadDropzone(…) L14, createState() L25
- L28  class _UploadDropzoneState extends State<UploadDropzone> (_isHovering) — build(BuildContext context) L32
- L146  class _BusyPill extends StatelessWidget — _BusyPill() L147, build(BuildContext context) L150

## lib/presentation/project_hub/widgets/yt_dlp_guidance_dialog.dart (181 lines)
- L14  class YtDlpGuidanceDialog extends StatelessWidget (onLaunchFailed) — downloadPageUrl L17, YtDlpGuidanceDialog(…) L24, show(…) L28, _openDownloadPage(BuildContext context) L38, build(BuildContext context) L57
- L138  class _GuidanceStep extends StatelessWidget (number, text) — _GuidanceStep(…) L142, build(BuildContext context) L145

## lib/presentation/settings/settings_screen.dart (298 lines)
- L16  class SettingsScreen extends ConsumerStatefulWidget — SettingsScreen(…) L17, createState() L19
- L22  class _SettingsScreenState extends ConsumerState<SettingsScreen> (_appVersion, _checkOnStartup, _binaryController, _modelController, _binaryFocus, _modelFocus) — initState() L31, dispose() L40, _onBinaryFocusLost() L49, _onModelFocusLost() L54, _loadVersion() L59, _persistWhisper() L65, _syncWhisperFields(AppSettings? settings) L76, _updateSettings(AppSettings Function(AppSettings) mutate) L90, build(BuildContext context) L99, _updateSubtitle(UpdateState state) L283

## lib/presentation/settings/widgets/update_dialog.dart (185 lines)
- L5  class UpdateDialog extends StatefulWidget (release, overrideDownloader) — UpdateDialog(…) L13, show(BuildContext context, ReleaseInfo release) L19, createState() L28
- L31  class _UpdateDialogState extends State<UpdateDialog> (_isDownloading, _progress, _status, _error) — build(BuildContext context) L38, _buildInitialDialog() L48, _buildProgressDialog() L66, _buildErrorDialog() L84, _userFriendlyError(String error) L109, _startUpdate() L149

## lib/presentation/shared_widgets/dashed_border.dart (87 lines)
- L6  class DashedRRectPainter extends CustomPainter (color, strokeWidth, radius, dash, gap) — DashedRRectPainter(…) L7, paint(Canvas canvas, Size size) L22, shouldRepaint(covariant DashedRRectPainter oldDelegate) L44
- L55  class DashedBorder extends StatelessWidget (child, color, radius, strokeWidth, dash, gap) — DashedBorder(…) L63, build(BuildContext context) L74

## lib/presentation/shared_widgets/export_dialog.dart (479 lines)
- L12  class ExportDialog extends ConsumerStatefulWidget (project) — ExportDialog(…) L15, createState() L18
- L21  class _ExportDialogState extends ConsumerState<ExportDialog> (_options, _isExporting, _progress, _done, _progressSub) — initState() L29, dispose() L38, _pickOutputPath() L43, _estimateFileSize() L61, _startExport() L79, _cancelExport() L136, build(BuildContext context) L148, _buildOptions(ThemeData theme) L177, _buildProgress(ThemeData theme) L239, _buildDone(ThemeData theme) L295, _buildDropdown(…) L331, _buildQualitySelector(ThemeData theme) L378, _buildOutputPath(ThemeData theme) L437

## lib/presentation/shared_widgets/uat_survey_dialog.dart (291 lines)
- L7  class UatSurveyDialog extends StatefulWidget (sessionId) — UatSurveyDialog(…) L9, createState() L12
- L15  class _UatSurveyDialogState extends State<UatSurveyDialog> (_responses) — _questions L16, _likertLabels L44, initState() L55, build(BuildContext context) L61, _exportResults() L153
- L186  class _SurveyQuestion (id, text, characteristic) — _SurveyQuestion(…) L190
- L197  class _QuestionCard extends StatelessWidget (question, value, onChanged, _shortLabels) — _QuestionCard(…) L202, build(BuildContext context) L209, _getShortLabel(int index) L289

## lib/presentation/shared_widgets/whats_new_dialog.dart (58 lines)
- L7  class WhatsNewDialog extends StatelessWidget (version, notes) — WhatsNewDialog(…) L11, show(…) L17, build(BuildContext context) L29
