import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/screens/print/receipt_line_discount.dart';

import 'order_detail_inputs.dart';
import 'order_detail_table_cell.dart';

class OrderDetailDesktopCartItemsTable extends StatelessWidget {
  const OrderDetailDesktopCartItemsTable(this.currency,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final showDiscount = inputs.data.cartItem?.any(
            (item) => ReceiptLineDiscount.fromItem(item).totalDiscount > 0) ??
        false;
    return Table(
      columnWidths: {
        0: FlexColumnWidth(0.5),
        1: FlexColumnWidth(2.7),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(0.6),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(1.1),
        6: FlexColumnWidth(1.0),
        7: FlexColumnWidth(1.2),
        if (showDiscount) 8: FlexColumnWidth(1.2),
      },
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
          ),
          children: [
            OrderDetailTableCell('Sl#', isHeader: true, inputs: inputs),
            OrderDetailTableCell('DESCRIPTION', isHeader: true, inputs: inputs),
            OrderDetailTableCell('sales_order_details.th_mrp'.tr,
                isHeader: true, align: TextAlign.right, inputs: inputs),
            OrderDetailTableCell('sales_order_details.th_qty'.tr,
                isHeader: true, align: TextAlign.center, inputs: inputs),
            OrderDetailTableCell('sales_order_details.th_unit'.tr,
                isHeader: true, align: TextAlign.center, inputs: inputs),
            OrderDetailTableCell('sales_order_details.th_rate'.tr,
                isHeader: true, align: TextAlign.right, inputs: inputs),
            OrderDetailTableCell('sales_order_details.th_tax'.tr,
                isHeader: true, align: TextAlign.right, inputs: inputs),
            if (showDiscount)
              OrderDetailTableCell('billing.discount_label'.tr,
                  isHeader: true, align: TextAlign.right, inputs: inputs),
            OrderDetailTableCell('sales_order_details.th_amount'.tr,
                isHeader: true, align: TextAlign.right, inputs: inputs),
          ],
        ),
        // Data Rows
        ...List.generate(
          inputs.data.cartItem?.length ?? 0,
          (index) {
            final item = inputs.data.cartItem![index];
            final amounts = ReceiptLineDiscount.fromItem(item);
            return TableRow(
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : Colors.grey.shade50,
              ),
              children: [
                OrderDetailTableCell('${index + 1}',
                    align: TextAlign.center, inputs: inputs),
                OrderDetailTableCell(
                    item.formattedVariantAttributes.isEmpty
                        ? (item.productName ??
                            'sales_order_details.value_na'.tr)
                        : '${item.productName ?? 'sales_order_details.value_na'.tr}\n${item.formattedVariantAttributes}',
                    inputs: inputs),
                OrderDetailTableCell('$currency ${inputs.data.fmt(item.mrp)}',
                    align: TextAlign.right, inputs: inputs),
                OrderDetailTableCell('${inputs.data.fmtQty(item.quantity)}',
                    align: TextAlign.center, inputs: inputs),
                OrderDetailTableCell(inputs.data.unitText(item),
                    align: TextAlign.center, inputs: inputs),
                OrderDetailTableCell(
                    '$currency ${inputs.data.fmt(amounts.originalRate)}',
                    align: TextAlign.right,
                    inputs: inputs),
                OrderDetailTableCell(
                    '$currency ${inputs.data.fmt(item.discountedTaxAmount ?? item.taxAmount)}',
                    align: TextAlign.right,
                    inputs: inputs),
                if (showDiscount)
                  OrderDetailTableCell(
                      '$currency ${inputs.data.fmt(amounts.totalDiscount)}',
                      align: TextAlign.right,
                      inputs: inputs),
                OrderDetailTableCell(
                    '$currency ${inputs.data.fmt(amounts.discountedTotal)}',
                    align: TextAlign.right,
                    inputs: inputs),
              ],
            );
          },
        ),
      ],
    );
  }
}
