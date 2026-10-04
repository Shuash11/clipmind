# Code Graph — lib/data (41 files, 6,897 lines; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## lib/data/local/database/app_database.dart (368 lines)
- L15  class Projects extends Table — id L16, name L17, projectPath L18, thumbnailPath L19, durationMs L20, createdAt L21, updatedAt L22, sourceMediaPaths L23, documentSchemaVersion L24, documentRevision L25, primaryKey L28
- L32  class ChatMessages extends Table — id L33, projectId L34, role L35, content L36, timestamp L37, status L38, stepsJson L39, resultingOperationIds L40, primaryKey L43
- L46  class EditHistory extends Table — id L47, projectId L48, operationType L49, params L50, createdAt L51, primaryKey L54
- L65  class MediaAnalysis extends Table — id L66, projectId L67, kind L68, sourcePath L69, payload L70, createdAt L71, primaryKey L74
- L78  class AppDatabase — AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection()) L79, schemaVersion L82, migration L85, upsertProject(…) L107, getProject(String id) L125, listRecentProjects(…) L133, deleteProject(String id) L147, getProjectPath(String id) L151, saveChatMessage(…) L160, getChatMessages(…) L181, deleteChatMessages(String projectId) L197, saveEditOperation(…) L205, getEditHistory(…) L220, deleteEditHistory(String projectId) L236, saveAnalysis(…) L245, getAnalysis(String projectId, String kind) L264, getAnalysisPayload(…) L271, deleteAnalysis(String projectId) L285, _projectRowToModel(ProjectRow row) L293, _chatMessageRowToModel(ChatMessageRow row) L307, _decodeOperationIds(String? raw) L321, _decodeSteps(String? raw) L330, _editHistoryRowToModel(EditHistoryData row) L347
- L361  function _openConnection

## lib/data/local/project_file_store.dart (74 lines)
- L6  class ProjectFileStore — write(Project project, String directory) L7, read(String filePath) L20, list(String directory) L32, export(Project project, String path, String format) L52

## lib/data/local/secure_key_store.dart (34 lines)
- L3  class SecureKeyStore (_storage, _keyPrefix) — SecureKeyStore() : _storage = const FlutterSecureStorage() L8, _keyFor(String provider) L11, saveApiKey(String provider, String key) L13, readApiKey(String provider) L17, deleteApiKey(String provider) L21, hasApiKey(String provider) L25, clearAll() L30

## lib/data/models/app_settings.dart (30 lines)
- L6  enum ThemeModePreference
- L9  class AppSettings — AppSettings(…) L10, AppSettings L27

## lib/data/models/chat_message.dart (28 lines)
- L8  enum ChatRole
- L11  class ChatMessage — ChatMessage(…) L13, ChatMessage L23
- L27  enum MessageStatus

## lib/data/models/chat_step.dart (29 lines)
- L7  enum ChatStepKind
- L14  class ChatStep — ChatStep(…) L15, ChatStep L26

## lib/data/models/clip.dart (22 lines)
- L7  class Clip — Clip(…) L8, Clip L20

## lib/data/models/edit_operation.dart (62 lines)
- L6  enum EditOperationType (splitClip) — trim L7, cut L8, merge L9, changeSpeed L10, mute L11, overlayText L12, resize L13, rotate L14, extractAudio L15, generateThumbnail L16, changeFormat L17, adjustBrightness L18, changeVolume L19, overlayWatermark L20, burnCaptions L21, addTransition L22, applyEffect L23, deleteClip L27, copyClip L28, moveClip L29, addSound L33, trimClip L38, jsonValue L41
- L44  enum OperationStatus
- L47  class EditOperation — EditOperation(…) L48, EditOperation L59

## lib/data/models/export_options.dart (71 lines)
- L1  class ExportOptions (format, resolution, quality, crf, outputPath, formats, qualities) — ExportOptions(…) L8, Map L16, qualityCrfMap L24, resolutions L32, crfForQuality(String quality) L41, ExportOptions L45, copyWith(…) L55

## lib/data/models/project.dart (28 lines)
- L10  class Project — Project(…) L11, Project L25

## lib/data/models/track.dart (20 lines)
- L7  enum TrackType
- L10  class Track — Track(…) L11, Track L18

## lib/data/repositories/chat_repository.dart (49 lines)
- L5  class ChatRepository (_db, _messages, _controller) — ChatRepository(this._db) L10, messages L12, stream L13, add(ChatMessage message,…) L15, getHistory(String projectId) L23, recent(int count) L31, clear(…) L37, dispose() L45

