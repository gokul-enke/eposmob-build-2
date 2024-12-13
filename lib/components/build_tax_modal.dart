import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

class TaxDetailsDialog extends StatelessWidget {
  final Map<String, num> taxAmounts;

  const TaxDetailsDialog({
    super.key,
    required this.taxAmounts,
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
            ...taxAmounts.entries.map((entry) {
              String taxName = entry.key;
              num amount = entry.value;

              return Text("$taxName: ${AmountHelper.formatAmount(amount)}");
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
