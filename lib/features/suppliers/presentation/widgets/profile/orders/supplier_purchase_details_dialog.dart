import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_purchase_labels.dart';

/// Shows the items and totals of [purchase] (the old expandable card's
/// body).
Future<void> showSupplierPurchaseDetailsDialog(
  BuildContext context, {
  required SupplierPurchase purchase,
  required String currency,
}) {
  return AppDialog.show<void>(
    context,
    title: SupplierPurchaseLabels.title(purchase),
    subtitle: SupplierPurchaseLabels.itemCount(purchase),
    maxWidth: 520,
    child: SupplierPurchaseDetails(purchase: purchase, currency: currency),
  );
}

/// Number, status, items and totals of one purchase order.
class SupplierPurchaseDetails extends StatelessWidget {
  const SupplierPurchaseDetails({
    super.key,
    required this.purchase,
    required this.currency,
  });

  final SupplierPurchase purchase;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tax = SupplierPurchaseLabels.tax(purchase);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Line(
          label: 'supplier_profile.orders_label_purchase_number'.tr,
          value: SupplierPurchaseLabels.orNa(purchase.purchaseNumber),
        ),
        _Line(
          label: 'supplier_profile.orders_label_status'.tr,
          value: SupplierPurchaseLabels.status(purchase.status),
          valueColor:
              SupplierPurchaseLabels.statusTone(purchase.status).foreground,
        ),
        const Divider(height: 20, color: AppColors.border),
        if (purchase.items.isEmpty)
          Text(
            'supplier_profile.orders_msg_no_items'.tr,
            style: AppTextStyles.caption,
          )
        else
          for (final item in purchase.items)
            _Line(
              label: '${item.productName} (x${item.quantity})',
              value: SupplierPurchaseLabels.money(currency, item.totalPrice),
              labelColor: AppColors.heading,
            ),
        const Divider(height: 20, color: AppColors.border),
        _Line(
          label: 'supplier_profile.orders_label_subtotal'.tr,
          value: SupplierPurchaseLabels.money(currency, purchase.amountTotal),
        ),
        if (tax != null)
          _Line(
            label: 'supplier_profile.orders_label_tax'.tr,
            value: SupplierPurchaseLabels.money(currency, tax),
          ),
        const SizedBox(height: AppSpacing.sm),
        _Line(
          label: 'supplier_profile.orders_label_total'.tr,
          value: SupplierPurchaseLabels.money(currency, purchase.amountTotal),
          valueColor: AppColors.green,
          emphasized: true,
        ),
      ],
    );
  }
}

/// Label on the start side, value on the end side.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 14.0 : 12.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized
                    ? AppColors.heading
                    : (labelColor ?? AppColors.muted),
                fontSize: size,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.heading,
              fontSize: size,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
