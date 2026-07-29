import 'package:clipmind/features/tagging/domain/marker_filter.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class MarkerFilterMenu extends ConsumerWidget {
  const MarkerFilterMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(markerFilterProvider);
    final document = ref.watch(taggingProvidersProvider)?.document;
    final colors = document == null
        ? <String>[]
        : (document.currentState.markers
              .map((marker) => marker.color)
              .toSet()
              .toList()
            ..sort());

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _FilterToggle(
          label: 'Show point markers',
          selected: filter.includePoints,
          onSelected: (selected) => _setFilter(
            ref,
            MarkerFilter(
              selectedColors: filter.selectedColors,
              includePoints: selected,
              includeRanges: filter.includeRanges,
            ),
          ),
        ),
        _FilterToggle(
          label: 'Show range markers',
          selected: filter.includeRanges,
          onSelected: (selected) => _setFilter(
            ref,
            MarkerFilter(
              selectedColors: filter.selectedColors,
              includePoints: filter.includePoints,
              includeRanges: selected,
            ),
          ),
        ),
        for (final color in colors)
          _FilterToggle(
            label: 'Filter markers by color $color',
            selected: filter.selectedColors.contains(color),
            onSelected: (selected) {
              final next = {...filter.selectedColors};
              if (selected) {
                next.add(color);
              } else {
                next.remove(color);
              }
              _setFilter(
                ref,
                MarkerFilter(
                  selectedColors: next,
                  includePoints: filter.includePoints,
                  includeRanges: filter.includeRanges,
                ),
              );
            },
          ),
      ],
    );
  }

  void _setFilter(WidgetRef ref, MarkerFilter value) {
    ref.read(markerFilterProvider.notifier).state = value;
  }
}

final class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    toggled: selected,
    child: ExcludeSemantics(
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
      ),
    ),
  );
}
