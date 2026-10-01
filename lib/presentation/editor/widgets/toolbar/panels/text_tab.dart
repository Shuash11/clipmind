import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/services/fonts/font_resolver.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'panel_notice.dart';

/// The Text tab: a text input, the font picker (the 6 bundled OFL fonts,
/// loaded once via `FontLoader` so each name renders in its own typeface)
/// and the quick style presets — applied through
/// `manualEditControllerProvider` as an undoable, journaled overlay.
class TextTab extends ConsumerStatefulWidget {
  const TextTab({super.key});

  @override
  ConsumerState<TextTab> createState() => _TextTabState();
}

class _TextTabState extends ConsumerState<TextTab> {
  final TextEditingController _textController = TextEditingController();

  /// Quick style presets (the verified `overlay_text` positions:
  /// center, top-right, bottom-left, bottom-right).
  static const _stylePresets = <_TextStylePreset>[
    _TextStylePreset(label: 'Title', position: 'center', fontSize: 72),
    _TextStylePreset(label: 'Subtitle', position: 'bottom-left', fontSize: 48),
    _TextStylePreset(label: 'Caption', position: 'bottom-right', fontSize: 32),
  ];

  /// Families already registered with the engine (static so a panel
  /// remount doesn't re-load the same family).
  static final Set<String> _engineLoaded = <String>{};

  final Set<String> _loadedFonts = <String>{};
  final Set<String> _unavailableFonts = <String>{};
  bool _fontsLoading = true;
  String? _selectedFont; // family label; null = system default
  int _selectedPresetIndex = 0;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFonts);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Resolve each bundled family once through `fontResolverProvider`,
  /// then register the `.ttf` bytes with the engine under its display
  /// label so `TextStyle(fontFamily: label)` renders in that typeface.
  /// Missing assets degrade to the unavailable state (the resolver's
  /// graceful-null behavior); IO failures never surface.
  Future<void> _loadFonts() async {
    final resolver = ref.read(fontResolverProvider);
    for (final font in FontResolver.catalog) {
      if (!mounted) return;
      if (_engineLoaded.contains(font.label)) {
        setState(() => _loadedFonts.add(font.label));
        continue;
      }
      final path = await resolver.resolve(font.id);
      if (!mounted) return;
      if (path == null) {
        setState(() => _unavailableFonts.add(font.label));
        continue;
      }
      try {
        final bytes = await File(path).readAsBytes();
        final loader = FontLoader(font.label)
          ..addFont(
            Future.value(
              bytes.buffer
                  .asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
            ),
          );
        await loader.load();
        _engineLoaded.add(font.label);
        if (!mounted) return;
        setState(() => _loadedFonts.add(font.label));
      } catch (_) {
        if (!mounted) return;
        setState(() => _unavailableFonts.add(font.label));
      }
    }
    if (mounted) setState(() => _fontsLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider).value;
    final selectedClip =
        resolveSelectedClip(project, ref.watch(selectedClipIdProvider));
    final preset = _stylePresets[_selectedPresetIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectedClip == null)
            PanelNotice(
              message: project == null
                  ? 'Open a project first.'
                  : 'Select a clip first.',
            )
          else
            Text(
              'Selected clip: ${clipDisplayLabel(selectedClip)}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Text',
              hintText: 'Overlay text',
              isDense: true,
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text('Font', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _FontTile(
            label: 'System default',
            fontFamily: null,
            available: true,
            pending: false,
            selected: _selectedFont == null,
            onSelect: () => setState(() => _selectedFont = null),
          ),
          const SizedBox(height: 4),
          for (final font in FontResolver.catalog) ...[
            _FontTile(
              label: font.label,
              fontFamily: _loadedFonts.contains(font.label)
                  ? font.label
                  : null,
              available: _loadedFonts.contains(font.label),
              pending: _fontsLoading && !_loadedFonts.contains(font.label),
              selected: _selectedFont == font.label,
              onSelect: _loadedFonts.contains(font.label)
                  ? () => setState(() => _selectedFont = font.label)
                  : null,
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 16),
          Text('Style', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _stylePresets.length; index++)
                ChoiceChip(
                  label: Text(_stylePresets[index].label),
                  selected: _selectedPresetIndex == index,
                  onSelected: (_) => setState(() => _selectedPresetIndex = index),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${preset.position} · ${preset.fontSize}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isApplying ? null : _apply,
            icon: _isApplying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.text_fields_rounded, size: 16),
            label: const Text('Apply text'),
          ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    if (_isApplying) return;
    final text = _textController.text;
    if (text.trim().isEmpty) {
      _showMessage('Enter some text first.');
      return;
    }
    final clipId = ref.read(selectedClipIdProvider);
    if (clipId == null) {
      _showMessage('Select a clip first.');
      return;
    }
    final preset = _stylePresets[_selectedPresetIndex];
    setState(() => _isApplying = true);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitOverlayText(
            clipId: clipId,
            text: text,
            fontFamily: _selectedFont,
            position: preset.position,
            fontSize: preset.fontSize,
          );
      if (!mounted) return;
      _showMessage(result.message);
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _TextStylePreset {
  final String label;
  final String position;
  final int fontSize;

  const _TextStylePreset({
    required this.label,
    required this.position,
    required this.fontSize,
  });
}

class _FontTile extends StatelessWidget {
  final String label;
  final String? fontFamily;
  final bool available;
  final bool pending;
  final bool selected;
  final VoidCallback? onSelect;

  const _FontTile({
    required this.label,
    required this.fontFamily,
    required this.available,
    required this.pending,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: available || pending ? 1.0 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: available ? onSelect : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ClipMindColors.accentSoft
                : ClipMindColors.bgElevated,
            border: Border.all(
              color: selected
                  ? ClipMindColors.accentPrimary
                  : ClipMindColors.borderColor,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    color: available
                        ? ClipMindColors.textPrimary
                        : ClipMindColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!available && !pending)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Unavailable',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: ClipMindColors.accentPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
