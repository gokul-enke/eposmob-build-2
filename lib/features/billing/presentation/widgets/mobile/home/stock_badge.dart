import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';
import 'package:pos_machine/resources/color_manager.dart';

class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final ProductStockDisplayStatus status;
  final bool compact;

  String get _label {
    switch (status) {
      case ProductStockDisplayStatus.available:
        return 'stock.status_available'.tr;
      case ProductStockDisplayStatus.lowStock:
        return 'stock.status_low_stock'.tr;
      case ProductStockDisplayStatus.atReorderLevel:
        return 'stock.status_at_reorder_level'.tr;
      case ProductStockDisplayStatus.outOfStock:
        return 'stock.status_out_of_stock'.tr;
    }
  }

  String get _compactLabel {
    switch (status) {
      case ProductStockDisplayStatus.available:
        return 'stock.status_in_short'.tr;
      case ProductStockDisplayStatus.lowStock:
      case ProductStockDisplayStatus.atReorderLevel:
        return 'stock.status_low_short'.tr;
      case ProductStockDisplayStatus.outOfStock:
        return 'stock.status_out_short'.tr;
    }
  }

  Color get _backgroundColor {
    switch (status) {
      case ProductStockDisplayStatus.available:
        return Colors.green;
      case ProductStockDisplayStatus.lowStock:
        return ColorManager.kOrange;
      case ProductStockDisplayStatus.atReorderLevel:
        return ColorManager.kButtonYellow;
      case ProductStockDisplayStatus.outOfStock:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        compact ? _compactLabel : _label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: status == ProductStockDisplayStatus.atReorderLevel
              ? Colors.black87
              : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 8 : 9,
        ),
      ),
    );
  }
}