## lib/data/repositories/project_repository.dart (112 lines)
- L10  class ProjectRepository (_db, _fileStore, _uuid) — ProjectRepository(this._db) : _fileStore = ProjectFileStore() L15, createNew(…) L17, save(Project project) L38, load(String path) L45, loadFromId(String id) L49, listRecent() L58, delete(String id) L62, _getProjectsDir() L71, _buildInitialTracks(…) L78, _fileNameFromPath(String path) L106

## lib/data/repositories/settings_repository.dart (54 lines)
- L8  class SettingsRepository (_cached, _controller, _disposed) — stream L13, load() L15, save(AppSettings settings) L32, getActiveProviderId() L44, dispose() L49

## lib/data/services/ffmpeg/command_builder.dart (725 lines)
- L7  class CommandBuilder — trim(String input, String start, String end) L8, cut(…) L25, shiftedCutTime(String removeTime, double clipStartSec) L68, _cutTimeToSeconds(String time) L76, merge(…) L116, _mergeSilenceDuration(List<double?>? durations, int index) L205, changeSpeed(…) L229, mute(String input) L270, overlayText(…) L274, resize(String input, int width, int height, String fit) L337, rotate(String input, double degrees) L358, burnCaptions(…) L380, burnCaptionsFilter(…) L402, transition(…) L435, effectFilter(…) L495, effect(…) L524, extractAudio(String input, String outputFormat) L545, generateThumbnail(String input, String timestamp) L557, changeFormat(…) L561, adjustBrightness(String input, double value) L583, changeVolume(String input, double factor) L588, overlayPosition(String position) L596, overlayWatermark(…) L611, addAudio(…) L646, proceduralSoundSource(String presetId) L706, lavfiToWav(String source) L721

## lib/data/services/ffmpeg/ffmpeg_binary_resolver.dart (62 lines)
- L3  class FfmpegBinaryResolver (_cachedFfmpeg, _cachedFfprobe) — resolveFfmpeg(…) L7, resolveFfprobe(…) L13, _resolve(String binary,…) L19, _bundledPath(String binary) L29, _executablePlatform() L35, _which(String binary) L42, invalidateCache() L57

## lib/data/services/ffmpeg/ffmpeg_service.dart (275 lines)
- L10  class FfmpegProgress (percent, outTimeMs, speed, status) — FfmpegProgress(…) L16
- L24  class FfmpegJob (id, args, expectedDurationMs, inputPath, outputPath, label) — FfmpegJob(…) L32
- L42  class FfmpegResult (success, outputPath, exitCode, stderr, error) — FfmpegResult(…) L49
- L58  class FfmpegService (_resolver, _tempDir, _uuid, jobTimeout, _process) — Function(String binary, List<String> args)? L70, FfmpegService(…) L75, tempDir L83, createTempPath(…) L85, run(FfmpegJob job) async* L91, runSync(FfmpegJob job) L169, cancel() L252, dispose() L257
- L268  class FfmpegBinaryNotFoundException (message) — FfmpegBinaryNotFoundException(this.message) L270, toString() L273

## lib/data/services/ffmpeg/ffprobe_service.dart (213 lines)
- L8  class VideoMetadata (durationMs, width, height, fps, codec, hasAudio, bitrate, audioSampleRate) — VideoMetadata(…) L18
- L30  class FfprobeService (_resolver, probeTimeout) — Function(String binary, List<String> args)? L37, FfprobeService(…) L44, _realRunProbe(…) L54, extractMetadata(String filePath) L74, _parseMetadata(Map<String, dynamic> data) L120, generateThumbnail(…) L167

## lib/data/services/ffmpeg/filter_escaping.dart (111 lines)
- L5  class FilterEscaping (_hexColor) — escapeDrawtext(String text) L13, validateColor(String color) L23, assColorFromHex(String color) L37, escapeSubtitlePath(String path) L53, escapeFontFilePath(String path) L66, validateImagePath(String imagePath,…) L78
- L104  class FilterValidationException (message) — FilterValidationException(this.message) L106, toString() L109

