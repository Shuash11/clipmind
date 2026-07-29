import 'dart:async';

import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';
import 'package:clipmind/features/tagging/domain/marker_layout.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/features/tagging/presentation/widgets/marker_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class MarkerRuler extends ConsumerStatefulWidget {
  const MarkerRuler({
    required this.durationMs,
    required this.width,
    this.document,
    super.key,
  });

  final int durationMs;
  final double width;
  final ProjectDocument? document;

  @override
  ConsumerState<MarkerRuler> createState() => _MarkerRulerState();
}

final class _MarkerRulerState extends ConsumerState<MarkerRuler> {
  final Map<String, FocusNode> _focusNodes = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNodeFor(String markerId) => _focusNodes.putIfAbsent(
    markerId,
    () => FocusNode(debugLabel: 'marker-$markerId'),
  );

  Future<void> _update(
    TimelineMarker marker,
    MarkerEditorFormValue value,
  ) async {
    if (_busy || !_isValid(value)) return;
    final providers = ref.read(taggingProvidersProvider);
    if (providers == null) return;
    setState(() => _busy = true);
    await providers.applyManual(
      providers.controller.updateMarker(
        markerId: marker.id,
        label: value.label,
        color: value.color,
        atMs: value.atMs,
        startMs: value.startMs,
        endMs: value.endMs,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete(TimelineMarker marker) async {
    if (_busy) return;
    final providers = ref.read(taggingProvidersProvider);
    if (providers == null) return;
    setState(() => _busy = true);
    await providers.applyManual(
      providers.controller.deleteMarker(markerId: marker.id),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(TimelineMarker marker) async {
    if (_busy || !mounted) return;
    final result = await showDialog<MarkerEditorFormValue>(
      context: context,
      builder: (_) => MarkerEditorDialog(initialValue: _formFor(marker)),
    );
    if (result != null) await _update(marker, result);
  }

  KeyEventResult _onKeyEvent(TimelineMarker marker, KeyEvent event) {
    if (event is! KeyDownEvent || _busy) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      unawaited(_edit(marker));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      unawaited(_delete(marker));
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }

    final next = _keyboardForm(
      marker,
      movesRight: key == LogicalKeyboardKey.arrowRight,
      resizing: HardwareKeyboard.instance.isShiftPressed,
    );
    if (next == null) return KeyEventResult.handled;
    unawaited(_update(marker, next));
    return KeyEventResult.handled;
  }

  MarkerEditorFormValue? _keyboardForm(
    TimelineMarker marker, {
    required bool movesRight,
    required bool resizing,
  }) {
    final delta = movesRight ? 100 : -100;
    if (_isPoint(marker)) {
      if (resizing) return null;
      final next = (marker.atMs! + delta).clamp(0, widget.durationMs);
      if (next == marker.atMs) return null;
      return MarkerEditorFormValue(
        label: marker.label,
        color: marker.color,
        atMs: next,
      );
    }
    if (!_isRange(marker)) return null;
    final start = marker.startMs!;
    final end = marker.endMs!;
    if (resizing) {
      final nextEnd = movesRight
          ? (end + 100).clamp(start + 1, widget.durationMs)
          : end - 100;
      if (nextEnd <= start || nextEnd == end) return null;
      return MarkerEditorFormValue(
        label: marker.label,
        color: marker.color,
        startMs: start,
        endMs: nextEnd,
      );
    }

    final span = end - start;
    if (span > widget.durationMs) return null;
    var nextStart = start + delta;
    if (nextStart < 0) nextStart = 0;
    if (nextStart + span > widget.durationMs) {
      nextStart = widget.durationMs - span;
    }
    if (nextStart == start) return null;
    return MarkerEditorFormValue(
      label: marker.label,
      color: marker.color,
      startMs: nextStart,
      endMs: nextStart + span,
    );
  }

  bool _isValid(MarkerEditorFormValue value) {
    if (value.label.trim().isEmpty ||
        value.label.trim().length > 120 ||
        value.label.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f) ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.color)) {
      return false;
    }
    final isPoint =
        value.atMs != null &&
        value.atMs! >= 0 &&
        value.startMs == null &&
        value.endMs == null;
    final isRange =
        value.atMs == null &&
        value.startMs != null &&
        value.endMs != null &&
        value.startMs! >= 0 &&
        value.endMs! > value.startMs!;
    return isPoint || isRange;
  }

  MarkerEditorFormValue _formFor(TimelineMarker marker) =>
      MarkerEditorFormValue(
        label: marker.label,
        color: marker.color,
        atMs: marker.atMs,
        startMs: marker.startMs,
        endMs: marker.endMs,
      );

  @override
  Widget build(BuildContext context) {
    final document =
        widget.document ?? ref.watch(taggingProvidersProvider)?.document;
    if (document == null || widget.durationMs <= 0 || widget.width <= 0) {
      return const SizedBox(height: 44);
    }
    final markers = ref
        .watch(markerFilterProvider)
        .filter(document.currentState.markers);
    final layout = MarkerLayout.layout(
      markers: markers,
      durationMs: widget.durationMs,
      width: widget.width,
    );
    final markersById = {for (final marker in markers) marker.id: marker};

    return SizedBox(
      width: widget.width,
      height: 44,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final entry in layout)
            if (markersById[entry.markerId] case final TimelineMarker marker)
              Positioned(
                left: entry.leftPx,
                top: 0,
                child: SizedBox(
                  key: ValueKey('marker-ruler-marker-${marker.id}'),
                  width: entry.widthPx,
                  height: 44,
                  child: Focus(
                    focusNode: _focusNodeFor(marker.id),
                    onKeyEvent: (_, event) => _onKeyEvent(marker, event),
                    child: Semantics(
                      label: _semanticLabel(marker),
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _focusNodeFor(marker.id).requestFocus(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _colorFor(marker.color),
                            border: Border.all(
                              color: ClipMindColors.accentPrimary,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _semanticLabel(TimelineMarker marker) => _isPoint(marker)
      ? 'Marker ${marker.label} at ${marker.atMs} ms, color ${marker.color}'
      : 'Marker ${marker.label} from ${marker.startMs} ms to ${marker.endMs} ms, color ${marker.color}';

  bool _isPoint(TimelineMarker marker) =>
      marker.atMs != null &&
      marker.atMs! >= 0 &&
      marker.startMs == null &&
      marker.endMs == null;

  bool _isRange(TimelineMarker marker) =>
      marker.atMs == null &&
      marker.startMs != null &&
      marker.endMs != null &&
      marker.startMs! >= 0 &&
      marker.endMs! > marker.startMs!;

  Color _colorFor(String value) {
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return ClipMindColors.statusError;
    }
    return Color(0xff000000 | int.parse(value.substring(1), radix: 16));
  }
}
