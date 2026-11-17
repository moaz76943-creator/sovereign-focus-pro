import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/main.dart';
import 'package:focus_studio_pro/features/studios/studios_catalog.dart';
import 'package:focus_studio_pro/features/analytics/analytics_engine.dart';
import 'package:focus_studio_pro/features/flashcards/fsrs_engine.dart';

void main() {
  test('All 10 Studios are registered with non-empty Arabic and English titles', () {
    expect(StudiosCatalog.all10Studios.length, 10);
    for (final s in StudiosCatalog.all10Studios) {
      expect(s.titleEn.isNotEmpty, isTrue);
      expect(s.titleAr.isNotEmpty, isTrue);
    }
  });

  test('AnalyticsEngine computes 30-day workload and Western-digit heatmap keys', () {
    final t0 = DateTime.utc(2026, 11, 17, 8, 0);
    final summary = AnalyticsEngine.computeSummary(
      cardStates: [FsrsCardState.initial(t0)],
      focusSessionDurationsSeconds: const [1500, 1500],
      referenceNowUtc: t0,
    );
    expect(summary.recordedFocusMinutes, 50);
    expect(summary.next30DaysWorkload.length, 30);
    expect(summary.next30DaysWorkload.first, 1);
    expect(summary.dailyActivityHeatmap.keys.first, '2026-11-17');
  });

  testWidgets('HomeShellScreen renders cleanly with header Studios button and Nature Sounds on top',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FocusStudioProApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('studios_header_btn')), findsOneWidget);
    expect(find.byKey(const Key('focus_clock_text')), findsOneWidget);

    // Switch to Sounds tab (index 2)
    await tester.tap(find.byIcon(Icons.graphic_eq_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nature_sounds_header')), findsOneWidget);
    expect(find.byKey(const Key('spatial_audio_expansion')), findsOneWidget);
  });
}
