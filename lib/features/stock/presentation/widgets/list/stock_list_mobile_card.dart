import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'stock_list_cells.dart';

class StockListMobileCard extends StatelessWidget {
  const StockListMobileCard(
      {super.key,
      required this.stock,
      required this.variantEnabled,
      required this.canViewPurchasePrice,
      required this.actions,
      required this.onCopy});
  final ListStockModelData stock;
  final bool variantEnabled, canViewPurchasePrice;
  final Widget actions;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: stock.productName ?? 'stock.unnamed'.tr,
      subtitle: [stock.categoryName, stock.storeName]
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .join(' · '),
      leading: AppAvatar(
          name: stock.productName ?? '',
          semanticLabel: stock.productName ?? 'stock.unnamed'.tr),
      trailing: stockQuantity(stock),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (variantEnabled && stock.productVariantId != null) ...[
          Text(stockVariant(stock), style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.payments_outlined,
              label: 'stock.retail_price'.tr,
              value: stock.retailPrice ?? 'stock.na'.tr),
          AppMetric(
              icon: Icons.sell_outlined,
              label: 'stock.mrp'.tr,
              value: stock.mrp ?? 'stock.na'.tr),
        ]),
        const SizedBox(height: AppSpacing.sm),
        InfoGrid(minColumnWidth: 140, maxColumns: 2, children: [
          if (canViewPurchasePrice)
            InfoRow(
                label: 'stock.purchase_price'.tr,
                value: stock.purchaseRate ?? 'stock.na'.tr),
          InfoRow(label: 'stock.unit'.tr, value: stock.unit ?? 'stock.na'.tr),
          InfoRow(label: 'stock.rack'.tr, value: stock.rack ?? 'stock.na'.tr),
          InfoRow(
              label: 'stock.order_date'.tr,
              value: DateHelper.formatISODate(stock.orderDate ?? '')),
        ]),
        stockBarcode(stock, onCopy),
        const SizedBox(height: AppSpacing.sm),
        actions,
      ]));
}
