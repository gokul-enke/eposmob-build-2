import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:provider/provider.dart';

class TaxDetailsDialog extends StatelessWidget {
  final List<dynamic> cartItems;
  final List<String> taxNames;

  const TaxDetailsDialog({
    super.key,
    required this.cartItems,
    required this.taxNames,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tax Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...taxNames.asMap().entries.map((entry) {
              int index = entry.key;
              String taxName = entry.value;

              debugPrint(
                  "cartItems Tax ${cartItems[index].taxAmount * cartItems[index].quantity}");

              int taxRate =
                  cartItems[index].taxAmount * cartItems[index].quantity;

              return Text("$taxName: ${AmountHelper.formatAmount(taxRate)}");
            }).toList(),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
