import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/clip_block.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/track_row.dart';
import 'package:clipmind/presentation/editor/widgets/workspace_split.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import '../features/tagging/support/tagging_widget_harness.dart';

/// Cycle 15 Phase A: the editor workspace layout size matrix.
///
/// Pumps the extracted [WorkspaceSplit] with the real [TimelineView] (never
/// [PreviewPlayer] — media_kit has no host native libs) at the app's default
/// and common window sizes and locks the timeline geometry:
///
/// - the split policy holds the ~40% timeline share (288/360/432px at
///   720/900/1080) with the preview floor intact;
/// - with the ruler present (TaggingWidgetHarness, the real reserved
///   behavior) the tracks region scrolls vertically at 1280x720 and
///   640x400, with fixed 48px rows and the Video row at the top;
/// - 1400x900 and 1920x1080 keep the even fit distribution at 63.25/81.25px
///   rows;
/// - ClipBlock always renders its full 38px block (48px box with padding);
/// - selection and trim-handle drags still work at 1280x720;
/// - no size raises an exception.
///
/// TimelineView's internal reservation (when the ruler is present): the 1px
/// root top border + toolbar 42 + divider 1, ruler block 59 + divider 1; the
/// four rows then share `timelineHeight - 104` px with three 1px dividers
/// between them (without the ruler the reservation is 44px).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Project oneClipProject() {
    return Project(
      id: 'p1',
      name: 'Test',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sourceMediaPaths: const ['C:/media/sample.mp4'],
      tracks: const [
        Track(
          id: 'track-1',
          type: TrackType.video,
          label: 'Video',
          clips: [
            Clip(
              id: 'clip-1',
              trackId: 'track-1',
              sourcePath: 'C:/media/sample.mp4',
              startMs: 0,
              endMs: 30000,
              label: 'sample.mp4',
            ),
          ],
        ),
      ],
      durationMs: 30000,
    );
  }

  const tracksScrollKey = ValueKey('timeline-tracks-scroll');

  Finder verticalTrackScrollable() => find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );

  /// Pumps the split + timeline at [viewport]. With [withRuler] the harness
  /// provides a tagging document, so the 60px ruler block is present (the
  /// production behavior once the document has content).
  Future<ProviderContainer> pumpWorkspace(
    WidgetTester tester,
    Size viewport, {
    bool withRuler = true,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = TaggingWidgetHarness();
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        projectRepositoryProvider.overrideWithValue(
          _FakeProjectRepository(db: db),
        ),
        if (withRuler)
          taggingProvidersProvider.overrideWithValue(harness.providers),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectProvider.notifier).setProject(oneClipProject());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: WorkspaceSplit(
              // Stand-in for the preview pane: the real PreviewPlayer is
              // never pumped (media_kit has no host native libs).
              preview: ColoredBox(color: Color(0xFF000000)),
              timeline: TimelineView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  double clipBlockHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ClipBlock)).height;

  List<double> rowHeights(WidgetTester tester) => [
    for (var index = 0; index < 4; index++)
      tester.getSize(find.byType(TrackRow).at(index)).height,
  ];

  /// Drags upward inside the tracks region from a point below the first
  /// row (empty Audio area), so the drag reaches the vertical scroller.
  Future<void> dragTracksUp(WidgetTester tester) async {
    final start =
        tester.getTopLeft(find.byKey(tracksScrollKey)) + const Offset(160, 60);
    await tester.dragFrom(start, const Offset(0, -80));
    await tester.pump();
  }

  group('WorkspaceSplitPolicy (pure sizing)', () {
    const policy = WorkspaceSplitPolicy();

    test('holds the 40% timeline share at the common window sizes', () {
      expect(policy.timelineHeightFor(720), closeTo(288, 0.01));
      expect(policy.timelineHeightFor(900), closeTo(360, 0.01));
      expect(policy.timelineHeightFor(1080), closeTo(432, 0.01));
    });

    test('never exceeds the 45% ceiling and keeps the 200px preview floor', () {
      for (final height in const [720.0, 900.0, 1080.0, 400.0]) {
        final timeline = policy.timelineHeightFor(height);
        expect(timeline, lessThanOrEqualTo(height * 0.45 + 0.01));
        expect(
          policy.previewHeightFor(height),
          greaterThanOrEqualTo(200 - 0.01),
        );
        expect(policy.previewHeightFor(height), greaterThan(0));
      }
    });

    test('holds the 220px timeline floor while the floors fit', () {
      // 40% of 500 is 200; the floor lifts it to 220 and the preview keeps
      // well above its floor.
      expect(policy.timelineHeightFor(500), closeTo(220, 0.01));
    });

    test('degrades proportionally below the two-floor window', () {
      // At 280 the reachable ceiling (~70px) is under the timeline hard
      // minimum, so both panes fall back to the plain 40/60 share.
      expect(policy.timelineHeightFor(280), closeTo(112, 0.01));
      expect(policy.previewHeightFor(280), greaterThan(0));
      expect(policy.timelineHeightFor(0), 0);
    });
  });

  group('layout matrix with the ruler present', () {
    testWidgets(
      '1280x720 (app default): 288px timeline, 48px rows, vertical scroll, '
      'and select + trim still work',
      (WidgetTester tester) async {
        final container = await pumpWorkspace(tester, const Size(1280, 720));
        expect(tester.takeException(), isNull);

        expect(
          tester.getSize(find.byType(TimelineView)).height,
          closeTo(288, 0.01),
        );

        // Scroll mode: the region (288 - 104 = 184px) is shorter than the
        // four 48px rows + dividers (195px), so the rows keep 48px and the
        // region scrolls.
        final scroll = verticalTrackScrollable();
        expect(scroll, findsOneWidget);
        expect(find.byType(TrackRow), findsNWidgets(4));
        for (final height in rowHeights(tester)) {
          expect(height, closeTo(48, 0.01));
        }
        expect(clipBlockHeight(tester), closeTo(48, 0.01));

        // The Video row starts pinned to the top of the scroll viewport.
        expect(
          tester.getTopLeft(find.byType(TrackRow).first).dy,
          closeTo(tester.getTopLeft(find.byKey(tracksScrollKey)).dy, 0.01),
        );

        // Select the clip: the block's tap target works at 48px rows.
        await tester.tap(find.text('sample.mp4'));
        await tester.pump();
        expect(container.read(selectedClipIdProvider), equals('clip-1'));
        expect(find.byKey(const ValueKey('trim-start-clip-1')), findsOneWidget);

        // Trim: dragging the start handle +30px moves the in point by
        // 30 * 1000/12 = 2500ms through the manual-edit controller.
        await tester.drag(
          find.byKey(const ValueKey('trim-start-clip-1')),
          const Offset(30, 0),
        );
        await tester.pump();
        await tester.pump();
        final clip = container
            .read(projectProvider)
            .value!
            .tracks
            .first
            .clips
            .first;
        expect(clip.startMs, equals(2500));
        expect(clip.endMs, equals(30000));

        // The region scrolls (functional): a drag moves the offset.
        await dragTracksUp(tester);
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('1400x900: 360px timeline, four 63.25px rows, fit mode', (
      WidgetTester tester,
    ) async {
      await pumpWorkspace(tester, const Size(1400, 900));
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byType(TimelineView)).height,
        closeTo(360, 0.01),
      );
      // Fit mode: (360 - 104 - 3) / 4 = 63.25px rows; no vertical fallback.
      expect(verticalTrackScrollable(), findsNothing);
      for (final height in rowHeights(tester)) {
        expect(height, closeTo(63.25, 0.01));
      }
      expect(clipBlockHeight(tester), closeTo(48, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '1920x1080: 432px timeline, four 81.25px rows (>= 48), fit mode',
      (WidgetTester tester) async {
        await pumpWorkspace(tester, const Size(1920, 1080));
        expect(tester.takeException(), isNull);

        expect(
          tester.getSize(find.byType(TimelineView)).height,
          closeTo(432, 0.01),
        );
        // Fit mode: (432 - 104 - 3) / 4 = 81.25px rows.
        expect(verticalTrackScrollable(), findsNothing);
        for (final height in rowHeights(tester)) {
          expect(height, greaterThanOrEqualTo(48));
          expect(height, closeTo(81.25, 0.01));
        }
        expect(clipBlockHeight(tester), closeTo(48, 0.01));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '640x400: degrades gracefully (180px timeline) and still scrolls at '
      '48px rows without exceptions',
      (WidgetTester tester) async {
        await pumpWorkspace(tester, const Size(640, 400));
        expect(tester.takeException(), isNull);

        // The preview floor caps the timeline at the 45% ceiling: 180px.
        expect(
          tester.getSize(find.byType(TimelineView)).height,
          closeTo(180, 0.01),
        );
        final scroll = verticalTrackScrollable();
        expect(scroll, findsOneWidget);
        for (final height in rowHeights(tester)) {
          expect(height, closeTo(48, 0.01));
        }
        expect(clipBlockHeight(tester), closeTo(48, 0.01));
        expect(
          tester.getTopLeft(find.byType(TrackRow).first).dy,
          closeTo(tester.getTopLeft(find.byKey(tracksScrollKey)).dy, 0.01),
        );

        await dragTracksUp(tester);
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ruler-reserved behavior', () {
    testWidgets(
      '1280x720 without a ruler: the same 288px timeline fits four 60.25px rows',
      (WidgetTester tester) async {
        await pumpWorkspace(tester, const Size(1280, 720), withRuler: false);
        expect(tester.takeException(), isNull);

        expect(
          tester.getSize(find.byType(TimelineView)).height,
          closeTo(288, 0.01),
        );
        // Without the reserved 60px ruler the region is (288 - 44) = 244px,
        // so the rows share it evenly: (244 - 3) / 4 = 60.25px.
        expect(verticalTrackScrollable(), findsNothing);
        for (final height in rowHeights(tester)) {
          expect(height, closeTo(60.25, 0.01));
        }
        expect(clipBlockHeight(tester), closeTo(48, 0.01));
      },
    );
  });
}

/// Fake repository: the sandbox has no path_provider; the save is a no-op
/// so manual edits reach the project state without file IO (the
/// timeline_view_test pattern).
class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({required AppDatabase db}) : super(db);

  @override
  Future<void> save(Project project) async {}
}
