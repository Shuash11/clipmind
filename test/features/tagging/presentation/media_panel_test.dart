import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/media_asset.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/entities/tag_definition.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/features/tagging/presentation/widgets/asset_tag_chips.dart';
import 'package:clipmind/features/tagging/presentation/widgets/media_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tagging_widget_harness.dart';

void main() {
  testWidgets(
    'searches canonical display names without exposing source paths',
    (tester) async {
      final harness = TaggingWidgetHarness(document: _mediaDocument());
      await tester.pumpWidget(
        taggingTestApp(harness: harness, child: const MediaPanel()),
      );

      expect(find.bySemanticsLabel('Search media'), findsOneWidget);
      expect(find.text('Vacation one.mp4'), findsOneWidget);
      expect(find.text('work-reel.mp4'), findsOneWidget);
      expect(find.text(r'C:\private\vacation-one.mp4'), findsNothing);

      await tester.enterText(find.bySemanticsLabel('Search media'), 'VACATION');
      await tester.pump();

      expect(find.text('Vacation one.mp4'), findsOneWidget);
      expect(find.text('work-reel.mp4'), findsNothing);
    },
  );

  testWidgets('filters by every selected tag and exposes selectable media', (
    tester,
  ) async {
    final harness = TaggingWidgetHarness(document: _mediaDocument());
    await tester.pumpWidget(
      taggingTestApp(harness: harness, child: const MediaPanel()),
    );

    await tester.tap(find.bySemanticsLabel('Filter by tag Travel'));
    await tester.tap(find.bySemanticsLabel('Filter by tag Work'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaPanel)),
    );
    expect(container.read(tagQueryProvider).selectedTagIds, {
      'tag-travel',
      'tag-work',
    });
    expect(find.text('Vacation one.mp4'), findsNothing);
    expect(find.text('work-reel.mp4'), findsNothing);
    expect(find.text('Travel work.mp4'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Select asset asset-both'));
    await tester.pump();
    expect(find.bySemanticsLabel('Selected asset asset-both'), findsOneWidget);
  });

  testWidgets('reports truthful unavailable and empty states', (tester) async {
    await tester.pumpWidget(taggingTestApp(child: const MediaPanel()));
    expect(find.text('No project available'), findsOneWidget);

    final empty = TaggingWidgetHarness(
      document: _mediaDocument().copyWith(
        currentState: _mediaDocument().currentState.copyWith(assets: const []),
      ),
    );
    await tester.pumpWidget(
      taggingTestApp(harness: empty, child: const MediaPanel()),
    );
    expect(find.text('No media assets'), findsOneWidget);
  });

  testWidgets('removes an asset tag through exactly one manual transaction', (
    tester,
  ) async {
    final harness = TaggingWidgetHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: harness,
        child: const AssetTagChips(assetId: 'asset-1'),
      ),
    );

    await tester.tap(
      find.bySemanticsLabel('Remove tag Travel from asset asset-1'),
    );
    await tester.pumpAndSettle();

    expect(harness.repository.saveCalls, 1);
    expect(harness.publisher.publishCalls, 1);
    final record = harness.document.history.single;
    expect(record.sourceKind, TransactionSourceKind.manual);
    expect(record.commands.single.type, 'unassign_tag');
  });
}

ProjectDocument _mediaDocument() {
  final harness = TaggingWidgetHarness();
  return harness.document.copyWith(
    currentState: ProjectStateSnapshot(
      assets: [
        MediaAsset(
          id: 'asset-travel',
          sourcePath: r'C:\private\vacation-one.mp4',
          displayName: 'Vacation one.mp4',
          durationMs: 1000,
          tagIds: {'tag-travel'},
        ),
        MediaAsset(
          id: 'asset-work',
          sourcePath: r'C:\private\work-reel.mp4',
          displayName: 'work-reel.mp4',
          durationMs: 1000,
          tagIds: {'tag-work'},
        ),
        MediaAsset(
          id: 'asset-both',
          sourcePath: r'C:\private\travel-work.mp4',
          displayName: 'Travel work.mp4',
          durationMs: 1000,
          tagIds: {'tag-travel', 'tag-work'},
        ),
      ],
      tracks: harness.document.currentState.tracks,
      tags: const [
        TagDefinition(id: 'tag-travel', name: 'Travel', color: '#1299AA'),
        TagDefinition(id: 'tag-work', name: 'Work', color: '#AA5511'),
      ],
      markers: const [],
      overlays: const [],
    ),
  );
}
