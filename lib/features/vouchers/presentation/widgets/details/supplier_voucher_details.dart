import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';
import '../../../domain/models/supplier_voucher.dart';

class SupplierVoucherDetails {
  SupplierVoucherDetails(this.context, this.currency);
  final BuildContext context;
  final String currency;
  void show(SupplierVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'supplier_voucher.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_voucher_number'.tr, voucher.voucherNumber,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_supplier_name'.tr, voucher.supplier.name),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.field_supplier_phone'.tr,
                voucher.supplier.phone,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_type'.tr,
                UiCodeLabels.voucherType(voucher.type)),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_voucher_date'.tr, voucher.voucherDate),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_due_date'.tr, voucher.dueDate),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_status'.tr, voucher.status),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_payment_method'.tr,
                UiCodeLabels.payment(voucher.paymentMethod)),
          ],
        ],
        sectionTitle: 'supplier_voucher.items_section_title'.tr,
        tableContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: ColorManager.tableBGColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    children: [
                      _buildTableHeaderCell('supplier_voucher.col_voucher'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_item_name'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_quantity_upper'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_unit_amount_upper'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_tax_upper'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_total_amount_upper'.tr),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Table Body
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1.5),
              },
              children: voucher.items.asMap().entries.map((entry) {
                final item = entry.value;
                final index = entry.key;
                return TableRow(
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? Colors.white
                        : Colors.grey.withValues(alpha: 0.05),
                  ),
                  children: [
                    _buildTableBodyCell(voucher.voucherNumber),
                    _buildTableBodyCell(item.itemName),
                    _buildTableBodyCell(item.quantity),
                    _buildTableBodyCell(item.unitAmount),
                    _buildTableBodyCell(item.tax),
                    _buildTableBodyCell(item.totalAmount),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
        totalsContent: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'supplier_voucher.grand_total_label'.tr,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.27,
                  Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$currency ${voucher.amount}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s18,
                  0.27,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }

  Widget _buildTableBodyCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.15,
          Colors.black,
        ),
      ),
    );
  }
}
