import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

import '../../domain/models/customer_list.dart';
import '../../domain/customer_display.dart';
import '../widgets/customer_labels.dart';

/// Excel export of the customers list.
abstract final class CustomerExcelExport {
  static const mimeType = FileExportService.xlsxMimeType;

  static List<ListExportColumn<CustomerListModelData>> columns() => [
        ListExportColumn(
          label: 'customers.export_col_no'.tr,
          value: (_, index) => index + 1,
        ),
        ListExportColumn(
          label: 'customers.name'.tr,
          value: (customer, _) => CustomerLabels.name(customer.name),
        ),
        ListExportColumn(
          label: 'customers.phone'.tr,
          value: (customer, _) => customer.phone,
        ),
        ListExportColumn(
          label: 'customers.export_col_alt_phone'.tr,
          value: (customer, _) => customer.altPhone,
        ),
        ListExportColumn(
          label: 'customers.email'.tr,
          value: (customer, _) => customer.email,
        ),
        ListExportColumn(
          label: 'customers.export_col_type'.tr,
          value: (customer, _) =>
              CustomerType.parse(customer.customerType).apiValue,
        ),
        ListExportColumn(
          label: 'customers.balance'.tr,
          value: (customer, _) => customer.balance ?? 0,
        ),
      ];

  /// Writes [customers] to an `.xlsx` file.
  static Future<File> createFile(
    List<CustomerListModelData> customers, {
    Directory? outputDirectory,
  }) {
    return ListExcelExportService.export<CustomerListModelData>(
      items: customers,
      columns: columns(),
      fileNamePrefix: 'customers',
      sheetName: 'customers.title'.tr,
      outputDirectory: outputDirectory,
    );
  }

  /// Writes [customers] to a file and hands it to the user (Save As on
  /// Windows, the share sheet elsewhere).
  static Future<void> exportAndShare(
    BuildContext context,
    List<CustomerListModelData> customers,
  ) async {
    final file = await createFile(customers);
    if (!context.mounted) return;
    await FileExportService.deliver(
      context,
      file,
      mimeType: mimeType,
      shareText: 'customers.export_share_text'.tr,
    );
  }
}
