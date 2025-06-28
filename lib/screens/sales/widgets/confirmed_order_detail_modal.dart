import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ConfirmedOrderDetailModal extends StatelessWidget {
  final SavedOrder order;

  const ConfirmedOrderDetailModal({Key? key, required this.order})
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
            maxWidth: 700, maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                  "Order Details",
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
                    _buildInfoRow("Order Number", "#${order.orderNumber}"),
                    const SizedBox(height: 8),
                    _buildInfoRow("Customer Phone", order.customerPhone ?? "N/A"),
                    const SizedBox(height: 8),
                    _buildInfoRow("Date", _formatDateTime(order.createdAt)),
                    const SizedBox(height: 8),
                    _buildInfoRow("Time", _formatTime(order.createdAt)),
                    const SizedBox(height: 8),
                    _buildInfoRow("Total Amount", "₹${order.total.toStringAsFixed(2)}"),
                    if (order.comment != null && order.comment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow("Comment", order.comment!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order Items Section
            const Text(
              "Order Items",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Table with order items
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
                        DataColumn(label: Text('Unit Price'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                      ],
                      rows: order.items.map((item) {
                        double unitPrice = item.price ?? item.product.price?.price ?? 0.0;
                        double totalPrice = unitPrice * item.quantity;
                        
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
                            "₹${unitPrice.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.black),
                          )),
                          DataCell(Text(
                            "₹${totalPrice.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.black,
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
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomRoundButton(
                  fct: () => _printOrder(context),
                  title: "Print Order",
                  fontSize: FontSize.s12,
                  height: MediaQuery.of(context).size.height * .05,
                  width: 120,
                  boxColor: ColorManager.kPrimaryColor,
                  textColor: Colors.white,
                ),
                Row(
                  children: [
                    CustomRoundButton(
                      fct: () => _showDeleteConfirmationDialog(context),
                      title: "Delete",
                      fontSize: FontSize.s12,
                      height: MediaQuery.of(context).size.height * .05,
                      width: 80,
                      boxColor: ColorManager.kButtonRed,
                      borderColor: ColorManager.kButtonRed,
                      textColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    CustomRoundButton(
                      fct: () => Navigator.of(context).pop(),
                      title: "Close",
                      fontSize: FontSize.s12,
                      height: MediaQuery.of(context).size.height * .05,
                      width: 80,
                      boxColor: Colors.grey[300],
                      textColor: Colors.black,
                    ),
                  ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$label:",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String isoDateString) {
    final DateTime dateTime = DateTime.parse(isoDateString);
    final DateFormat formatter = DateFormat('MMM dd, yyyy');
    return formatter.format(dateTime);
  }

  String _formatTime(String isoDateString) {
    final DateTime dateTime = DateTime.parse(isoDateString);
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(dateTime);
  }

  void _printOrder(BuildContext context) {
    try {
      // Convert SavedOrder items to the format expected by PrintPage
      List<Map<String, dynamic>> cartItems = [];

      for (var item in order.items) {
        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': (item.product.mrp?.toString() ?? '0.00'),
          'quantity': item.quantity.toString(),
          'unitPrice': (item.price?.toString() ??
              item.product.price?.price?.toString() ??
              '0.00'),
          'totalPrice': ((item.price ?? (item.product.price?.price ?? 0.0)) *
                  item.quantity)
              .toString(),
        });
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: "SOUQ POINT",
            cartItems: cartItems,
            formattedTotal: order.total.toString(),
            savedTotal: "0.00", // Adjust if you track discounts
            orderDate: order.createdAt,
            orderNumber: order.orderNumber,
            isFromLocalStorage: true,
          ),
        ),
      );
    } catch (error) {
      debugPrint("Error printing order: ${error.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to print order. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    DeleteConfirmationDialog.show(
      context: context,
      title: "Delete Confirmed Order",
      itemName: order.orderNumber,
      message: "This confirmed order will be permanently removed from your local storage. This action cannot be undone.",
      warningIcon: Icons.receipt_long_outlined,
      warningIconColor: ColorManager.kButtonRed,
      deleteButtonText: "Delete",
      onDelete: () {
        // Delete the confirmed order from local storage
        final provider = Provider.of<LocalProductProvider>(context, listen: false);
        provider.deleteConfirmedOrder(order.id);

        // Close the modal first
        Navigator.of(context).pop();

        // Show success message
        showScaffold(
          context: context,
          message: "Confirmed order deleted successfully",
        );
      },
    );
  }
} 