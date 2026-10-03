import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

import '../../domain/models/supplier.dart';

/// Excel export of the suppliers list.
abstract final class SupplierExcelExport {
  static List<ListExportColumn<Supplier>> columns() => [
        ListExportColumn(
          label: 'suppliers.number'.tr,
          value: (_, index) => index + 1,
        ),
        ListExportColumn(
          label: 'suppliers.name'.tr,
          value: (supplier, _) => supplier.name,
        ),
        ListExportColumn(
          label: 'suppliers.email'.tr,
          value: (supplier, _) => supplier.email,
        ),
        ListExportColumn(
          label: 'suppliers.phone'.tr,
          value: (supplier, _) => supplier.phone,
        ),
        ListExportColumn(
          label: 'suppliers.address'.tr,
          value: (supplier, _) => supplier.address,
        ),
        ListExportColumn(
          label: 'suppliers.current_balance'.tr,
          value: (supplier, _) => supplier.currentBalance,
        ),
      ];

  /// Writes [suppliers] to an `.xlsx` file.
  static Future<File> createFile(
    List<Supplier> suppliers, {
    Directory? outputDirectory,
  }) =>
      ListExcelExportService.export<Supplier>(
        items: suppliers,
        columns: columns(),
        fileNamePrefix: 'suppliers',
        sheetName: 'suppliers.list'.tr,
        outputDirectory: outputDirectory,
      );
}
