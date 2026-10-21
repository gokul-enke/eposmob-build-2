import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/invoice_details.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

class InvoiceDetailsDialog extends StatelessWidget {
  const InvoiceDetailsDialog({super.key, required this.details});
  final InvoiceDetails details;

  @override
  Widget build(BuildContext context) => CommonDetailsDialog(
        title: 'invoice.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_invoice_number'.tr, details.invoiceNumber,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_customer_name'.tr, details.customer.name),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_customer_phone'.tr, details.customer.phone,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_amount'.tr, details.amount),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_type'.tr, details.type),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_invoice_date'.tr, details.invoiceDate),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_due_date'.tr, details.dueDate),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_status'.tr, details.status),
            CommonDetailsDialog.buildKeyValueRow(
                'invoice.field_order_number'.tr, 'common_details_dialog.na'.tr),
          ],
        ],
        sectionTitle: 'invoice.items_title'.tr,
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
                    flex: 4,
                    child: Text(
                      'invoice.col_item'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeightManager.bold,
                        fontSize: FontSize.s12,
                        color: ColorManager.kTitleTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'invoice.col_quantity'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeightManager.bold,
                        fontSize: FontSize.s12,
                        color: ColorManager.kTitleTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'invoice.col_price'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeightManager.bold,
                        fontSize: FontSize.s12,
                        color: ColorManager.kTitleTextColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'invoice.col_total'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeightManager.bold,
                        fontSize: FontSize.s12,
                        color: ColorManager.kTitleTextColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            ...details.invoiceItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        item.itemName,
                        style: const TextStyle(
                          fontSize: FontSize.s12,
                          color: ColorManager.textColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.displayQuantity,
                        style: const TextStyle(
                          fontSize: FontSize.s12,
                          color: ColorManager.textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.unitAmount,
                        style: const TextStyle(
                          fontSize: FontSize.s12,
                          color: ColorManager.textColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.totalAmount,
                        style: const TextStyle(
                          fontSize: FontSize.s12,
                          color: ColorManager.textColor,
                        ),
                        textAlign: TextAlign.right,
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
