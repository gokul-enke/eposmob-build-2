import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

import '../../domain/models/customer_list.dart';
import '../state/customer_provider.dart';

/// The one place that knows how the customer screens are reached in the
/// sidebar shell. Screens call these instead of setting sidebar indices.
abstract final class CustomerNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());

  /// Sidebar indices that belong to the customers section (for highlighting
  /// the menu entry).
  static const sectionIndices = {
    SideBarController.customersScreenIndex,
    SideBarController.addCustomerScreenIndex,
    SideBarController.userProfileScreenIndex,
    SideBarController.customerProfileScreenIndex,
  };

  static bool get isInCustomersSection =>
      sectionIndices.contains(_sidebar.index.value);

  static void openList() =>
      _sidebar.index.value = SideBarController.customersScreenIndex;

  static void openAddPage() =>
      _sidebar.index.value = SideBarController.addCustomerScreenIndex;

  /// Selects [customer] and shows its profile.
  static void openProfile(
    CustomerProvider provider,
    CustomerListModelData customer,
  ) {
    provider.selectCustomer(customer);
    _sidebar.index.value = SideBarController.customerProfileScreenIndex;
  }
}
