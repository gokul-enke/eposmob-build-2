import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:intl/intl.dart';

class ReceiptPreviewWidget extends StatelessWidget {
  final double paperWidth;
  final double scaleFactor;

  const ReceiptPreviewWidget({super.key, 
    this.paperWidth = 80, // Default to 80mm paper width
    this.scaleFactor = 2.5, // Adjust this to change the size of the preview
  });

  @override
  Widget build(BuildContext context) {
    // Convert mm to logical pixels
    final widthInPixels = paperWidth * scaleFactor;

    return Scaffold(
      appBar: AppBar(
        title: Text('ui_chrome.receipt_preview'.tr),
      ),
      body: Center(
        child: Container(
          width: widthInPixels,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Dummy Thermal Receipt',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Thank you for your purchase!',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Date: ${DateHelper.getCurrentFormattedTimeWithAMPM()}',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const ReceiptItem('Item 1', 10.00),
                  const ReceiptItem('Item 2', 15.00),
                  const ReceiptItem('Item 3', 20.00),
                  const Divider(),
                  const ReceiptItem('Total:', 45.00, isTotal: true),
                  const SizedBox(height: 8),
                  const Text(
                    'Have a great day!',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16), // Space for tear-off
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.print),
        onPressed: () {
          // TODO: Implement actual printing logic
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printing...')),
          );
        },
      ),
    );
  }
}

class ReceiptItem extends StatelessWidget {
  final String name;
  final double price;
  final bool isTotal;

  const ReceiptItem(this.name, this.price, {super.key, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text('\$${price.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
