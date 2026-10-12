import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

import '../../domain/proforma_list_query.dart';
import '../../domain/proforma_details.dart';

/// Passive view of the existing details response. It performs no API requests.
class ProformaDetailsDialog extends StatelessWidget {
  const ProformaDetailsDialog({super.key, required this.details});

  final ProformaDetails details;
  @override
  Widget build(BuildContext context) {
    final data = details.invoice;
    final customer = details.customer;
    final quotation = details.quotation;
    final items = details.items;

    return CommonDetailsDialog(
      title: 'proforma_invoice.details_title'.tr,
      gridColumns: [
        [
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.invoice_number_label'.tr,
              proformaText(data['invoice_number']),
              copyable: true),
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.status_label'.tr,
              UiCodeLabels.status(proformaText(data['status']))),
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.field_amount'.tr, proformaText(data['amount'])),
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.field_invoice_date'.tr,
              proformaText(data['invoice_date'])),
        ],
        [
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.field_due_date'.tr,
              proformaText(data['due_date'])),
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.customer_label'.tr,
              proformaText(customer['name'])),
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.field_phone'.tr,
              proformaText(customer['phone']),
              copyable: true),
          CommonDetailsDialog.buildKeyValueRow(
              'proforma_invoice.field_quotation_number'.tr,
              proformaText(quotation['quotation_number'])),
        ],
      ],
      sectionTitle: 'proforma_invoice.items_title'.tr,
      tableContent: items.isEmpty
          ? Center(child: Text('proforma_invoice.no_items_found'.tr))
          : Table(
              columnWidths: const {
                0: FlexColumnWidth(2.4),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
              },
              children: [
                _detailsHeaderRow(),
                ...items.map((item) {
                  final row = proformaMap(item);
                  return TableRow(
                    children: [
                      _dialogCell(proformaText(row['item_name'])),
                      _dialogCell(proformaText(row['quantity'])),
                      _dialogCell(proformaText(row['unit_amount'])),
                      _dialogCell(proformaText(row['total_amount'])),
                    ],
                  );
                }),
              ],
            ),
    );
  }

  TableRow _detailsHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _StaticTableCell('proforma_invoice.col_item'.tr),
        _StaticTableCell('proforma_invoice.col_qty'.tr),
        _StaticTableCell('proforma_invoice.col_unit_amount'.tr),
        _StaticTableCell('proforma_invoice.col_total'.tr),
      ],
    );
  }

  Widget _dialogCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

class _StaticTableCell extends StatelessWidget {
  final String text;

  const _StaticTableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }
}
