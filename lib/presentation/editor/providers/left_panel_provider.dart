import 'package:flutter_riverpod/legacy.dart';

/// The tabs of the CapCut-style left panel, in display order.
enum LeftPanelTab { media, effects, text, audio }

/// Open/tab state of the left panel. The single source of truth shared by
/// the tool rail (opens/toggles), the editor layout (includes the panel
/// only while open) and the panel itself (tab sync).
class LeftPanelState {
  final bool open;
  final LeftPanelTab tab;

  const LeftPanelState({required this.open, this.tab = LeftPanelTab.media});

  const LeftPanelState.closed() : this(open: false);

  @override
  bool operator ==(Object other) =>
      other is LeftPanelState && other.open == open && other.tab == tab;

  @override
  int get hashCode => Object.hash(open, tab);
}

/// Controller for the left panel's open/tab state (the
/// `ManualEditController` naming pattern): the rail and the panel call the
/// intent methods instead of assigning raw state.
class LeftPanelController extends StateNotifier<LeftPanelState> {
  LeftPanelController() : super(const LeftPanelState.closed());

  /// Open the panel on [tab] (or switch tabs while open); also the way a
  /// tab tap inside the panel flows back into the state.
  void open(LeftPanelTab tab) =>
      state = LeftPanelState(open: true, tab: tab);

  /// Collapse the panel (the last tab is remembered for the next open).
  void close() => state = LeftPanelState(open: false, tab: state.tab);

  /// CapCut behavior: clicking the active tool again collapses the panel;
  /// otherwise it opens on that tab.
  void toggle(LeftPanelTab tab) {
    if (state.open && state.tab == tab) {
      close();
    } else {
      open(tab);
    }
  }
}

final leftPanelProvider =
    StateNotifierProvider<LeftPanelController, LeftPanelState>((ref) {
  return LeftPanelController();
});
