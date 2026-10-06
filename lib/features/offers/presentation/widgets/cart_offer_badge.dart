import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// "Offer" tag plus the struck-through price before the offer, shown under
/// a cart line's name. Renders nothing for lines without an offer.
class CartOfferBadge extends StatelessWidget {
  const CartOfferBadge({super.key, required this.item, this.fontSize = 10});

  final LocalCartItem item;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final standardPrice = item.displayStandardPrice;
    if (!item.hasOffer || standardPrice == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: ColorManager.kSuccessColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: fontSize + 1,
                color: ColorManager.kSuccessColor,
              ),
              const SizedBox(width: 3),
              Text(
                'offers.badge'.tr,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: ColorManager.kSuccessColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AmountHelper.formatAmount(standardPrice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: ColorManager.kGreyColor,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
      ],
    );
  }
}
