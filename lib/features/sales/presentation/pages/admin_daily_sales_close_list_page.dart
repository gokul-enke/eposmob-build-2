import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/day_closes/domain/admin_day_close_list.dart';
import 'package:pos_machine/features/day_closes/presentation/pages/admin_day_close_list_page.dart';
import '../navigation/sales_navigation.dart';
import '../state/sales_provider.dart';

/// Listing owns its requests; View details and the admin return route stay in Sales.
class AdminDailySalesCloseListPage extends StatelessWidget {
  const AdminDailySalesCloseListPage({super.key, this.readSource});
  final Future<AdminDayCloseSource> Function()? readSource;
  @override
  Widget build(BuildContext context) => AdminDayCloseListPage(
      readSource: readSource,
      onView: (context, row) {
        context.read<SalesProvider>()
          ..setSelectedDailySalesCloseData(row)
          ..setReturnIndex(
              SideBarController.adminDailySalesCloseListScreenIndex);
        SalesNavigation.openDailyCloseDetails();
      });
}
