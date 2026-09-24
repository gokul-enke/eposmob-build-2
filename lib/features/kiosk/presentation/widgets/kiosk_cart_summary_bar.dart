import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskCartSummaryBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final String currency;
  final VoidCallback onPressed;

  const KioskCartSummaryBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.currency,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: const Color(0x260F172A),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(KioskSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final details = _CartDetails(
                itemCount: itemCount,
                total: total,
                currency: currency,
              );
              final action = _CheckoutButton(
                enabled: itemCount > 0,
                onPressed: onPressed,
              );

              if (compact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    details,
                    const SizedBox(height: KioskSpacing.sm),
                    SizedBox(width: double.infinity, child: action),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: KioskSpacing.md),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CartDetails extends StatelessWidget {
  final int itemCount;
  final double total;
  final String currency;

  const _CartDetails({
    required this.itemCount,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Badge(
          isLabelVisible: itemCount > 0,
          label: Text('$itemCount'),
          backgroundColor: ColorManager.kPrimaryColor,
          offset: const Offset(-2, 2),
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              color: ColorManager.kPrimaryColor,
              size: 27,
            ),
          ),
        ),
        const SizedBox(width: KioskSpacing.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: KioskType.supporting,
              ),
              Text(
                '${currency.trim().isEmpty ? '' : '${currency.trim()} '}'
                '${AmountHelper.formatAmount(total)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KioskType.sectionTitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _CheckoutButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryColor,
          disabledBackgroundColor: ColorManager.kGreyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: const Text(
          'Review order',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KioskType.action,
        ),
      ),
    );
  }
}
