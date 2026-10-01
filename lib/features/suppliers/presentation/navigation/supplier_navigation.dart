import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

import '../../domain/models/supplier.dart';
import '../state/supplier_provider.dart';

/// The one place that knows how the supplier screens are reached in the
/// sidebar shell. Screens call these instead of setting sidebar indices.
abstract final class SupplierNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());

  /// Sidebar indices of the suppliers section (for highlighting the menu).
  static const sectionIndices = {
    SideBarController.suppliersScreenIndex,
    SideBarController.supplierDetailsScreenIndex,
    SideBarController.supplierProfileScreenIndex,
  };

  static bool get isInSuppliersSection =>
      sectionIndices.contains(_sidebar.index.value);

  static void openList() =>
      _sidebar.index.value = SideBarController.suppliersScreenIndex;

  /// Selects [supplier] and shows its profile.
  static void openProfile(SupplierProvider provider, Supplier supplier) {
    provider.selectSupplier(supplier);
    _sidebar.index.value = SideBarController.supplierProfileScreenIndex;
  }
}
