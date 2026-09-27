import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/presentation/shared_widgets/dashed_border.dart';

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
        cursor: widget.isBusy
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.isBusy ? null : widget.onBrowse,
          child: AnimatedScale(
            scale: widget.isDragActive ? 1.01 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? ClipMindColors.surfaceHover
                        : ClipMindColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (widget.isDragActive)
                        BoxShadow(
                          color: ClipMindColors.accentPrimary.withValues(
                            alpha: 0.18,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isBusy) ...[
                        const _BusyPill(),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: ClipMindColors.accentPrimary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Drag and drop your video here',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'or click to browse your files',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'MP4 · MOV · AVI · WEBM · MKV',
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: DashedRRectPainter(
                        color: borderColor,
                        strokeWidth: widget.isDragActive ? 2 : 1.5,
                        radius: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Busy pill: small spinner + status copy shown while media is prepared.
class _BusyPill extends StatelessWidget {
  const _BusyPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ClipMindColors.bgElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Text(
            'Checking your storage…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ClipMindColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
