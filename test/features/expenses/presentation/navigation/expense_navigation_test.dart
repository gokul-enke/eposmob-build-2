import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import 'package:pos_machine/features/expenses/presentation/navigation/expense_navigation.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_view_controller.dart';
import '../../support/expense_fixtures.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);
  test(
      'named routes retain slots and publish selected reference before entering details',
      () {
    final sidebar = Get.put(SideBarController());
    ExpenseNavigation.openList();
    expect(sidebar.index.value, 93);
    ExpenseNavigation.openCreate();
    expect(sidebar.index.value, 94);
    String? referenceAtNavigation;
    final subscription = sidebar.index.listen((index) {
      if (index == 95) {
        referenceAtNavigation =
            Get.find<ExpenseViewController>().selectedRef.value;
      }
    });
    ExpenseNavigation.openDetails(Expense.fromJson(row(1)));
    expect(sidebar.index.value, 95);
    expect(referenceAtNavigation, '0001');
    expect(ExpenseNavigation.sectionIndices, {93, 94, 95});
    subscription.cancel();
  });
}