## lib/data/services/ffmpeg/filter_graph_composer.dart (551 lines)
- L8  class FilterGraphComposer (_uuid) — compose(…) L11, _composeClip(…) L34, _buildFilterJob(…) L82, _accumulateFilter(…) L140, _atempoChain(double factor) L328, _buildStandaloneJob(EditOperation op, String inputPath) L343, _buildOpArgs(EditOperation op, String inputPath) L360, _outputExtension(EditOperation op) L497, _paramString(Map<String, dynamic> p, String key, String fallback) L514, _paramNum(Map<String, dynamic> p, String key, double fallback) L521, _paramInt(Map<String, dynamic> p, String key, int fallback) L528, _paramDoubleOrNull(Map<String, dynamic> p, String key) L536, _paramCutRangeOrNull(Map<String, dynamic> p, String key) L544

## lib/data/services/ffmpeg/procedural_sound_service.dart (111 lines)
- L11  class ProceduralSoundPreset (id, label, durationSeconds) — ProceduralSoundPreset(…) L16
- L30  class ProceduralSoundService (_resolver) — Function(String exe, List<String> args) _run L34, presets L36, ProceduralSoundService(…) L61, isKnownPreset(String presetId) L68, lavfiSourceFor(String presetId) L73, generate(…) L82

## lib/data/services/ffmpeg/scene_detection_service.dart (95 lines)
- L8  typedef SceneTimestampMs
- L11  class SceneDetection (scenesMs, truncated) — SceneDetection(…) L18, count L20
- L34  class SceneDetectionService (_resolver, thresholdDefault, maxScenesDefault) — Function(String exe, List<String> args) _run L38, SceneDetectionService(…) L43, detectScenes(…) L53, parseSceneTimestampsMs(String stderr) L90

## lib/data/services/ffmpeg/srt_builder.dart (41 lines)
- L10  class SrtBuilder — buildSrt(List<TranscriptSegment> segments) L12, formatTimestamp(int ms) L30

## lib/data/services/fonts/font_resolver.dart (125 lines)
- L12  class BundledFont (id, label, fileName) — BundledFont(…) L22
- L36  class FontResolver (_cache) — catalog L37, Function(String key) _loadAsset L69, Function() _supportDir L73, FontResolver(…) L75, isKnownFamily(String familyId) L82, cachedPath(String familyId) L88, resolve(String familyId) L94, invalidateCache() L123

## lib/data/services/import/url_import_service.dart (121 lines)
- L6  class GDriveInvalidInputException (message) — GDriveInvalidInputException(this.message) L9, toString() L12
- L20  class UrlImportService (_dio, _cancelToken, _progress, _errorStream) — driveLinkMessage L21, progress L31, errors L32, UrlImportService(…) L35, _reportError(String message) L43, import(String fileUrl, String outputPath) L56, _downloadDirect(String fileUrl, String outputPath) L93, cancel() L115

## lib/data/services/import/youtube_import_service.dart (79 lines)
- L5  class YouTubeImportService (_progress, _errorStream, _process) — progress L10, errors L11, import(String url, String outputDir) L13, cancel() L75

## lib/data/services/llm/anthropic_provider.dart (444 lines)
- L10  class AnthropicConfig (model, apiKey) — AnthropicConfig(…) L14
- L20  class AnthropicProvider extends LlmProvider (_baseUrl, _apiVersion, config, _keyStore, _dio, _healthTimer, _status) — _models L23, _connectionCtrl L32, id L38, AnthropicProvider(…) L40, _resolveApiKey() L59, availableModels() L69, parseCommand(AgentRequest request) L74, supportsToolCalling L164, chatWithTools(AgentTurnRequest request) L173, _toWireMessages(AgentTurnRequest request) L217, _turnToWire(AgentTurnMessage turn) L234, _parseTurnResponse(Map<String, dynamic>? data) L272, _buildSchema(String schemaJson) L315, _cleanJsonResponse(String raw) L350, _isTransientError(DioException e) L363, _formatDioError(DioException e) L378, watchConnection() L398, _checkHealth() L408, dispose() L438

## lib/data/services/llm/custom_openai_compatible_provider.dart (204 lines)
- L11  class CustomOpenAiConfig (endpoint, model, apiKey) — CustomOpenAiConfig(…) L21
- L40  class CustomOpenAiCompatibleProvider extends OpenAiCompatibleLlmProvider (config, _dio, _healthTimer, _status) — _connectionCtrl L43, id L49, baseUrl L52, _normalizedEndpoint L58, modelName L64, dio L67, chatCompletionsPath L73, usesMaxCompletionTokens L78, supportsToolCalling L81, suggestedRoundTimeoutSeconds L85, CustomOpenAiCompatibleProvider(…) L87, resolveApiKey() L104, availableModels() L113, parseCommand(AgentRequest request) L122, chatWithTools(AgentTurnRequest request) L135, connectionErrorText() L139, watchConnection() L146, _checkHealth() L160, _setConnected() L185, _setDisconnected() L192, dispose() L199

