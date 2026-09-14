import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_flow_scaffold.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskPaymentFailurePage extends StatelessWidget {
  final double total;
  final String currency;
  final String paymentMethodLabel;
  final VoidCallback onTryAgain;
  final VoidCallback onChooseAnotherMethod;

  const KioskPaymentFailurePage({
    super.key,
    required this.total,
    required this.currency,
    required this.paymentMethodLabel,
    required this.onTryAgain,
    required this.onChooseAnotherMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.kBgLightColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: KioskSurfaceCard(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                child: Column(
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFECEC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFE5484D),
                        size: 58,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment unsuccessful',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColorManager.kTitleTextColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No payment was taken. Please try again or choose another payment method.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColorManager.kTextColor,
                        fontSize: 17,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _FailureRow(
                            label: 'Amount',
                            value: _money(currency, total),
                          ),
                          const SizedBox(height: 10),
                          _FailureRow(
                            label: 'Payment method',
                            value: paymentMethodLabel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    KioskPrimaryButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: onTryAgain,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: onChooseAnotherMethod,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColorManager.kPrimaryColor,
                          side: const BorderSide(
                              color: ColorManager.kPrimaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Choose another payment method',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureRow extends StatelessWidget {
  final String label;
  final String value;

  const _FailureRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: ColorManager.kTextColor)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ColorManager.kTitleTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _money(String currency, num value) {
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${AmountHelper.formatAmount(value)}';
}
