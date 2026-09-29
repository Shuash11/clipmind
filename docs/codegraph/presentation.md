# Code Graph — lib/presentation (25 files, 5,940 lines; generated 2026-09-29T15:29; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/presentation/editor/editor_screen.dart (238 lines)
- L16  class EditorScreen extends ConsumerStatefulWidget (projectId) — EditorScreen(…) L18, createState() L21
- L24  class _EditorScreenState extends ConsumerState<EditorScreen> (_projectState) — initState() L28, didUpdateWidget(covariant EditorScreen oldWidget) L34, _loadProject() L41, build(BuildContext context) L70
- L106  class _EditorShell extends StatelessWidget — _EditorShell() L107, build(BuildContext context) L110
- L147  class _WorkspaceStack extends StatelessWidget — _WorkspaceStack() L148, build(BuildContext context) L151
- L162  class _EditorPanel extends StatelessWidget (child) — _EditorPanel(…) L165, build(BuildContext context) L168
- L183  class _ProjectStateMessage extends StatelessWidget (icon, title, message, actionLabel, onAction) — _ProjectStateMessage(…) L190, build(BuildContext context) L199

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

## lib/presentation/editor/widgets/preview_player.dart (253 lines)
- L9  class PreviewPlayer extends ConsumerStatefulWidget — PreviewPlayer(…) L10, createState() L13
- L16  class _PreviewPlayerState extends ConsumerState<PreviewPlayer> (_player, _controller, _positionSub, _durationSub, _playingSub, _lastPath) — initState() L24, _listenToPlayer() L30, didChangeDependencies() L45, dispose() L56, _togglePlayPause() L64, _skip(int ms) L72, _formatDuration(Duration d) L84, build(BuildContext context) L95

## lib/presentation/editor/widgets/status_bar.dart (202 lines)
- L11  class StatusBar extends ConsumerWidget — StatusBar(…) L12, build(BuildContext context, WidgetRef ref) L15, _providerPill(…) L48, _connectedPill(String? modelName) L84, _truncateModel(String model) L98, _ffmpegPill(AsyncValue<bool> ffmpeg) L104, _agentPill(AgentRunState runState) L132
- L150  class _StatusPill extends StatelessWidget (color, label, spinner) — _StatusPill(…) L155, build(BuildContext context) L163

## lib/presentation/editor/widgets/timeline/clip_block.dart (104 lines)
- L4  class ClipBlock extends StatelessWidget (color, label, durationLabel, width, selected, muted, onTap) — ClipBlock(…) L13, build(BuildContext context) L25

## lib/presentation/editor/widgets/timeline/timeline_view.dart (436 lines)
- L15  class TimelineClipRange (clipId, startMs, endMs) — TimelineClipRange(…) L16
- L27  class TimelineView extends ConsumerStatefulWidget (selectedRange, onRemoveRange, project, projectDocument, onRendered) — TimelineView(…) L28, Function(…) L38, createState() L49
- L52  class _TimelineViewState extends ConsumerState<TimelineView> (_uuid, _zoom, _selectedClipId, _isEditing, _rendered) — didUpdateWidget(covariant TimelineView oldWidget) L60, _showTimelineMessage(String message) L65, _changeZoom(double delta) L74, _removeSelectedRange() L78, _deleteSelectedClip() L106, _copySelectedClip() L125, _replaceTrack(…) L153, _selectedClipLocation(Project? project) L182, build(BuildContext context) L202, _buildTrack(TrackTypeDisplay type, Project? project) L341, _clipsForType(Project? project, TrackTypeDisplay type) L351, _modelTypeForDisplay(TrackTypeDisplay type) L360, _fileNameFromPath(String path) L373, _scheduleRendered(Project? project) L379, _rulerDuration(ProjectDocument? document) L391
- L421  class _ClipLocation (trackIndex, clipIndex, track, clip) — _ClipLocation(…) L427
- L435  enum TrackTypeDisplay

