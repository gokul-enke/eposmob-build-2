import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/features/expenses/presentation/pages/create_expense_page.dart';
import 'package:pos_machine/features/expenses/presentation/widgets/form/expense_form_body.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import '../../support/expense_page_harness.dart';

class PendingMasterData extends ExpenseMasterDataFake {
  final pending = Completer<MasterData?>();
  @override
  Future<MasterData?> fetchMasterData(String code) => pending.future;
}

void main() {
  tearDown(Get.reset);
  for (final size in [const Size(375, 812), const Size(1440, 900)]) {
    testWidgets('create form fits $size with original controls and navigation',
        (tester) async {
      await mountExpensePage(tester, const CreateExpensePage(), size);
      expect(find.byKey(const ValueKey('expense_category_dropdown')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('expense_payment_method_dropdown')),
          findsOneWidget);
      final body = tester.widget<ExpenseFormBody>(find.byType(ExpenseFormBody));
      expect(body.controller.referenceNo, 'EXP00002');
      body.onCancel();
      expect(Get.find<SideBarController>().index.value, 93);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'leaving while master data loads does not access disposed context or focus',
      (tester) async {
    final master = PendingMasterData();
    await mountExpensePage(
        tester, const CreateExpensePage(), const Size(1440, 900),
        master: master);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    master.pending.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
