import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/print_service.dart';

void printConfirmedSaleDetail(BuildContext context, SavedOrder order) async {
  try {
    await const PrintService().printSavedOrder(context, order);
    return;
  } catch (error) {
    debugPrint("Error printing order: ${error.toString()}");
    if (!context.mounted) return;
    AppToast.error(context, "confirmed_orders.failed_print".tr);
  }
}
