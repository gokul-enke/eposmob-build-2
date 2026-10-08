import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/print_service.dart';

import 'local_sales_services.dart';

void printLocalSale(
    BuildContext context, SavedOrder order, LocalSalesServices services) async {
  try {
    await const PrintService().printSavedOrder(context, order);
    return;
  } catch (error) {
    debugPrint("Error printing order: ${error.toString()}");
    if (!context.mounted) return;
    showScaffoldError(
        context: context, message: "confirmed_orders.failed_print".tr);
  }
}
