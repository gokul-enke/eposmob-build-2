import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';

import '../../../state/customer_orders_controller.dart';
import 'order_card.dart';
import 'order_details_dialog.dart';
import 'order_table_columns.dart';

/// Body of the Orders tab, driven by [controller]. Needs a bounded height.
class CustomerOrdersView extends StatelessWidget {
  const CustomerOrdersView({
    super.key,
    required this.controller,
    required this.currency,
    this.customerName,
  });

  /// Orders listed per API page (used for row numbers).
  static const pageSize = 20;

  final CustomerOrdersController controller;
  final String currency;

  /// Fallback for orders without a customer name.
  final String? customerName;

  void _view(BuildContext context, ListOrderModelData order) {
    showOrderDetailsDialog(
      context,
      order: order,
      currency: currency,
      fallbackCustomerName: customerName,
    );
  }

  String _countLabel() => 'customer_profile.orders_on_page'
      .trParams({'count': '${controller.orders.length}'});

  Widget _body(BuildContext context) {
    final errorKey = controller.errorKey;
    if (errorKey != null && !controller.isLoading) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'customer_orders.title_error'.tr,
        subtitle: errorKey.tr,
        action: AppPrimaryButton(
          label: 'customer_orders.btn_try_again'.tr,
          icon: Icons.refresh_rounded,
          onPressed: controller.retry,
        ),
      );
    }

    return AppAdaptiveList<ListOrderModelData>(
      isLoading: controller.isLoading,
      items: controller.orders,
      columns: orderTableColumns(
        currency: currency,
        onView: (order) => _view(context, order),
      ),
      onRowTap: (order) => _view(context, order),
      cardBuilder: (order, number) => OrderCard(
        order: order,
        rowNumber: number,
        currency: currency,
        onView: () => _view(context, order),
      ),
      emptyState: AppEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'customer_orders.title_empty'.tr,
        subtitle: 'customer_orders.msg_empty'.tr,
      ),
      pagination: controller.showPagination
          ? ListPagination(
              currentPage: controller.currentPage,
              totalPages: controller.totalPages,
              itemsPerPage: pageSize,
              onPageChanged: controller.goToPage,
              countLabel: _countLabel(),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.shopping_bag_outlined,
            title: 'customer_orders.title'.tr,
            subtitle: _countLabel(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }
}
