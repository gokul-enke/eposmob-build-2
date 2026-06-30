import 'package:flutter/material.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_method_modal.dart';
import 'package:provider/provider.dart';

class PaymentMethodModalWrapper extends StatelessWidget {
  const PaymentMethodModalWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        return PaymentMethodModal(
          initialIsCashSelected: billingProvider.isCashSelected,
          initialIsCardSelected: billingProvider.isCardSelected,
          initialIsUpiSelected: billingProvider.isUpiSelected,
          initialIsCodSelected: billingProvider.isCodSelected,
          initialIsDebitSelected: billingProvider.isDebitSelected,
          initialCashAmount: billingProvider.cashAmountController.text,
          initialCardAmount: billingProvider.cardAmountController.text,
          initialUpiAmount: billingProvider.upiAmountController.text,
          initialCodAmount: billingProvider.codAmountController.text,
          initialDebitAmount: billingProvider.debitAmountController.text,
          initialTransactionNumber:
              billingProvider.transactionNumberController.text,
          cartTotal: billingProvider.totalOrderAmount,
          customerPrevBalance: billingProvider.customerBalance,
          onPaymentMethodSelected: (
            isCash,
            isCard,
            isUpi,
            isCod,
            isDebit,
            cashAmt,
            cardAmt,
            upiAmt,
            codAmt,
            debitAmt,
            transNum,
            toCustomerCredit, {
            String? cashMethodId,
            String? cardMethodId,
            String? upiMethodId,
            String? codMethodId,
            Map<String, String>? extraMethodAmounts,
            Map<String, String>? extraMethodValues,
          }) {
            billingProvider.updatePaymentFromModal(
              isCash: isCash,
              isCard: isCard,
              isUpi: isUpi,
              isCod: isCod,
              isDebit: isDebit,
              cashAmount: cashAmt,
              cardAmount: cardAmt,
              upiAmount: upiAmt,
              codAmount: codAmt,
              debitAmount: debitAmt,
              transactionNumber: transNum,
              toCustomerCredit: toCustomerCredit,
              cashMethodId: cashMethodId,
              cardMethodId: cardMethodId,
              upiMethodId: upiMethodId,
              codMethodId: codMethodId,
            );
          },
        );
      },
    );
  }
}
