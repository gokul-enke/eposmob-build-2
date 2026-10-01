import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import '../../../state/supplier_orders_controller.dart';
import 'supplier_purchase_card.dart';
import 'supplier_purchase_details_dialog.dart';
import 'supplier_purchase_table_columns.dart';

/// Body of the supplier Orders tab, driven by [controller]. Needs a bounded
/// height.
class SupplierOrdersView extends StatelessWidget {
  const SupplierOrdersView({
    super.key,
    required this.controller,
    required this.currency,
  });

  final SupplierOrdersController controller;
  final String currency;

  void _view(BuildContext context, SupplierPurchase purchase) {
    showSupplierPurchaseDetailsDialog(
      context,
      purchase: purchase,
      currency: currency,
    );
  }

  Widget _body(BuildContext context) {
    if (controller.hasError && !controller.isLoading) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'supplier_profile.orders_load_failed'.tr,
        action: AppOutlinedButton(
          label: 'general.retry'.tr,
          icon: Icons.refresh_rounded,
          onPressed: controller.retry,
        ),
      );
    }

    return AppAdaptiveList<SupplierPurchase>(
      isLoading: controller.isLoading,
      items: controller.purchases,
      columns: supplierPurchaseTableColumns(
        currency: currency,
        onView: (purchase) => _view(context, purchase),
      ),
      onRowTap: (purchase) => _view(context, purchase),
      cardBuilder: (purchase, number) => SupplierPurchaseCard(
        purchase: purchase,
        rowNumber: number,
        currency: currency,
        onView: () => _view(context, purchase),
      ),
      emptyState: AppEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'supplier_profile.orders_empty_title'.tr,
        subtitle: 'supplier_profile.orders_empty_msg'.tr,
      ),
      pagination: controller.showPagination
          ? ListPagination(
              currentPage: controller.currentPage,
              totalPages: controller.totalPages,
              itemsPerPage: controller.perPage,
              onPageChanged: controller.goToPage,
              countLabel: 'supplier_profile.orders_on_page'.trParams(
                {'count': '${controller.purchases.length}'},
              ),
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
            icon: Icons.shopping_cart_outlined,
            title: '${'supplier_profile.orders_title'.tr} '
                '(${controller.allPurchases.length})',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }
}
