import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/expenses/presentation/widgets/list/expense_list_status_pill.dart';
import '../../../../../test_support/app_translations.dart';

void main() {
  tearDown(Get.reset);
  for (final status in ['SUCC', 'PENDING', 'FAIL', 'CUSTOM']) {
    testWidgets('status $status retains a translated label and pill border',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp(
          translations: EnglishTranslations(),
          locale: const Locale('en'),
          home: Scaffold(body: ExpenseListStatusPill(status: status))));
      final key = {
        'SUCC': 'transaction_status_labels.succ',
        'PENDING': 'quotations.status_pending',
        'FAIL': 'transaction_status_labels.fail'
      }[status];
      expect(find.text(key?.tr ?? status), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
          of: find.byType(ExpenseListStatusPill),
          matching: find.byType(Container)));
      expect((container.decoration as BoxDecoration).border, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
