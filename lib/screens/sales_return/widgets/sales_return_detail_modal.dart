import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/resources/font_manager.dart';

class SalesReturnDetailModal extends StatelessWidget {
  final SalesReturnOrder order;

  const SalesReturnDetailModal({Key? key, required this.order})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Return Details",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order Information Card
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Order Information",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow("Order Number", "#${order.orderId}"),
                    const SizedBox(height: 8),
                    _buildInfoRow("Customer", "Sales Executive"),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        "Date", DateTime.now().toString().split(' ')[0]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Return Items Section
            const Text(
              "Return Items",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Table with return items
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
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
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('Reason')),
                      ],
                      rows: order.items.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(
                            item.cartItem.product.name,
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
                            item.price,
                            style: const TextStyle(color: Colors.black),
                          )),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                item.reason,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButton(
                  fct: () => Navigator.of(context).pop(),
                  title: "Close",
                  fontSize: FontSize.s12,
                  height: MediaQuery.of(context).size.height * .05,
                  width: 60,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