## lib/data/services/llm/gemini_provider.dart (487 lines)
- L10  class GeminiConfig (model, apiKey) — GeminiConfig(…) L14
- L28  class GeminiProvider extends LlmProvider (_baseUrl, config, _keyStore, _dio, _healthTimer, _status, _toolCallTurns) — _models L30, _connectionCtrl L42, id L48, GeminiProvider(…) L54, _resolveApiKey() L69, availableModels() L79, parseCommand(AgentRequest request) L84, supportsToolCalling L161, chatWithTools(AgentTurnRequest request) L173, _toContents(AgentTurnRequest request) L233, _turnToContent(AgentTurnMessage turn) L252, _decodeResultPayload(String? content) L298, _parseTurnResponse(Map<String, dynamic>? data) L309, _buildResponseSchema(String schemaJson) L357, _cleanJsonResponse(String raw) L391, _isTransientError(DioException e) L404, _formatDioError(DioException e) L419, watchConnection() L439, _checkHealth() L449, dispose() L481

## lib/data/services/llm/llm_provider.dart (33 lines)
- L4  enum ConnectionStatus
- L6  class LlmProvider (id) — availableModels() L8, parseCommand(AgentRequest request) L9, watchConnection() L10, supportsToolCalling L17, suggestedRoundTimeoutSeconds L24, chatWithTools(AgentTurnRequest request) L29

## lib/data/services/llm/nvidia_nim_provider.dart (395 lines)
- L11  class NvidiaNimConfig (model, apiKey) — NvidiaNimConfig(…) L15
- L37  class NvidiaNimProvider extends OpenAiCompatibleLlmProvider (_baseUrl, config, _keyStore, _dio, _healthTimer, _status) — _models L48, _connectionCtrl L103, id L109, baseUrl L112, modelName L115, dio L118, usesMaxCompletionTokens L124, toolRequestExtras() L129, NvidiaNimProvider(…) L131, resolveApiKey() L153, supportsToolCalling L165, connectionErrorText() L168, availableModels() L178, _parseModelIds(Map<String, dynamic>? data) L198, parseCommand(AgentRequest request) L212, chatWithTools(AgentTurnRequest request) L286, _buildStructuredOutputSchema(String schemaJson) L289, _cleanJsonResponse(String raw) L328, _isTransientError(DioException e) L341, watchConnection() L357, _checkHealth() L367, dispose() L390

## lib/data/services/llm/ollama_provider.dart (247 lines)
- L10  class OllamaConfig (host, port, model, apiKey) — OllamaConfig(…) L16, baseUrl L23, compatBaseUrl L25
- L28  class OllamaProvider extends OpenAiCompatibleLlmProvider (config, _keyStore, _dio, _healthTimer, _status) — _connectionCtrl L32, id L38, baseUrl L41, modelName L44, dio L47, usesMaxCompletionTokens L53, OllamaProvider(…) L55, resolveApiKey() L75, supportsToolCalling L94, suggestedRoundTimeoutSeconds L98, connectionErrorText() L101, mapToolsModelError(Object? data) L105, availableModels() L115, parseCommand(AgentRequest request) L133, _cleanJsonResponse(String raw) L178, _jsonSchemaToOllamaFormat(String schemaJson) L191, watchConnection() L213, _checkHealth() L223, dispose() L242

## lib/data/services/llm/openai_compatible_provider.dart (291 lines)
- L40  class OpenAiCompatibleLlmProvider extends LlmProvider (baseUrl, modelName, dio) — chatCompletionsPath L58, resolveApiKey() L64, usesMaxCompletionTokens L69, toolRequestExtras() L74, authHeaders(String? apiKey) L83, connectionErrorText() L89, mapToolsModelError(Object? data) L94, supportsToolCalling L97, chatWithTools(AgentTurnRequest request) L106, _toWireMessages(AgentTurnRequest request) L160, _turnToWire(AgentTurnMessage turn) L176, _parseTurnResponse(Map<String, dynamic>? data) L208, _isTransientError(DioException e) L256, formatDioError(DioException e) L271

