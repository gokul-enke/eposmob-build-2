import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

void deleteConfirmedSaleDetail(BuildContext context, SavedOrder order,
    LocalProductProvider provider, LocalSaleSyncService saleSync) {
  DeleteConfirmationDialog.show(
    context: context,
    title: "confirmed_orders.delete_title".tr,
    itemName: order.orderNumber,
    message: "confirmed_orders.delete_message".tr,
    warningIcon: Icons.receipt_long_outlined,
    warningIconColor: ColorManager.kButtonRed,
    deleteButtonText: "confirmed_orders.delete".tr,
    onDelete: () async {
      // Delete the confirmed order from local storage

      await saleSync.remove(order.id);
      provider.deleteConfirmedOrder(order.id);
      await provider.flushPersistence();
      if (!context.mounted) return;

      // Close the modal first
      Navigator.of(context).pop();

      // Show success message
      showScaffold(
        context: context,
        message: "confirmed_orders.delete_success".tr,
      );
    },
  );
}
