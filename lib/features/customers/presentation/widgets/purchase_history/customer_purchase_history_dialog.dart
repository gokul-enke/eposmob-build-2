import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';

import 'purchase_history_list.dart';

/// Shows a customer's last purchases of [product] so the cashier can reuse
/// an old price.
///
/// Pops with:
/// * `{'price': double, 'orderNumber': String, 'useCurrentPrice': false}`
///   when a row's "Use This" is pressed;
/// * `{'useCurrentPrice': true}` for "Use Current Price";
/// * `null` for Cancel / close.
class CustomerPurchaseHistoryDialog extends StatelessWidget {
  const CustomerPurchaseHistoryDialog({
    super.key,
    required this.product,
    required this.purchaseHistory,
    required this.customerName,
  });

  final GetProduct product;
  final List<CustomerPurchaseItem> purchaseHistory;
  final String customerName;

  /// Below this list width the rows become cards.
  static const cardsBelow = 460.0;

  void _useItem(BuildContext context, CustomerPurchaseItem item) {
    Navigator.of(context).pop(<String, dynamic>{
      'price': item.priceValue,
      'orderNumber': item.orderNumber,
      'useCurrentPrice': false,
    });
  }

  String _countTitle() {
    final count = purchaseHistory.length;
    return count == 1
        ? 'customer_profile.history_last_purchase_one'.tr
        : 'customer_profile.history_last_purchases'
            .trParams({'count': '$count'});
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return FocusTraversalGroup(
      child: AppDialog(
        title: 'billing.customer_purchase_history'.tr,
        subtitle: '${'general.customer_prefix'.tr}$customerName',
        maxWidth: 600,
        scrollable: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${'general.product_prefix'.tr}${product.productName ?? ''}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_countTitle(), style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AppAdaptiveList<CustomerPurchaseItem>(
                  items: purchaseHistory,
                  cardsBelow: cardsBelow,
                  columns: purchaseHistoryColumns(
                    onUse: (item) => _useItem(context, item),
                  ),
                  cardBuilder: (item, _) => PurchaseHistoryCard(
                    item: item,
                    onUse: () => _useItem(context, item),
                  ),
                  emptyState: AppEmptyState(
                    icon: Icons.history_rounded,
                    title: 'billing.no_purchase_history'.tr,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  AppOutlinedButton(
                    label: 'billing.use_current_price'.tr,
                    onPressed: () => Navigator.of(context)
                        .pop(<String, dynamic>{'useCurrentPrice': true}),
                  ),
                  AppOutlinedButton(
                    label: 'general.cancel'.tr,
                    foreground: AppColors.body,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
