import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

/// The tab-top selection banner for the CapCut-style panels: shown when a
/// tab's action needs a selected timeline clip but none is selected (or
/// no project is open). One shared widget keeps the three tabs consistent.
final class PanelNotice extends StatelessWidget {
  final String message;

  const PanelNotice({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClipMindColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ClipMindColors.statusWarning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
