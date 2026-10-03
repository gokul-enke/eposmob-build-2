import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/supplier_voucher.dart';

Future<File> exportSupplierVouchers(
    List<SupplierVoucher> items, String currency) {
  return ListExcelExportService.export<SupplierVoucher>(
    items: items,
    fileNamePrefix: 'supplier-vouchers',
    sheetName: 'supplier_voucher.mobile_header_title'.tr,
    columns: [
      ListExportColumn(
          label: 'supplier_voucher.col_voucher_number'.tr,
          value: (v, _) => v.voucherNumber),
      ListExportColumn(
          label: 'supplier_voucher.col_supplier_name'.tr,
          value: (v, _) => v.supplier.name),
      ListExportColumn(
          label: 'supplier_voucher.col_type'.tr,
          value: (v, _) => UiCodeLabels.voucherType(v.type)),
      ListExportColumn(
          label: 'supplier_voucher.col_voucher_date'.tr,
          value: (v, _) => v.voucherDate),
      ListExportColumn(
          label: 'supplier_voucher.col_due_date'.tr,
          value: (v, _) => v.dueDate),
      ListExportColumn(
          label: 'supplier_voucher.col_payment_method'.tr,
          value: (v, _) => UiCodeLabels.payment(v.paymentMethod)),
      ListExportColumn(
          label: 'supplier_voucher.col_paid_amount'.tr,
          value: (v, _) => ListExcelExportService.numericValue(v.amount)),
      ListExportColumn(
          label: 'supplier_transactions.currency'.tr,
          value: (_, __) => currency),
      ListExportColumn(
          label: 'supplier_voucher.col_status'.tr,
          value: (v, _) => UiCodeLabels.status(v.status)),
    ],
  );
}
