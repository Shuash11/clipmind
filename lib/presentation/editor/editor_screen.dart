import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/preview_player.dart';
import 'widgets/timeline/timeline_view.dart';
import 'widgets/agent_chat/agent_chat_panel.dart';
import 'widgets/toolbar/left_tool_rail.dart';
import 'widgets/toolbar/top_action_bar.dart';
import 'widgets/status_bar.dart';

class EditorScreen extends ConsumerWidget {
  final String projectId;
  const EditorScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Column(
        children: [
          TopActionBar(),
          Expanded(
            child: Row(
              children: [
                LeftToolRail(),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(flex: 3, child: PreviewPlayer(),
                      ),
                      Expanded(flex: 1, child: TimelineView()),
                    ],
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: AgentChatPanel(),
                ),
              ],
            ),
          ),
          StatusBar(),
        ],
      ),
    );
  }
}
