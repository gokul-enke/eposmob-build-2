import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'local_order_detail_inputs.dart';

class LocalOrderItemsTable extends StatelessWidget {
  const LocalOrderItemsTable({super.key, required this.inputs});
  final LocalOrderDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    final order = inputs.order;
    final currency = inputs.currency;
    const cellStyle = TextStyle(
      color: Color(0xFF334155),
      fontSize: 13.5,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // Fill the dialog width, but scroll sideways on narrow screens
        // instead of clipping the totals column.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor:
                    const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                headingRowHeight: 42,
                dividerThickness: 0.6,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
                dataTextStyle: cellStyle,
                horizontalMargin: 16,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text('confirmed_orders.product'.tr)),
                  DataColumn(
                      label: Text('billing.table_qty'.tr), numeric: true),
                  DataColumn(
                      label: Text('billing.unit_price'.tr), numeric: true),
                  DataColumn(
                      label: Text('billing.table_total'.tr), numeric: true),
                ],
                rows: order.items.map((item) {
                  double unitPrice =
                      item.price ?? item.product.price?.price ?? 0.0;
                  double totalPrice = item.amounts.total;

                  return DataRow(cells: [
                    DataCell(Text(
                      item.product.productName ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    )),
                    DataCell(Text(item.quantity.toString())),
                    DataCell(Text("$currency ${unitPrice.toStringAsFixed(2)}")),
                    DataCell(Text(
                      "$currency ${totalPrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
