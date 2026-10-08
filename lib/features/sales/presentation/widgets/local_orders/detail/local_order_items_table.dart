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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          dataTextStyle: const TextStyle(
            color: Colors.black,
          ),
          horizontalMargin: 16,
          columnSpacing: 24,
          columns: [
            DataColumn(label: Text('confirmed_orders.product'.tr)),
            DataColumn(label: Text('billing.table_qty'.tr), numeric: true),
            DataColumn(label: Text('billing.unit_price'.tr), numeric: true),
            DataColumn(label: Text('billing.table_total'.tr), numeric: true),
          ],
          rows: order.items.map((item) {
            double unitPrice = item.price ?? item.product.price?.price ?? 0.0;
            double totalPrice = item.amounts.total;

            return DataRow(cells: [
              DataCell(Text(
                item.product.productName ?? 'Unknown Product',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              )),
              DataCell(Text(
                item.quantity.toString(),
                style: const TextStyle(color: Colors.black),
              )),
              DataCell(Text(
                "$currency${unitPrice.toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.black),
              )),
              DataCell(Text(
                "$currency${totalPrice.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