## lib/presentation/editor/widgets/timeline/track_row.dart (181 lines)
- L9  class TrackRow extends StatelessWidget (trackType, clips, zoom, selectedClipId, onClipSelected) — TrackRow(…) L16, _trackColor L25, _icon L38, _label L51, build(BuildContext context) L65, _buildClipWidgets() L117, _clipDurationMs(Clip clip) L148, _clipWidth(int durationMs) L153, _gapWidth(int durationMs) L158, _durationLabel(Clip clip) L163, _fileNameFromPath(String path) L175

## lib/presentation/editor/widgets/toolbar/left_tool_rail.dart (181 lines)
- L10  class LeftToolRail extends ConsumerStatefulWidget — LeftToolRail(…) L11, createState() L14
- L17  class _LeftToolRailState extends ConsumerState<LeftToolRail> (_selectedIndex, _mediaSheetOpen) — _tools L18, _selectTool(int index) L31, _openMediaSheet() L51, _showMessage(String message) L71, build(BuildContext context) L81
- L107  class _ToolItem (icon, label) — _ToolItem(…) L111
- L114  class _ToolButton extends StatelessWidget (icon, label, selected, onPressed) — _ToolButton(…) L120, build(BuildContext context) L128

## lib/presentation/editor/widgets/toolbar/top_action_bar.dart (146 lines)
- L11  class TopActionBar extends ConsumerWidget — TopActionBar(…) L12, build(BuildContext context, WidgetRef ref) L15, _openExportDialog(BuildContext context, Project project) L114
- L122  class _ChromeIconButton extends StatelessWidget (icon, tooltip, enabled, onPressed) — _ChromeIconButton(…) L128, build(BuildContext context) L136

## lib/presentation/project_hub/project_hub_screen.dart (941 lines)
- L31  class ProjectHubScreen extends ConsumerStatefulWidget — ProjectHubScreen(…) L32, createState() L35
- L38  class _ProjectHubScreenState extends ConsumerState<ProjectHubScreen> (_urlController, _urlFocusNode, _isDragActive, _isImporting) — initState() L45, dispose() L53, _handleUrlChanged() L60, _initUpdateCheck() L64, _checkWhatsNew() L78, _awaitLoadedSettings() L109, _updateSettings(AppSettings Function(AppSettings) mutate) L126, _handleBrowse() L134, _handleImportedFiles(List<PlatformFile> files) L145, _handleDrop(DropDoneDetails details) L155, _openProjectForMedia(…) L163, _readMediaDetails(String path) L196, _handleUploadUrl() L210, _getImportDir() L259, _fileNameFromPath(String path) L268, _showImportError(String message) L274, _createBlankProject() L281, _showImportUrlDialog(String sourceType) L299, _showAllProjects() L347, build(BuildContext context) L449, _buildImportSources(BoxConstraints constraints) L560, _buildRecentProjects(List<dynamic> projects) L609, _buildRecentError(ThemeData theme) L629, _buildEmptyRecent(ThemeData theme) L642
- L652  class _HubIntro extends StatelessWidget (theme) — _HubIntro(…) L655, build(BuildContext context) L658
- L701  class _SectionHeader extends StatelessWidget (title, actionLabel, onAction) — _SectionHeader(…) L706, build(BuildContext context) L709
- L736  class _UrlImportBar extends StatelessWidget (controller, focusNode, isImporting, hasUrl, onClear, onImport) — _UrlImportBar(…) L744, build(BuildContext context) L754
- L829  class _CompactMessage extends StatelessWidget (icon, title, message, action) — _CompactMessage(…) L835, build(BuildContext context) L843
- L876  class _RecentSkeleton extends StatelessWidget (compact) — _RecentSkeleton(…) L879, build(BuildContext context) L882
- L935  class _MediaDetails (durationMs, thumbnailPath) — _MediaDetails(…) L939

## lib/presentation/project_hub/widgets/blank_project_card.dart (94 lines)
- L7  class BlankProjectCard extends StatefulWidget (onTap) — BlankProjectCard(…) L10, createState() L13
- L16  class _BlankProjectCardState extends State<BlankProjectCard> (_isHovering) — build(BuildContext context) L20

