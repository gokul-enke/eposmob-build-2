import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/product/widgets/stock_responsive.dart';
import 'stock_list_compact_value.dart';
import 'stock_list_quantity_colors.dart';

class StockListMobileCard extends StatelessWidget {
  final ListStockModelData stock;
  final bool variantEnabled;
  final Widget actions;
  const StockListMobileCard(
      {super.key,
      required this.stock,
      required this.variantEnabled,
      required this.actions});
  @override
  Widget build(BuildContext context) {
    final barcode = stock.barCode ?? 'stock.na'.tr;
    final qtyColors = stockListQuantityColors(stock);
    final orderDate = DateHelper.formatISODate(stock.orderDate ?? '');

    return StockContentCard(
      padding: const EdgeInsetsDirectional.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      stock.productName ?? 'stock.unnamed'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.20,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    if (variantEnabled && stock.productVariantId != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        stock.variantName?.trim().isNotEmpty == true
                            ? stock.variantName!
                            : 'Variant #${stock.productVariantId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s11,
                          0.15,
                          Colors.deepPurple.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${stock.categoryName ?? ''}${(stock.categoryName ?? '').isNotEmpty && (stock.storeName ?? '').isNotEmpty ? ' · ' : ''}${stock.storeName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.15,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              actions,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _compactValue(
                  label: 'stock.retail_short'.tr,
                  value: '${stock.retailPrice ?? 'stock.na'.tr}',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _compactValue(
                  label: 'stock.qty_short'.tr,
                  value: '${stock.qty}',
                  valueColor: qtyColors.$1,
                  valueBgColor: qtyColors.$2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _compactValue(
                  label: 'stock.barcode'.tr,
                  value: barcode,
                  copyable: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _compactValue(
                  label: 'stock.order_date'.tr,
                  value: orderDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactValue(
          {required String label,
          required String value,
          Color? valueColor,
          Color? valueBgColor,
          bool copyable = false}) =>
      StockListCompactValue(
          label: label,
          value: value,
          valueColor: valueColor,
          valueBgColor: valueBgColor,
          copyable: copyable);
}
