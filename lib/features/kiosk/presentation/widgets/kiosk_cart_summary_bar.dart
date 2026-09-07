import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
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
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: ColorManager.kPrimaryWithOpacity10,
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  isLabelVisible: itemCount > 0,
                  label: Text('$itemCount'),
                  backgroundColor: ColorManager.kPrimaryColor,
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: ColorManager.kPrimaryColor,
                    size: 27,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(color: ColorManager.kTextColor),
                    ),
                    Text(
                      '${currency.trim().isEmpty ? '' : '${currency.trim()} '}'
                      '${AmountHelper.formatAmount(total)}',
                      style: const TextStyle(
                        color: ColorManager.kTitleTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: itemCount == 0 ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColorManager.kPrimaryColor,
                    disabledBackgroundColor: ColorManager.kGreyColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'View order & checkout',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
