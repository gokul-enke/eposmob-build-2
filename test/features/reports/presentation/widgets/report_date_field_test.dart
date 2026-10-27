import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_machine/features/reports/presentation/widgets/report_date_field.dart';
import '../../../../test_support/app_translations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  tearDown(Get.reset);

  Future<List<DateTime?>> mount(WidgetTester tester, DateTime? value) async {
    final changes = <DateTime?>[];
    await tester.pumpWidget(GetMaterialApp(
        translations: EnglishTranslations(),
        locale: const Locale('en'),
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: ReportDateField(
                    label: 'From Date',
                    value: value,
                    onChanged: changes.add)))));
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('empty has no clear button; a date shows and clears',
      (tester) async {
    await mount(tester, null);
    expect(find.text('From Date'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    final changes = await mount(tester, DateTime(2026, 10, 2));
    expect(find.text('2026 Oct 02'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear date'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
  });
}
