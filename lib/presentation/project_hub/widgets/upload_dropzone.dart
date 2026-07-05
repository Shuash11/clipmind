import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class UploadDropzone extends StatelessWidget {
  final VoidCallback? onBrowse;
  final void Function(DropEventDetails)? onDragEntered;
  final void Function(DropEventDetails)? onDragExited;
  final void Function(DropDoneDetails)? onDragDone;
  final bool isDragActive;

  const UploadDropzone({
    super.key,
    this.onBrowse,
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
    this.isDragActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      onDragEntered: onDragEntered ?? (_) {},
      onDragExited: onDragExited ?? (_) {},
      onDragDone: onDragDone ?? (_) {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: ClipMindColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDragActive ? ClipMindColors.accentPrimary : ClipMindColors.borderColor,
            width: isDragActive ? 2.0 : 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: AnimatedOpacity(
          opacity: isDragActive ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ClipMindColors.accentPrimary.withValues(alpha: isDragActive ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: ClipMindColors.accentPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Drag and drop your video here',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'or ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: onBrowse,
                    child: const Text('Browse files'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'MP4, MOV, AVI, WEBM, MKV',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
