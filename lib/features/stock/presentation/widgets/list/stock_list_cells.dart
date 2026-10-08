import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_stock.dart';

Widget stockQuantity(ListStockModelData stock) => AppBadge(
    label: '${stock.qty}',
    tone: switch (stock.stockStatus) {
      'Out of Stock' => AppBadgeTone.danger,
      'Low Stock' || 'At Reorder Level' => AppBadgeTone.warning,
      _ => AppBadgeTone.neutral,
    });
String stockVariant(ListStockModelData stock) =>
    stock.variantName?.trim().isNotEmpty == true
        ? stock.variantName!
        : 'stock.list_variant'.trParams({'id': '${stock.productVariantId}'});
Widget stockBarcode(ListStockModelData stock, VoidCallback onCopy) =>
    Row(children: [
      Expanded(
          child: Text(stock.barCode ?? 'stock.na'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.input)),
      if (stock.barCode?.isNotEmpty == true && stock.barCode != 'stock.na'.tr)
        AppSquareIconButton(
            icon: Icons.copy_outlined,
            iconSize: 16,
            size: AppSizes.compactControl,
            tooltip: 'stock.list_copy_barcode'.tr,
            onPressed: onCopy),
    ]);
