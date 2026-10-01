import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/services/ffmpeg/procedural_sound_service.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'panel_notice.dart';

/// The Audio tab: "Add sound from file" (the file_picker path) plus the 6
/// procedural presets (Beep, Drone-low, Drone-mid, Hum, Static-noise,
/// Alert-chime) and a volume slider — applied through
/// `manualEditControllerProvider` as an undoable, journaled layer. The
/// controller auto-detects preset ids vs file paths; both need a selected
/// clip.
class AudioTab extends ConsumerStatefulWidget {
  const AudioTab({super.key});

  @override
  ConsumerState<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends ConsumerState<AudioTab> {
  /// Material icon name → IconData for the 6 procedural presets.
  static const _presetIcons = <String, IconData>{
    'beep': Icons.volume_up,
    'drone-low': Icons.waves,
    'drone-mid': Icons.equalizer,
    'hum': Icons.hearing,
    'static-noise': Icons.grain,
    'alert-chime': Icons.notifications_active,
  };

  double _volume = 1.0;
  bool _isPicking = false;

  /// The in-flight submit's preset id; null = idle. Blocks a second
  /// submit until the first finishes (the busy-guard pattern).
  String? _busyPresetId;

  Future<void> _pickSound() async {
    if (_isPicking) return;
    final clipId = ref.read(selectedClipIdProvider);
    if (clipId == null) {
      _showMessage('Select a clip first.');
      return;
    }
    setState(() => _isPicking = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (picked == null || picked.files.isEmpty) return; // user cancelled
      final path = picked.files.first.path;
      if (path == null || path.isEmpty) {
        if (!mounted) return;
        _showMessage('Could not read the selected file path.');
        return;
      }
      final result = await ref
          .read(manualEditControllerProvider)
          .submitSound(clipId: clipId, soundSource: path, volume: _volume);
      if (!mounted) return;
      _showMessage(result.message);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _applyPreset(ProceduralSoundPreset preset) async {
    if (_busyPresetId != null) return;
    final clipId = ref.read(selectedClipIdProvider);
    if (clipId == null) {
      _showMessage('Select a clip first.');
      return;
    }
    setState(() => _busyPresetId = preset.id);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitSound(
            clipId: clipId,
            soundSource: preset.id,
            volume: _volume,
          );
      if (!mounted) return;
      _showMessage(result.message);
    } finally {
      if (mounted) setState(() => _busyPresetId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider).value;
    final selectedClip =
        resolveSelectedClip(project, ref.watch(selectedClipIdProvider));
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
          OutlinedButton.icon(
            onPressed: _isPicking ? null : _pickSound,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Add sound from file'),
          ),
          const SizedBox(height: 16),
          Text('Built-in sounds', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
            padding: EdgeInsets.zero,
            children: [
              for (final preset in ProceduralSoundService.presets)
                _SoundCard(
                  preset: preset,
                  icon: _presetIcons[preset.id] ?? Icons.graphic_eq_rounded,
                  busy: _busyPresetId == preset.id,
                  enabled: _busyPresetId == null,
                  onApply: () => _applyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Volume', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 2,
                    divisions: 20,
                    onChanged: (value) => setState(() => _volume = value),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_volume.toStringAsFixed(1)}×',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _SoundCard extends StatelessWidget {
  final ProceduralSoundPreset preset;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onApply;

  const _SoundCard({
    required this.preset,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${preset.label} — ${_durationLabel(preset.durationSeconds)}',
      child: Opacity(
        opacity: enabled || busy ? 1.0 : 0.55,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onApply : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ClipMindColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClipMindColors.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          icon,
                          size: 18,
                          color: ClipMindColors.accentPrimary,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preset.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _durationLabel(double seconds) => seconds == seconds.roundToDouble()
      ? '${seconds.round()}s'
      : '${seconds.toStringAsFixed(1)}s';
}
