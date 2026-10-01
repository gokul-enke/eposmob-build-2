import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';

/// Display helpers for one [CustomerPurchaseItem].
abstract final class PurchaseHistoryLabels {
  static String orderNumber(CustomerPurchaseItem item) =>
      item.orderNumber.isEmpty ? 'general.not_available'.tr : item.orderNumber;

  static String date(CustomerPurchaseItem item) =>
      DateHelper.formatISODate(item.date);

  static String price(CustomerPurchaseItem item) =>
      AmountHelper.formatAmount(item.price);
}

/// Columns of the purchase history table: order, date, qty, price, action.
List<TableColumnDef<CustomerPurchaseItem>> purchaseHistoryColumns({
  required ValueChanged<CustomerPurchaseItem> onUse,
}) {
  return [
    TableColumnDef(
      label: 'customer_profile.col_order'.tr,
      flex: 2,
      cellBuilder: (item, _) => TableCells.text(
        PurchaseHistoryLabels.orderNumber(item),
        color: AppColors.heading,
        weight: FontWeight.w600,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_date'.tr,
      flex: 2,
      cellBuilder: (item, _) => TableCells.text(
        PurchaseHistoryLabels.date(item),
        color: AppColors.muted,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_qty'.tr,
      flex: 1,
      align: TextAlign.center,
      cellBuilder: (item, _) => TableCells.text(
        item.quantity,
        color: AppColors.primary,
        weight: FontWeight.w600,
        align: TextAlign.center,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_price'.tr,
      flex: 1.6,
      align: TextAlign.center,
      cellBuilder: (item, _) => TableCells.text(
        PurchaseHistoryLabels.price(item),
        color: AppColors.heading,
        weight: FontWeight.w600,
        align: TextAlign.center,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_action'.tr,
      flex: 1.8,
      cellBuilder: (item, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Center(
          child: AppPrimaryButton(
            label: 'billing.use_this'.tr,
            height: 34,
            onPressed: () => onUse(item),
          ),
        ),
      ),
    ),
  ];
}

/// Card for one past purchase on narrow dialogs.
class PurchaseHistoryCard extends StatelessWidget {
  const PurchaseHistoryCard({
    super.key,
    required this.item,
    required this.onUse,
  });

  final CustomerPurchaseItem item;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      title:
          '${'general.order_number_hash'.tr}${PurchaseHistoryLabels.orderNumber(item)}',
      subtitle: PurchaseHistoryLabels.date(item),
      body: AppMetricStrip(
        metrics: [
          AppMetric(
            icon: Icons.inventory_2_outlined,
            label: 'general.quantity_short'.tr,
            value: item.quantity,
          ),
          AppMetric(
            icon: Icons.sell_outlined,
            label: 'billing.price'.tr,
            value: PurchaseHistoryLabels.price(item),
          ),
        ],
      ),
      actionLabel: 'billing.use_this'.tr,
      actionIcon: Icons.check_rounded,
      onAction: onUse,
    );
  }
}
