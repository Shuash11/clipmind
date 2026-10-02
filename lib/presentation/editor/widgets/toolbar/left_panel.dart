import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/tagging/presentation/widgets/media_panel.dart';
import 'package:clipmind/presentation/editor/providers/left_panel_provider.dart';
import 'panels/adjustments_tab.dart';
import 'panels/audio_tab.dart';
import 'panels/effects_tab.dart';
import 'panels/text_tab.dart';
import 'panels/transitions_tab.dart';

/// The CapCut-style collapsible left panel (~300px): Media | Effects |
/// Transitions | Text | Audio | Adjustments tabs hosted next to the
/// tool rail. The open/tab state
/// lives in [leftPanelProvider] so the rail, the editor layout and the
/// panel stay in sync; the editor row includes the panel only while open,
/// so the workspace shrinks accordingly and the last tab is remembered
/// for the next open.
class LeftPanel extends ConsumerStatefulWidget {
  const LeftPanel({super.key});

  @override
  ConsumerState<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends ConsumerState<LeftPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: LeftPanelTab.values.length,
      vsync: this,
      initialIndex: ref.read(leftPanelProvider).tab.index,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// User tab taps flow back into the provider (the single source of
  /// truth); identical states are skipped by the controller.
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = LeftPanelTab.values[_tabController.index];
    if (ref.read(leftPanelProvider).tab != tab) {
      ref.read(leftPanelProvider.notifier).open(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rail-driven tab changes animate the tabs from outside the panel;
    // post-frame keeps the controller mutation out of the build phase.
    ref.listen<LeftPanelState>(leftPanelProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tabController.index != next.tab.index &&
            !_tabController.indexIsChanging) {
          _tabController.animateTo(next.tab.index);
        }
      });
    });
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border.all(color: ClipMindColors.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    labelColor: ClipMindColors.accentPrimary,
                    unselectedLabelColor: ClipMindColors.textSecondary,
                    indicatorColor: ClipMindColors.accentPrimary,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    labelStyle: Theme.of(context).textTheme.titleMedium,
                    unselectedLabelStyle:
                        Theme.of(context).textTheme.titleMedium,
                    tabs: const [
                      Tab(text: 'Media'),
                      Tab(text: 'Effects'),
                      Tab(text: 'Transitions'),
                      Tab(text: 'Text'),
                      Tab(text: 'Audio'),
                      Tab(text: 'Adjustments'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_left, size: 20),
                  tooltip: 'Collapse panel',
                  onPressed: () =>
                      ref.read(leftPanelProvider.notifier).close(),
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                MediaPanel(),
                EffectsTab(),
                TransitionsTab(),
                TextTab(),
                AudioTab(),
                AdjustmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
