import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';

Future<void> handleDetailWindowsSharing(
    BuildContext context,
    SalesOrderDetailController controller,
    SalesPageServices services,
    File pdfFile) async {
  final orderNumber = controller.orderNumber;

  if (context.mounted) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red),
            const SizedBox(width: 8),
            Text('sales_order_details.title_pdf_ready'.tr),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'sales_order_details.label_invoice'.tr} $orderNumber'),
            const SizedBox(height: 8),
            Text(
                '${'sales_order_details.label_file'.tr} ${pdfFile.path.split('/').last}'),
            const SizedBox(height: 16),
            Text(
              'sales_order_details.label_choose_share'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Process.start(
                  'explorer.exe',
                  ['/select,', pdfFile.path.replaceAll('/', '\\')],
                  mode: ProcessStartMode.detached,
                );
                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: 'sales_order_details.msg_file_location_opened'.tr,
                  );
                }
              } catch (e) {
                debugPrint('Error opening file location: $e');
              }
            },
            icon: const Icon(Icons.folder_open),
            label: Text('sales_order_details.btn_open_file_location'.tr),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Process.start(
                  'cmd',
                  ['/c', 'start', '""', pdfFile.path],
                  mode: ProcessStartMode.detached,
                );
                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: 'sales_order_details.msg_pdf_opened'.tr,
                  );
                }
              } catch (e) {
                debugPrint('Error opening PDF: $e');
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: Text('sales_order_details.btn_open_pdf'.tr),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Clipboard.setData(ClipboardData(text: pdfFile.path));
                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: 'sales_order_details.msg_path_copied'.tr,
                  );
                }
              } catch (e) {
                debugPrint('Error copying to clipboard: $e');
              }
            },
            icon: const Icon(Icons.copy),
            label: Text('sales_order_details.btn_copy_path'.tr),
          ),
        ],
      ),
    );
  }
}
