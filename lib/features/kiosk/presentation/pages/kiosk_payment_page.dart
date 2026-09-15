import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/models/kiosk_order_draft.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_payment_failure_page.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_success_page.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_flow_scaffold.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_payment_processing_dialog.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class KioskPaymentPage extends StatefulWidget {
  final List<LocalCartItem> items;
  final String currency;
  final DeliveryMethod deliveryMethod;
  final String customerName;
  final String customerPhone;
  final Future<bool> Function(PaymentMethod method)? onPaymentRequested;

  const KioskPaymentPage({
    super.key,
    required this.items,
    required this.currency,
    required this.deliveryMethod,
    this.customerName = '',
    this.customerPhone = '',
    this.onPaymentRequested,
  });

  @override
  State<KioskPaymentPage> createState() => _KioskPaymentPageState();
}

class _KioskPaymentPageState extends State<KioskPaymentPage> {
  PaymentMethod? _selectedMethod;
  bool _processing = false;

  void _selectInitialMethod(List<PaymentMethod> methods) {
    if (_selectedMethod != null || methods.isEmpty) return;
    _selectedMethod = methods.first;
  }

  Future<void> _continue(double total) async {
    final selectedMethod = _selectedMethod;
    if (selectedMethod == null || _processing) return;
    setState(() => _processing = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => KioskPaymentProcessingDialog(
        paymentMethodLabel: selectedMethod.label,
      ),
    );

    var succeeded = false;
    try {
      if (widget.onPaymentRequested != null) {
        succeeded = await widget.onPaymentRequested!(selectedMethod);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        succeeded = true;
      }
    } catch (_) {
      succeeded = false;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _processing = false);

    if (succeeded) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => KioskSuccessPage(
            total: total,
            currency: widget.currency,
            paymentMethodLabel: selectedMethod.label,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KioskPaymentFailurePage(
          total: total,
          currency: widget.currency,
          paymentMethodLabel: selectedMethod.label,
          onTryAgain: () {
            Navigator.of(context).pop();
            _continue(total);
          },
          onChooseAnotherMethod: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MasterDataProvider>();
    final methods = provider.enabledSortedPaymentMethods;
    _selectInitialMethod(methods);
    final draft = KioskOrderDraft.fromCartItems(widget.items);
    final total = draft.total + (widget.deliveryMethod.basePrice ?? 0);

    return KioskFlowScaffold(
      title: 'Payment',
      stepLabel: 'Step 3 of 3',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final padding = constraints.maxWidth < 600 ? 14.0 : 22.0;
          final methodsCard = _PaymentMethodsCard(
            methods: methods,
            selectedMethod: _selectedMethod,
            onSelected: (method) {
              setState(() => _selectedMethod = method);
            },
          );
          final summary = _PaymentSummary(
            draft: draft,
            deliveryMethod: widget.deliveryMethod,
            total: total,
            currency: widget.currency,
            selectedMethod: _selectedMethod,
            onPay: _selectedMethod == null || _processing
                ? null
                : () => _continue(total),
          );

          if (wide) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: methodsCard),
                  const SizedBox(width: 20),
                  SizedBox(width: 390, child: summary),
                ],
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              methodsCard,
              const SizedBox(height: 16),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  final List<PaymentMethod> methods;
  final PaymentMethod? selectedMethod;
  final ValueChanged<PaymentMethod> onSelected;

  const _PaymentMethodsCard({
    required this.methods,
    required this.selectedMethod,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return KioskSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KioskSectionTitle(
            'Choose a payment method',
            subtitle: 'Only methods enabled for this store are shown',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth < 620
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: methods.map((method) {
                  return SizedBox(
                    width: tileWidth,
                    child: _PaymentMethodTile(
                      method: method,
                      selected: selectedMethod?.code == method.code,
                      onTap: () => onSelected(method),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (selectedMethod?.behavior == PaymentBehavior.terminal) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.contactless_rounded,
                      color: ColorManager.kPrimaryColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Follow the instructions shown on the payment terminal.',
                      style: TextStyle(color: ColorManager.kTextColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ColorManager.kPrimaryWithOpacity10
          : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? ColorManager.kPrimaryColor
                  : const Color(0xFFE2E7F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _paymentIcon(method),
                  color: ColorManager.kPrimaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  method.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? ColorManager.kPrimaryColor
                    : ColorManager.kGreyColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  final KioskOrderDraft draft;
  final DeliveryMethod deliveryMethod;
  final double total;
  final String currency;
  final PaymentMethod? selectedMethod;
  final VoidCallback? onPay;

  const _PaymentSummary({
    required this.draft,
    required this.deliveryMethod,
    required this.total,
    required this.currency,
    required this.selectedMethod,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryCharge = deliveryMethod.basePrice ?? 0;
    return KioskSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KioskSectionTitle('Payable total'),
          const SizedBox(height: 22),
          _PaymentRow(
            label: 'Subtotal',
            value: _money(currency, draft.subtotal),
          ),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Included tax',
            value: _money(currency, draft.includedTax),
          ),
          if (deliveryCharge > 0) ...[
            const SizedBox(height: 12),
            _PaymentRow(
              label: 'Delivery',
              value: _money(currency, deliveryCharge),
            ),
          ],
          const Divider(height: 34),
          Text(
            _money(currency, total),
            style: const TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedMethod == null
                ? 'Select a payment method'
                : 'Pay with ${selectedMethod!.label}',
            style: const TextStyle(color: ColorManager.kTextColor),
          ),
          const SizedBox(height: 24),
          KioskPrimaryButton(
            label: 'Pay ${_money(currency, total)}',
            icon: Icons.lock_outline_rounded,
            onPressed: onPay,
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 18, color: ColorManager.kGreyColor),
              SizedBox(width: 7),
              Text(
                'Secure payment',
                style: TextStyle(color: ColorManager.kGreyColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: ColorManager.kTextColor)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: ColorManager.kTitleTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

IconData _paymentIcon(PaymentMethod method) {
  final hint = '${method.iconKey ?? ''} ${method.code}'.toLowerCase();
  if (hint.contains('cash')) return Icons.payments_outlined;
  if (hint.contains('card')) return Icons.credit_card_rounded;
  if (hint.contains('upi') || hint.contains('qr')) return Icons.qr_code_rounded;
  if (hint.contains('online') || method.behavior == PaymentBehavior.terminal) {
    return Icons.contactless_rounded;
  }
  if (method.behavior == PaymentBehavior.credit) {
    return Icons.account_balance_wallet_outlined;
  }
  return Icons.payment_rounded;
}

String _money(String currency, num value) {
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${AmountHelper.formatAmount(value)}';
}
