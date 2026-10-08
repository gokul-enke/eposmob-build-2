import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import 'sales_page_services.dart';

Future<void> showSalesWindowsSharing(BuildContext context,
    SalesPageServices services, File pdfFile, ListOrderModelData order) async {
  if (context.mounted) {
    // Show dialog with multiple options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red[700]),
            const SizedBox(width: 8),
            Text('sales.title_pdf_ready'.tr),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'sales.label_invoice'.tr} ${order.orderNumber}'),
            const SizedBox(height: 8),
            Text('${'sales.label_file'.tr} ${pdfFile.path.split('/').last}'),
            const SizedBox(height: 16),
            Text(
              'sales.label_choose_share_pdf'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Option 1: Open file location
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                // Open file explorer to the file location
                await Process.start(
                  'explorer.exe',
                  ['/select,', pdfFile.path.replaceAll('/', '\\')],
                  mode: ProcessStartMode.detached,
                );
                if (!context.mounted) return;

                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: 'sales.file_location_opened'.tr,
                  );
                }
              } catch (e) {}
            },
            icon: const Icon(Icons.folder_open),
            label: Text('sales.btn_open_file_location'.tr),
          ),
          // Option 2: Open PDF directly
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Process.start(
                  'cmd',
                  ['/c', 'start', '""', pdfFile.path],
                  mode: ProcessStartMode.detached,
                );
                if (!context.mounted) return;

                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: 'sales.pdf_opened'.tr,
                  );
                }
              } catch (e) {}
            },
            icon: const Icon(Icons.open_in_new),
            label: Text('sales.btn_open_pdf'.tr),
          ),
          // Option 3: Copy path
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Clipboard.setData(ClipboardData(text: pdfFile.path));
                if (!context.mounted) return;

                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: 'sales.file_path_copied'.tr,
                  );
                }
              } catch (e) {}
            },
            icon: const Icon(Icons.copy),
            label: Text('sales.btn_copy_path'.tr),
          ),
        ],
      ),
    );
  }
}
