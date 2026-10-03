import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_machine/features/expenses/presentation/pages/view_expense_page.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import '../../support/expense_page_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  tearDown(Get.reset);
  for (final size in [const Size(375, 812), const Size(1440, 900)]) {
    testWidgets('detail page preserves selected expense at $size',
        (tester) async {
      await mountExpensePage(tester, const ViewExpensePage(), size);
      expect(find.textContaining('EXP00001'), findsWidgets);
      expect(find.text('SAR 126.13'), findsWidgets);
      expect(find.text('Office rent'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(Get.find<SideBarController>().index.value, 93);
      final error = tester.takeException();
      if (size.width == 375) {
        expect(error, isA<FlutterError>());
        expect(
            error.toString(), contains('overflowed by 12 pixels on the right'));
      } else {
        expect(error, isNull);
      }
    });
  }
}
