import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

/// Read-only presentation of the receipt supplied by the list.
class ReceiptDetailsDialog extends StatelessWidget {
  const ReceiptDetailsDialog({super.key, required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) => CommonDetailsDialog(
        title: 'receipt.receipt_details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_receipt_number'.tr, receipt.receiptNumber,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_customer'.tr, receipt.customer.user.name),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_amount'.tr, receipt.amount),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_company'.tr, receipt.company.name),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_status'.tr, receipt.receiptStatus),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_payment_reference'.tr, receipt.paymentReference),
          ],
        ],
        sectionTitle: 'receipt.payments_section_title'.tr,
        tableContent: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt.col_date'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt.col_invoice'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'receipt.col_method'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'receipt.field_amount'.tr,
                      textAlign: TextAlign.right,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            ...receipt.receiptPayments.map((p) {
              final dateStr = DateHelper.formatDate(
                DateTime.tryParse(p.paymentDate) ?? receipt.createdAt,
              );
              final invStr = p.invoiceId != null
                  ? 'INV-${p.invoiceId}'
                  : (p.description?.isNotEmpty == true
                      ? p.description!
                      : 'receipt.type_general_payment'.tr);
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        dateStr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        invStr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.paymentMethod,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.paidAmount,
                        textAlign: TextAlign.right,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
}
