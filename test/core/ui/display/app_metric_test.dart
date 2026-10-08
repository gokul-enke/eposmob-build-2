import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  testWidgets(
      'metrics default to blue 24px icons and support explicit overrides',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AppMetricStrip(metrics: [
      AppMetric(icon: Icons.payments_outlined, label: 'Default', value: '10'),
      AppMetric(
          icon: Icons.inventory_2_outlined,
          label: 'Custom',
          value: '20',
          iconSize: 16,
          iconColor: AppColors.muted),
    ]))));
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons[0].size, 24);
    expect(icons[0].color, AppColors.primary);
    expect(icons[1].size, 16);
    expect(icons[1].color, AppColors.muted);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
