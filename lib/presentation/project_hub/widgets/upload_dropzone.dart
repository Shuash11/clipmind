import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class UploadDropzone extends StatefulWidget {
  final VoidCallback? onBrowse;
  final void Function(DropEventDetails)? onDragEntered;
  final void Function(DropEventDetails)? onDragExited;
  final void Function(DropDoneDetails)? onDragDone;
  final bool isDragActive;
  final bool isBusy;

  const UploadDropzone({
    super.key,
    this.onBrowse,
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
    this.isDragActive = false,
    this.isBusy = false,
  });

  @override
  State<UploadDropzone> createState() => _UploadDropzoneState();
}

class _UploadDropzoneState extends State<UploadDropzone> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.isDragActive || _isHovering;
    final borderColor = widget.isDragActive
        ? ClipMindColors.accentPrimary
        : isActive
        ? ClipMindColors.textMuted
        : ClipMindColors.borderColor;

    return DropTarget(
      onDragEntered: widget.onDragEntered,
      onDragExited: widget.onDragExited,
      onDragDone: widget.onDragDone,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedScale(
          scale: widget.isDragActive ? 1.01 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
            decoration: BoxDecoration(
              color: isActive
                  ? ClipMindColors.surfaceHover
                  : ClipMindColors.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: widget.isDragActive ? 2 : 1,
              ),
              boxShadow: [
                if (widget.isDragActive)
                  BoxShadow(
                    color: ClipMindColors.accentPrimary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ClipMindColors.accentPrimary.withValues(
                      alpha: isActive ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ClipMindColors.accentPrimary.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  child: widget.isBusy
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: ClipMindColors.accentPrimary,
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.isBusy ? 'Preparing media' : 'Drop video here',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isBusy
                      ? 'Reading metadata and creating a project.'
                      : 'Use a local file or browse from your desktop.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: widget.isBusy ? null : widget.onBrowse,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Browse files'),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _FormatChip(label: 'MP4'),
                    _FormatChip(label: 'MOV'),
                    _FormatChip(label: 'WEBM'),
                    _FormatChip(label: 'MKV'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;

  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ClipMindColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