## lib/presentation/project_hub/widgets/hub_top_bar.dart (120 lines)
- L8  class HubTopBar extends StatelessWidget (onSettings, onNewProject) — HubTopBar(…) L12, build(BuildContext context) L19
- L95  class _Wordmark extends StatelessWidget — _Wordmark() L96, build(BuildContext context) L99

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

## lib/presentation/settings/settings_screen.dart (298 lines)
- L16  class SettingsScreen extends ConsumerStatefulWidget — SettingsScreen(…) L17, createState() L19
- L22  class _SettingsScreenState extends ConsumerState<SettingsScreen> (_appVersion, _checkOnStartup, _binaryController, _modelController, _binaryFocus, _modelFocus) — initState() L31, dispose() L40, _onBinaryFocusLost() L49, _onModelFocusLost() L54, _loadVersion() L59, _persistWhisper() L65, _syncWhisperFields(AppSettings? settings) L76, _updateSettings(AppSettings Function(AppSettings) mutate) L90, build(BuildContext context) L99, _updateSubtitle(UpdateState state) L283

## lib/presentation/settings/widgets/update_dialog.dart (152 lines)
- L5  class UpdateDialog extends StatefulWidget (release) — UpdateDialog(…) L8, show(BuildContext context, ReleaseInfo release) L10, createState() L19
- L22  class _UpdateDialogState extends State<UpdateDialog> (_isDownloading, _progress, _status, _error) — build(BuildContext context) L29, _buildInitialDialog() L39, _buildProgressDialog() L57, _buildErrorDialog() L75, _userFriendlyError(String error) L100, _startUpdate() L121

## lib/presentation/shared_widgets/dashed_border.dart (87 lines)
- L6  class DashedRRectPainter extends CustomPainter (color, strokeWidth, radius, dash, gap) — DashedRRectPainter(…) L7, paint(Canvas canvas, Size size) L22, shouldRepaint(covariant DashedRRectPainter oldDelegate) L44
- L55  class DashedBorder extends StatelessWidget (child, color, radius, strokeWidth, dash, gap) — DashedBorder(…) L63, build(BuildContext context) L74

## lib/presentation/shared_widgets/export_dialog.dart (459 lines)
- L11  class ExportDialog extends ConsumerStatefulWidget (project) — ExportDialog(…) L14, createState() L17
- L20  class _ExportDialogState extends ConsumerState<ExportDialog> (_options, _isExporting, _progress, _done, _progressSub) — initState() L28, dispose() L37, _pickOutputPath() L42, _estimateFileSize() L56, _startExport() L74, _cancelExport() L116, build(BuildContext context) L128, _buildOptions(ThemeData theme) L157, _buildProgress(ThemeData theme) L219, _buildDone(ThemeData theme) L275, _buildDropdown(…) L311, _buildQualitySelector(ThemeData theme) L358, _buildOutputPath(ThemeData theme) L417

## lib/presentation/shared_widgets/uat_survey_dialog.dart (291 lines)
- L7  class UatSurveyDialog extends StatefulWidget (sessionId) — UatSurveyDialog(…) L9, createState() L12
- L15  class _UatSurveyDialogState extends State<UatSurveyDialog> (_responses) — _questions L16, _likertLabels L44, initState() L55, build(BuildContext context) L61, _exportResults() L153
- L186  class _SurveyQuestion (id, text, characteristic) — _SurveyQuestion(…) L190
- L197  class _QuestionCard extends StatelessWidget (question, value, onChanged, _shortLabels) — _QuestionCard(…) L202, build(BuildContext context) L209, _getShortLabel(int index) L289

## lib/presentation/shared_widgets/whats_new_dialog.dart (58 lines)
- L7  class WhatsNewDialog extends StatelessWidget (version, notes) — WhatsNewDialog(…) L11, show(…) L17, build(BuildContext context) L29
