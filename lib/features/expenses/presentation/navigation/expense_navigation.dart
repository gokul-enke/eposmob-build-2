import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import '../../domain/models/expense.dart';
import '../state/expense_view_controller.dart';

abstract final class ExpenseNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static const sectionIndices = {
    SideBarController.expenseListScreenIndex,
    SideBarController.createExpenseScreenIndex,
    SideBarController.viewExpenseScreenIndex
  };
  static void openList() =>
      _sidebar.index.value = SideBarController.expenseListScreenIndex;
  static void openCreate() =>
      _sidebar.index.value = SideBarController.createExpenseScreenIndex;
  static void openDetails(Expense expense) {
    Get.put(ExpenseViewController()).selectedRef.value =
        expense.referenceNumber;
    _sidebar.index.value = SideBarController.viewExpenseScreenIndex;
  }
}
