import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/state/export_providers.dart';

class ExportDialog extends ConsumerStatefulWidget {
  final Project project;

  const ExportDialog({super.key, required this.project});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late ExportOptions _options;
  bool _isExporting = false;
  double _progress = 0.0;
  bool _done = false;
  StreamSubscription<double>? _progressSub;

  @override
  void initState() {
    super.initState();
    _options = ExportOptions.defaults().copyWith(
      outputPath:
          '${widget.project.name}_export.${ExportOptions.defaults().format}',
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _pickOutputPath() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Select export location',
      fileName: '${widget.project.name}_export.${_options.format}',
      type: FileType.custom,
      allowedExtensions: [_options.format],
    );
    if (result != null && mounted) {
      setState(() {
        _options = _options.copyWith(outputPath: result);
      });
    }
  }

  String _estimateFileSize() {
    final resolutionDims = ExportOptions.resolutionMap[_options.resolution] ?? (0, 0);
    final (width, height) = resolutionDims;
    final pixels = width * height;
    final bitrate = switch (_options.quality) {
      'ultra' => 20,
      'high' => 10,
      'medium' => 5,
      'low' => 2,
      _ => 10,
    };
    final durationSec = widget.project.durationMs ~/ 1000;
    if (durationSec <= 0 || pixels <= 0) return '~10 MB';
    final sizeMb = (pixels * bitrate * durationSec) ~/ 800000;
    return '~${sizeMb.clamp(1, 99999)} MB';
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _progress = 0.0;
      _done = false;
    });

    ref.read(isExportingProvider.notifier).state = true;

    final useCase = ref.read(exportUseCaseProvider);
    _progressSub = useCase.progressStream.listen(
      (progress) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _isExporting = false;
            _done = false;
          });
        }
      },
    );

    final result = await useCase.execute(
      widget.project,
      options: _options,
    );

    _progressSub?.cancel();

    ref.read(isExportingProvider.notifier).state = false;
    ref.read(lastExportResultProvider.notifier).state = result;

    if (mounted) {
      setState(() {
        _isExporting = false;
        _done = result.success;
        _progress = result.success ? 1.0 : 0.0;
      });
    }
  }

  void _cancelExport() {
    ref.read(exportUseCaseProvider).cancel();
    _progressSub?.cancel();
    if (mounted) {
      setState(() {
        _isExporting = false;
      });
    }
    ref.read(isExportingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: ClipMindColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ClipMindColors.borderColor),
      ),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export Project', style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              if (!_isExporting && !_done) ..._buildOptions(theme),
              if (_isExporting) ..._buildProgress(theme),
              if (_done) ..._buildDone(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptions(ThemeData theme) {
    return [
      _buildDropdown(
        theme,
        label: 'Format',
        value: _options.format,
        items: ExportOptions.formats,
        icon: Icons.videocam_outlined,
        onChanged: (v) {
          setState(() {
            _options = _options.copyWith(format: v);
          });
        },
      ),
      const SizedBox(height: 14),
      _buildDropdown(
        theme,
        label: 'Resolution',
        value: _options.resolution,
        items: ExportOptions.resolutions,
        icon: Icons.aspect_ratio_outlined,
        onChanged: (v) {
          setState(() {
            _options = _options.copyWith(resolution: v);
          });
        },
      ),
      const SizedBox(height: 14),
      _buildQualitySelector(theme),
      const SizedBox(height: 14),
      _buildOutputPath(theme),
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.storage_outlined,
              size: 14, color: ClipMindColors.textMuted),
          const SizedBox(width: 6),
          Text('Estimated size: ${_estimateFileSize()}',
              style: theme.textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _startExport,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Export'),
          style: FilledButton.styleFrom(
            backgroundColor: ClipMindColors.accentPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildProgress(ThemeData theme) {
    return [
      Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ClipMindColors.accentPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Exporting... ${(_progress * 100).toInt()}%',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 8,
          backgroundColor: ClipMindColors.bgElevated,
          valueColor: const AlwaysStoppedAnimation(
            ClipMindColors.accentPrimary,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${(_progress * 100).toInt()}%',
        style: theme.textTheme.bodySmall?.copyWith(
          color: ClipMindColors.textSecondary,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelExport,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ClipMindColors.statusError,
            side: BorderSide(color: ClipMindColors.statusError.withAlpha(80)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildDone(ThemeData theme) {
    return [
      Row(
        children: [
          Icon(Icons.check_circle,
              color: ClipMindColors.statusReady, size: 20),
          const SizedBox(width: 8),
          Text('Export Complete', style: theme.textTheme.titleMedium),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'File saved to:\n${_options.outputPath}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: ClipMindColors.textSecondary,
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Done'),
          style: FilledButton.styleFrom(
            backgroundColor: ClipMindColors.accentPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    ];
  }

  Widget _buildDropdown(
    ThemeData theme, {
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ClipMindColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ClipMindColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ClipMindColors.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: ClipMindColors.bgElevated,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13),
                items: items.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(v.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySelector(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.tune, size: 16, color: ClipMindColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text('Quality', style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: SegmentedButton<String>(
            segments: ExportOptions.qualities.map((q) {
              return ButtonSegment(
                value: q,
                label: Text(
                  q[0].toUpperCase() + q.substring(1),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
            selected: {_options.quality},
            onSelectionChanged: (v) {
              final quality = v.first;
              setState(() {
                _options = _options.copyWith(
                  quality: quality,
                  crf: ExportOptions.crfForQuality(quality),
                );
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return ClipMindColors.accentPrimary.withAlpha(40);
                }
                return ClipMindColors.bgElevated;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return ClipMindColors.accentPrimary;
                }
                return ClipMindColors.textSecondary;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(color: ClipMindColors.accentPrimary);
                }
                return BorderSide(color: ClipMindColors.borderColor);
              }),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputPath(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.folder_outlined,
            size: 16, color: ClipMindColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text('Output', style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _pickOutputPath,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ClipMindColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ClipMindColors.borderColor),
              ),
              child: Text(
                _options.outputPath.isNotEmpty
                    ? _options.outputPath.split('\\').last
                        .split('/').last
                    : 'Select path...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _options.outputPath.isNotEmpty
                      ? ClipMindColors.textPrimary
                      : ClipMindColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
