import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskPaymentProcessingDialog extends StatelessWidget {
  final String paymentMethodLabel;

  const KioskPaymentProcessingDialog({
    super.key,
    required this.paymentMethodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Processing payment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Waiting for $paymentMethodLabel. Please do not close this screen or remove your card.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ColorManager.kTextColor,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
