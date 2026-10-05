import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/customer_voucher.dart';

Future<File> exportCustomerVouchers(
    List<CustomerVoucher> items, String currency) {
  return ListExcelExportService.export<CustomerVoucher>(
      items: items,
      fileNamePrefix: 'customer-vouchers',
      sheetName: 'customer_voucher.list_title'.tr,
      columns: [
        ListExportColumn(
            label: 'customer_voucher.col_voucher_number'.tr,
            value: (v, _) => v.voucherNumber),
        ListExportColumn(
            label: 'customer_voucher.col_customer_name'.tr,
            value: (v, _) => v.customer.user.name),
        ListExportColumn(
            label: 'customer_voucher.col_type'.tr,
            value: (v, _) => UiCodeLabels.voucherType(v.type)),
        ListExportColumn(
            label: 'customer_voucher.col_voucher_date'.tr,
            value: (v, _) => v.voucherDate),
        ListExportColumn(
            label: 'customer_voucher.col_due_date'.tr,
            value: (v, _) => v.dueDate),
        ListExportColumn(
            label: 'customer_voucher.col_payment_method'.tr,
            value: (v, _) => UiCodeLabels.payment(v.paymentMethod)),
        ListExportColumn(
            label: 'customer_voucher.col_paid_amount'.tr,
            value: (v, _) => ListExcelExportService.numericValue(v.amount)),
        ListExportColumn(
            label: 'supplier_transactions.currency'.tr,
            value: (_, __) => currency),
        ListExportColumn(
            label: 'customer_voucher.col_status'.tr,
            value: (v, _) => UiCodeLabels.status(v.status)),
      ]);
}
