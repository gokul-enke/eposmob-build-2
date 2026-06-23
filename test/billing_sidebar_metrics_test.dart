/// Phase-4 characterization test for [BillingSidebarMetrics.clampedWidth],
/// the pure sidebar-width math extracted from `billing_page.dart`.
///
/// These values pin the exact behaviour the inline `_getClampedSidebarWidth`
/// produced, so the extraction is provably behaviour-preserving.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/presentation/utils/billing_sidebar_metrics.dart';

void main() {
  group('BillingSidebarMetrics.clampedWidth', () {
    test('wide row: clamps to [250, 420]', () {
      // usable 2000 → lower=min(250,800)=250, upper=max(250,min(420,1380))=420
      expect(BillingSidebarMetrics.clampedWidth(2000, 520), 420);
      expect(BillingSidebarMetrics.clampedWidth(2000, 300), 300);
      expect(BillingSidebarMetrics.clampedWidth(2000, 100), 250);
    });

    test('medium row: upper bound follows main-content floor', () {
      // usable 1000 → lower=250, upper=max(250,min(420,380))=380
      expect(BillingSidebarMetrics.clampedWidth(1000, 300), 300);
      expect(BillingSidebarMetrics.clampedWidth(1000, 400), 380);
      expect(BillingSidebarMetrics.clampedWidth(1000, 200), 250);
    });

    test('narrow row: range collapses to the lower bound', () {
      // usable 800 → lower=250, upper=max(250,min(420,180))=250
      expect(BillingSidebarMetrics.clampedWidth(800, 400), 250);
      expect(BillingSidebarMetrics.clampedWidth(800, 100), 250);
    });

    test('very narrow row: lower bound drops below 250 (40% rule)', () {
      // usable 500 → lower=min(250,200)=200, upper=max(200,min(420,-120))=200
      expect(BillingSidebarMetrics.clampedWidth(500, 300), 200);
      expect(BillingSidebarMetrics.clampedWidth(500, 50), 200);
    });

    test('exposed constants match the original inline values', () {
      expect(BillingSidebarMetrics.minWidth, 250);
      expect(BillingSidebarMetrics.maxWidth, 420);
      expect(BillingSidebarMetrics.mainContentMinWidth, 620);
    });
  });
}
