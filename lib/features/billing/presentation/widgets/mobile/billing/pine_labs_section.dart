import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// "Pay with Pine Labs" terminal button. All terminal-response interpretation
/// and billing-state mutation lives in `BillingMobilePaymentController` —
/// this widget only wires the tap and renders the result.
class PineLabsSection extends StatelessWidget {
  const PineLabsSection({super.key});

  static const _controller = BillingMobilePaymentController();

  @override
  Widget build(BuildContext context) {
    return Consumer2<PineLabsTerminalProvider, BillingProvider>(
      builder: (context, terminalProvider, billingProvider, child) {
        billingDebugLog(
            '[PineLabs] success=${billingProvider.pineLabsPaymentSuccess} | online=${billingProvider.isOnlineSelected}');

        return Semantics(
          label: 'billing.pay_with_pine_labs'.tr,
          button: true,
          child: CustomRoundButton(
            title: terminalProvider.isProcessing
                ? 'billing.processing'.tr
                : billingProvider.pineLabsPaymentSuccess
                    ? 'billing.paid_with_pine_labs'.tr
                    : 'billing.pay_with_pine_labs'.tr,
            fct: () => _payWithPineLabs(context, terminalProvider, billingProvider),
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
          ),
        );
      },
    );
  }

  Future<void> _payWithPineLabs(
    BuildContext context,
    PineLabsTerminalProvider terminalProvider,
    BillingProvider billingProvider,
  ) async {
    if (terminalProvider.isProcessing) return;

    final totalAmount = billingProvider.totalOrderAmount;
    if (!_controller.isPineLabsAmountValid(totalAmount)) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.pineLabsInvalidAmount,
      );
      return;
    }

    _controller.resetPineLabsBeforeAttempt(billingProvider);

    final billingRefNo = billingProvider.transactionNumberController.text;
    final String resultStr = await terminalProvider.processSale(
      amount: totalAmount,
      billingRefNo: billingRefNo.isEmpty
          ? 'REF-${DateTime.now().millisecondsSinceEpoch}'
          : billingRefNo,
    );

    final result = _controller.parsePineLabsResult(resultStr);
    _controller.applyPineLabsResult(billingProvider, result);

    if (!context.mounted) return;

    if (result.success) {
      billingDebugLog('[PineLabs] Payment SUCCESS');
      showScaffold(
        context: context,
        message: result.message,
      );
    } else {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.pineLabsPaymentFailed(
          result.message.isNotEmpty ? result.message : null,
        ),
      );
    }
  }
}
