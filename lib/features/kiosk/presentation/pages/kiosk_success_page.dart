import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_flow_scaffold.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskSuccessPage extends StatelessWidget {
  final double total;
  final String currency;
  final String paymentMethodLabel;
  final String? orderNumber;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onStartNewOrder;

  const KioskSuccessPage({
    super.key,
    required this.total,
    required this.currency,
    required this.paymentMethodLabel,
    this.orderNumber,
    this.onPrintReceipt,
    this.onStartNewOrder,
  });

  @override
  Widget build(BuildContext context) {
    final hasOrderNumber = orderNumber?.trim().isNotEmpty == true;
    return Scaffold(
      backgroundColor: ColorManager.kBgLightColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: KioskSurfaceCard(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF8EF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF22A559),
                        size: 62,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Order complete!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColorManager.kTitleTextColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasOrderNumber
                          ? 'Thank you. Please keep your order number and watch the collection screen.'
                          : 'Thank you. Your order has been received.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ColorManager.kTextColor,
                        fontSize: 17,
                        height: 1.45,
                      ),
                    ),
                    if (hasOrderNumber) ...[
                      const SizedBox(height: 26),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: ColorManager.kPrimaryWithOpacity10,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'ORDER NUMBER',
                              style: TextStyle(
                                color: ColorManager.kPrimaryColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              orderNumber!.trim(),
                              style: const TextStyle(
                                color: ColorManager.kTitleTextColor,
                                fontSize: 46,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _SuccessRow(
                      label: 'Amount paid',
                      value: _money(currency, total),
                    ),
                    const SizedBox(height: 10),
                    _SuccessRow(
                      label: 'Payment method',
                      value: paymentMethodLabel,
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 500;
                        final receipt = SizedBox(
                          height: 62,
                          child: OutlinedButton.icon(
                            onPressed: onPrintReceipt,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text(
                              'Print receipt',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ColorManager.kPrimaryColor,
                              side: const BorderSide(
                                  color: ColorManager.kPrimaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        );
                        final restart = KioskPrimaryButton(
                          label: 'Start new order',
                          icon: Icons.refresh_rounded,
                          onPressed: onStartNewOrder ??
                              () => Navigator.of(context)
                                  .popUntil((route) => route.isFirst),
                        );

                        if (compact) {
                          return Column(
                            children: [
                              restart,
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: receipt),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: receipt),
                            const SizedBox(width: 12),
                            Expanded(child: restart),
                          ],
                        );
                      },
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

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;

  const _SuccessRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: ColorManager.kTextColor)),
        ),
        const SizedBox(width: 14),
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
