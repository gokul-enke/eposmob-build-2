import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/payment_methods_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_sheet_header.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Bottom sheet wrapper around [PaymentMethodsSection] for the mobile Billing
/// tab. Shows a pinned live remaining-balance bar under the header (sourced
/// from [BillingProvider], currency from [AppSettingsProvider] the same way
/// [PaymentSummary] does), then the scrollable section content, then a
/// "Done" button.
Future<void> showPaymentMethodsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _PaymentMethodsSheet(),
  );
}

class _PaymentMethodsSheet extends StatelessWidget {
  const _PaymentMethodsSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileSheetHeader(
              title: 'billing.payment_methods'.tr,
              onClose: () => Navigator.pop(context),
            ),
            const _RemainingBalanceBar(),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PaymentMethodsSection(),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: ColorManager.kPrimaryColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _BalanceSnapshot {
  const _BalanceSnapshot({
    required this.effectiveOrderTotal,
    required this.totalPaidAmount,
    required this.balanceAmount,
  });

  factory _BalanceSnapshot.from(BillingProvider bp) => _BalanceSnapshot(
        effectiveOrderTotal: bp.effectiveOrderTotal,
        totalPaidAmount: bp.totalPaidAmount,
        balanceAmount: bp.balanceAmount,
      );

  final double effectiveOrderTotal;
  final double totalPaidAmount;
  final double balanceAmount;

  @override
  bool operator ==(Object other) {
    return other is _BalanceSnapshot &&
        other.effectiveOrderTotal == effectiveOrderTotal &&
        other.totalPaidAmount == totalPaidAmount &&
        other.balanceAmount == balanceAmount;
  }

  @override
  int get hashCode =>
      Object.hash(effectiveOrderTotal, totalPaidAmount, balanceAmount);
}

/// Pinned status bar directly under the sheet header showing the remaining
/// balance, sourced from [BillingProvider]. Green when fully paid (balance
/// <= 0), amber/red otherwise.
class _RemainingBalanceBar extends StatelessWidget {
  const _RemainingBalanceBar();

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? '';

    return Selector<BillingProvider, _BalanceSnapshot>(
      selector: (_, bp) => _BalanceSnapshot.from(bp),
      builder: (context, snapshot, _) {
        final balance = snapshot.balanceAmount;
        final isPaidInFull =
            snapshot.effectiveOrderTotal <= 0 || balance <= 0.001;
        final color = isPaidInFull
            ? const Color(0xFF15803D) // Dark green
            : (balance > snapshot.effectiveOrderTotal * 0.5
                ? const Color(0xFFDC2626) // Red
                : const Color(0xFFD97706)); // Amber

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaidInFull ? 'Fully Paid' : 'Remaining',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '$currency ${AmountHelper.formatAmount(isPaidInFull ? 0 : balance)}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
