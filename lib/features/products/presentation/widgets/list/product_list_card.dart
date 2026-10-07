import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/get_product.dart';
import 'product_list_actions.dart';
import 'product_list_copy.dart';
import 'product_list_labels.dart';

class ProductListCard extends StatelessWidget {
  const ProductListCard(
      {super.key,
      required this.product,
      required this.number,
      required this.itemCodeEnabled,
      required this.canViewPurchasePrice,
      required this.onView,
      this.onDelete});
  final GetProduct product;
  final int number;
  final bool itemCodeEnabled, canViewPurchasePrice;
  final VoidCallback onView;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => AppListCard(
        title: ProductListLabels.name(product),
        subtitle: ProductListLabels.category(product),
        leading: AppAvatar(
            name: ProductListLabels.name(product),
            semanticLabel: ProductListLabels.name(product)),
        trailing: Text('$number', style: AppTextStyles.label),
        onTap: onView,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppMetricStrip(metrics: [
            AppMetric(
                icon: Icons.payments_outlined,
                label: 'product.price'.tr,
                value: ProductListLabels.value(product.price?.price)),
            AppMetric(
                icon: Icons.sell_outlined,
                label: 'product.mrp'.tr,
                value: ProductListLabels.value(product.mrp)),
          ]),
          if (canViewPurchasePrice)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: AppMetric(
                    icon: Icons.receipt_outlined,
                    label: 'product.purchase_price'.tr,
                    value: ProductListLabels.value(
                        ProductListLabels.purchasePrice(product)))),
          Text('${'product.unit'.tr}: ${ProductListLabels.value(product.unit)}',
              style: AppTextStyles.body),
          if (itemCodeEnabled)
            ProductListCopy(
                label: 'product.item_code'.tr,
                value: product.itemCode,
                message: 'product.item_code_copied'),
          ProductListCopy(
              label: 'product.barcode'.tr,
              value: product.barcode,
              message: 'product.barcode_copied'),
          ProductListActions(onView: onView, onDelete: onDelete),
        ]),
      );
}
