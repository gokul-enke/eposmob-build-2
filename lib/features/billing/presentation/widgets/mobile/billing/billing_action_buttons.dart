import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Minimum recommended touch target (WCAG / Material).
const double kBillingMinTouchTarget = 44;

/// Persistent bottom action bar for the mobile Billing tab (Confirm / Confirm & Print).
class BillingActionButtons extends StatelessWidget {
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onConfirmOrder;
  final bool isConfirmingOrder;
  final bool isConfirmingAndPrinting;

  const BillingActionButtons({
    super.key,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onConfirmOrder,
    required this.isConfirmingOrder,
    this.isConfirmingAndPrinting = false,
  });

  bool get _isCheckoutBusy => isConfirmingOrder || isConfirmingAndPrinting;

  @override
  Widget build(BuildContext context) {
    final localProvider = Provider.of<LocalProductProvider>(context);
    final hasItems = localProvider.cartItems.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Confirm Button
          Expanded(
            child: Semantics(
              label: 'Confirm',
              button: true,
              child: ExcludeSemantics(
                child: ElevatedButton.icon(
                icon: isConfirmingOrder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle,
                        color: Colors.white, size: 18),
                label: const Text(
                  'Confirm',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      hasItems ? const Color(0xFF0056B3) : Colors.grey.shade300,
                  minimumSize: const Size(0, kBillingMinTouchTarget),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed:
                    (hasItems && !_isCheckoutBusy) ? onConfirmOrder : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Confirm & Print Button
          Expanded(
            child: Semantics(
              label: 'Confirm & Print',
              button: true,
              child: ExcludeSemantics(
                child: ElevatedButton.icon(
                icon: isConfirmingAndPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.print, color: Colors.white, size: 18),
                label: const Text(
                  'Confirm & Print',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      hasItems ? const Color(0xFF15803D) : Colors.grey.shade300,
                  minimumSize: const Size(0, kBillingMinTouchTarget),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (hasItems && !_isCheckoutBusy)
                    ? onCreateOrderAndPrint
                    : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
