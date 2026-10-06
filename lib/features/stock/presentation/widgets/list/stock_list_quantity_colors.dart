import 'package:flutter/material.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/resources/color_manager.dart';

(Color?, Color?) stockListQuantityColors(ListStockModelData stock) {
  if (stock.stockStatus == 'Out of Stock') {
    return (Colors.white, ColorManager.kRed);
  }
  if (stock.stockStatus == 'Low Stock') {
    return (Colors.white, ColorManager.kOrange);
  }
  if (stock.stockStatus == 'At Reorder Level') {
    return (Colors.white, ColorManager.kButtonYellow);
  }
  return (null, null);
}