## lib/data/services/llm/openai_provider.dart (265 lines)
- L11  class OpenAiConfig (model, apiKey) — OpenAiConfig(…) L15
- L18  class OpenAiProvider extends OpenAiCompatibleLlmProvider (_base, config, _keyStore, _dio, _healthTimer, _status) — _models L20, _connectionCtrl L32, id L38, baseUrl L41, modelName L44, dio L47, OpenAiProvider(…) L49, resolveApiKey() L68, availableModels() L78, parseCommand(AgentRequest request) L83, chatWithTools(AgentTurnRequest request) L156, _buildStructuredOutputSchema(String schemaJson) L159, _cleanJsonResponse(String raw) L198, _isTransientError(DioException e) L211, watchConnection() L227, _checkHealth() L237, dispose() L260

## lib/data/services/llm/provider_registry.dart (262 lines)
- L13  class ActiveLlmConfig (providerId, endpoint, apiKey, model) — ActiveLlmConfig(…) L26
- L36  typedef ActiveProfileResolver
- L38  class ProviderRegistry (_providers, _keyStore, _settingsRepository, activeProfileResolver, _cachedActive) — ProviderRegistry(…) L46, register(LlmProvider provider) L53, get(String id) L58, all L60, providerIds L62, unregister(String id) L64, dispose() L69, initializeAll() L76, invalidateActive() L117, getActiveProvider() L130, _customCompatProviderIds L168, _providerFromConfig(ActiveLlmConfig config) L189, _customCompatProvider(ActiveLlmConfig config, String? model) L250

## lib/data/services/thumbnail_service.dart (49 lines)
- L4  class ThumbnailService (_ffprobeService, _cache) — ThumbnailService(this._ffprobeService) L8, generate(String videoPath,…) L10, delete(String thumbnailPath) L29, getCached(String videoPath) L43, clearCache() L45

## lib/data/services/transcription/whisper_service.dart (221 lines)
- L6  class WhisperPaths (binaryPath, modelPath) — WhisperPaths(…) L10
- L14  class TranscriptSegment (startMs, endMs, text) — TranscriptSegment(…) L19, toJson() L25, fromJson(Map<String, dynamic> json) L31
- L41  class WhisperTranscript (text, segments) — WhisperTranscript(…) L45, charCount L47, isEmpty L48
- L69  class WhisperTranscriptionService — Function(String exe, List<String> args) _run L71, WhisperTranscriptionService(…) L73, findBinary(…) L79, isAvailable(…) L90, transcribe(…) L98, parseTranscriptSegments(String stdout) L134, _toMs(String hh, String mm, String ss, String ms) L166, parseTranscriptText(String stdout) L175, isSafeConfiguredPath(String path) L191, _isAbsolute(String path) L197, _which(String binary) L205

## lib/data/services/updates/asset_verifier.dart (115 lines)
- L7  class AssetVerificationResult (reason, passed, expectedDigest, actualDigest) — AssetVerificationResult(…) L16
- L34  class ReleaseAssetVerifier (_chunkSize, _hexPattern) — ReleaseAssetVerifier() L38, verify(File file, String? digest) L40, _parseSha256Hex(String digest) L77, _hashFile(File file) L86
- L104  class _DigestCollector (digest) — add(Digest data) L108, close() L113

## lib/data/services/updates/github_release_checker.dart (122 lines)
- L6  class GithubReleaseChecker (_repo, _apiUrl, _userAgent, _cachedRelease) — checkForUpdate() L13, _parseTag(String tag) L92, isNewer(ReleaseInfo latest, String currentVersion) L105, clearCache() L118

## lib/data/services/updates/release_info.dart (24 lines)
- L1  class ReleaseInfo (tagName, major, minor, patch, releaseNotes, downloadUrl, assetType, publishedAt) — ReleaseInfo(…) L12

## lib/data/services/updates/update_downloader.dart (248 lines)
- L10  typedef UpdateProcessStarter
- L13  function _defaultProcessStarter
- L27  function psSingleQuoted
- L31  class UpdateVerificationException (message, result) — UpdateVerificationException(this.message,…) L35, toString() L38
- L41  class UpdateDownloader (downloadUrl, assetType, digest, verifier, processStarter, appDirOverride) — Function(double? progress, String status)? onProgress L45, Function(int code) exitApp L48, UpdateDownloader(…) L51, _appDir L64, downloadAndInstall() L67, _downloadFile(…) L105, _formatSize(int bytes) L154, _extractAndInstallZip(String zipPath, String tempPath) L160, _runInstaller(String exePath, String tempPath) L219
