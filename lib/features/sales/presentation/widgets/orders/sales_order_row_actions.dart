import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/services/print_service.dart';

import '../../commands/sales_order_cancel.dart';
import '../../commands/sales_order_payment.dart';
import '../../commands/sales_order_return_items.dart';
import '../../commands/sales_order_share.dart';
import '../../commands/sales_order_status.dart';
import '../../sharing/sales_page_services.dart';
import 'sales_more_options_sheet.dart';

/// View / Print / More actions for one Sales or Online Orders row.
///
/// [context] must be the page's context: commands pop the sheet and then show
/// dialogs on it. [refresh] reloads the list that owns the row after a
/// cancel, status or payment change.
class SalesOrderRowActions extends StatelessWidget {
  const SalesOrderRowActions(
      {super.key,
      required this.pageContext,
      required this.services,
      required this.order,
      required this.isOnlineSales,
      required this.refresh});
  final BuildContext pageContext;
  final SalesPageServices services;
  final ListOrderModelData order;
  final bool isOnlineSales;
  final Future<void> Function() refresh;

  Widget _icon(IconData icon, String tooltip, VoidCallback onPressed) =>
      AppSquareIconButton(
          icon: icon,
          size: AppSizes.compactControl,
          foreground: AppColors.primary,
          tooltip: tooltip.tr,
          onPressed: onPressed);

  @override
  Widget build(BuildContext _) {
    final context = pageContext;
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          _icon(Icons.visibility, 'sales.view_order', () {
            services.sales.setOrderNumber(order.orderNumber ?? '0');
            services.sales.isOnlineSalesNavigation = isOnlineSales;
            SalesNavigation.openDetails();
          }),
          _icon(Icons.print, 'sales.print_order', () async {
            try {
              final number = order.orderNumber;
              if (number == null || number.isEmpty) return;
              await const PrintService()
                  .printOrderByIdWithOptions(context, number);
            } catch (error) {
              debugPrint(error.toString());
            }
          }),
          _icon(Icons.more_vert, 'sales.more_actions', () async {
            if (!context.mounted) return;
            await showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16))),
                builder: (ctx) => SalesMoreOptionsSheet(
                    order: order,
                    onShare: (sheet) => shareSalesOrder(
                        context, sheet, services, order, isOnlineSales),
                    onReturnItems: (sheet) => returnItemsSalesOrder(
                        context, sheet, services, order, isOnlineSales),
                    onCancel: (sheet) =>
                        cancelSalesOrder(context, sheet, services, order, refresh),
                    onStatus: (sheet) =>
                        statusSalesOrder(context, sheet, services, order, refresh),
                    onPayment: (sheet) => paymentSalesOrder(
                        context, sheet, services, order, refresh)));
          }),
        ]);
  }
}
