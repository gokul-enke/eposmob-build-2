import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// "Pay with Pine Labs" terminal button + result handling.
/// Extracted verbatim from `billing_tab.dart`'s `_buildPineLabsSection`.
class PineLabsSection extends StatelessWidget {
  const PineLabsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PineLabsTerminalProvider, BillingProvider>(
      builder: (context, terminalProvider, billingProvider, child) {
        final totalAmount = billingProvider.totalOrderAmount;
        final billingRefNo = billingProvider.transactionNumberController.text;
        // Debug: trace state when widget rebuilds (e.g., after loading saved order)
        debugPrint(
            '🧩 [PineLabs UI] pineLabsPaymentSuccess=${billingProvider.pineLabsPaymentSuccess} | methods=${billingProvider.getSelectedPaymentMethods()} | ref=$billingRefNo');

        return CustomRoundButton(
          title: terminalProvider.isProcessing
              ? 'Processing...'
              : billingProvider.pineLabsPaymentSuccess
                  ? 'Paid with Pinelabs  ✓'
                  : 'Pay with Pine Labs',
          fct: () async {
            if (totalAmount <= 0) {
              showScaffoldError(
                context: context,
                message: 'Invalid amount for Pine Labs payment',
              );
              return;
            }

            // reset success state before a new attempt
            billingProvider.setPineLabsPaymentSuccess(false);

            final String resultStr = await terminalProvider.processSale(
              amount: totalAmount,
              billingRefNo: billingRefNo.isEmpty
                  ? 'REF-${DateTime.now().millisecondsSinceEpoch}'
                  : billingRefNo,
            );
            // Prefer parsing the direct result string
            try {
              Map<String, dynamic> decoded = jsonDecode(resultStr);
              final response = decoded['Response'] as Map<String, dynamic>?;
              final dynamic rawCode = response?['ResponseCode'];
              final int code = rawCode is int
                  ? rawCode
                  : int.tryParse(rawCode?.toString() ?? '') ?? -1;
              final String msg = (response?['ResponseMsg'] ?? '').toString();

              if (code == 0) {
                // Extract reference number if available
                final detail = decoded['Detail'] as Map<String, dynamic>?;
                final String ref = (detail?['RetrievalReferenceNumber'] ??
                        detail?['ApprovalCode'] ??
                        detail?['BillingRefNo'] ??
                        '')
                    .toString();

                debugPrint('✅ [PineLabs] Payment SUCCESS');
                debugPrint('📋 [PineLabs] Reference Number: $ref');

                billingProvider.setPineLabsPaymentSuccess(true);

                // Update provider with ONLINE payment and reference number
                debugPrint('💳 [PineLabs] Setting payment method to ONLINE...');
                billingProvider.setPaymentMethod('ONLINE', true);

                debugPrint('🔢 [PineLabs] Setting transaction reference: $ref');
                billingProvider.transactionNumberController.text = ref;

                // Verify the payment method was set
                final selectedMethods =
                    billingProvider.getSelectedPaymentMethodsExcludingEmpty();
                debugPrint(
                    '✔️ [PineLabs] Selected payment methods after setting ONLINE: $selectedMethods');
                debugPrint(
                    '✔️ [PineLabs] isOnlineSelected flag: ${billingProvider.isOnlineSelected}');

                showScaffold(
                  context: context,
                  message:
                      msg.isNotEmpty ? msg : 'Pine Labs payment successful',
                );
              } else {
                billingProvider.setPineLabsPaymentSuccess(false);
                showScaffoldError(
                  context: context,
                  message: msg.isNotEmpty ? msg : 'Pine Labs payment failed',
                );
              }
            } catch (_) {
              // Fallback to simple contains if result is not JSON
              final String normalized = resultStr.toUpperCase();
              final bool isSuccess = normalized.contains('SUCCESS') ||
                  normalized.contains('APPROVED') ||
                  normalized.contains('TXN SUCCESS');
              if (isSuccess) {
                billingProvider.setPineLabsPaymentSuccess(true);
                showScaffold(
                  context: context,
                  message: 'Pine Labs payment successful',
                );
              } else {
                billingProvider.setPineLabsPaymentSuccess(false);
                showScaffoldError(
                  context: context,
                  message: resultStr.isEmpty
                      ? 'Pine Labs payment failed'
                      : resultStr,
                );
              }
            }
          },
          fontSize: 14,
          height: 48,
          width: double.infinity,
          radius: 12,
          boxColor: billingProvider.pineLabsPaymentSuccess
              ? ColorManager.kGreen
              : ColorManager.kPrimaryColor,
          borderColor: billingProvider.pineLabsPaymentSuccess
              ? ColorManager.kGreen
              : ColorManager.kPrimaryColor,
          textColor: Colors.white,
          isLoading: terminalProvider.isProcessing,
        );
      },
    );
  }
}
