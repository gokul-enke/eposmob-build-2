import 'dart:convert'; // Added for json.decode
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'local_order_detail_info_row.dart';
import 'local_order_detail_inputs.dart';

class LocalOrderPaymentInfo extends StatelessWidget {
  const LocalOrderPaymentInfo(this.paymentMethodJsonOrString, this.currency,
      {super.key, required this.inputs});
  final LocalOrderDetailInputs inputs;
  final String paymentMethodJsonOrString;
  final String currency;
  @override
  Widget build(BuildContext context) {
    try {
      if (paymentMethodJsonOrString.startsWith('{') &&
          paymentMethodJsonOrString.endsWith('}')) {
        final Map<String, dynamic> multiPaymentData =
            json.decode(paymentMethodJsonOrString);
        if (multiPaymentData['isMultiPayment'] == true) {
          final Map<String, dynamic> amounts =
              Map<String, dynamic>.from(multiPaymentData['amounts'] ?? {});

          List<Widget> methodWidgets = [];
          double totalPaid = 0.0;

          amounts.forEach((method, amount) {
            double amountValue = double.tryParse(amount.toString()) ?? 0.0;
            if (amountValue > 0) {
              // Convert method ID/name to display name
              String displayName = inputs.methodLabel(method);
              // DEBIT is a customer-credit allocation, not money collected.
              // Show it in the list, but don't include it in Total Paid.
              final isDebitCredit = displayName.toUpperCase() == 'DEBIT';
              if (!isDebitCredit) {
                totalPaid += amountValue;
              }
              methodWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                  child: LocalOrderDetailInfoRow(
                      'confirmed_orders.payment_display'
                          .tr
                          .replaceAll('@name', displayName),
                      "$currency${amountValue.toStringAsFixed(2)}",
                      valueStyle: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                      inputs: inputs),
                ),
              );
            }
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "billing.payment_methods".tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              ...methodWidgets,
              const SizedBox(height: 8),
              LocalOrderDetailInfoRow("billing.total_paid".tr,
                  "$currency${totalPaid.toStringAsFixed(2)}",
                  valueStyle: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  inputs: inputs),
            ],
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing payment method JSON: $e");
    }
    // Fallback for single payment method or parsing error
    // Convert ID to display name if needed
    String displayName = inputs.methodLabel(paymentMethodJsonOrString);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "confirmed_orders.payment_method".tr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        LocalOrderDetailInfoRow("confirmed_orders.method".tr, displayName,
            valueStyle: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
            inputs: inputs),
      ],
    );
  }
}
