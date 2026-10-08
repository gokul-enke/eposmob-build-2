import 'package:pos_machine/controllers/sidebar_controller.dart';

/// Listing navigation only. Inner stock screens retain their current routing.
class StockNavigation {
  const StockNavigation(this.sidebar);
  final SideBarController sidebar;
  void openList() =>
      sidebar.index.value = SideBarController.stockListScreenIndex;
  void openAdd() => sidebar.index.value = SideBarController.addStockScreenIndex;
}
