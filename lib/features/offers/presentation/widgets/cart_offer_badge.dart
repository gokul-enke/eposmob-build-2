import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// "Offer" tag plus the struck-through price before the offer, shown under
/// a cart line's name. Renders nothing for lines without an offer.
///
/// Laid out as one line of text (the tag is an inline widget) so it never
/// overflows a narrow cell: the struck price is ellipsized first, then the
/// tag's label.
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
    return OfferPriceBadge(standardPrice: standardPrice, fontSize: fontSize);
  }
}

/// The same offer label for cart lines and read-only product price previews.
class OfferPriceBadge extends StatelessWidget {
  const OfferPriceBadge(
      {super.key, required this.standardPrice, this.fontSize = 10});

  final double standardPrice;
  final double fontSize;
  static const _noDecoration = TextStyle(decoration: TextDecoration.none);

  @override
  Widget build(BuildContext context) {
    final standardText = AmountHelper.formatAmount(standardPrice);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Darker / lighter shades of the success colour keep the tag readable
    // (at least 4.5:1) on its tinted background in light and dark themes.
    final offerColor = isDark ? Colors.green.shade300 : Colors.green.shade800;
    final standardColor =
        isDark ? theme.colorScheme.onSurfaceVariant : ColorManager.kTextColor;

    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color:
            ColorManager.kSuccessColor.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: fontSize + 1,
            color: offerColor,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'offers.badge'.tr,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: offerColor,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'offers.badge_semantics'.trParams({'price': standardText}),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              style: _noDecoration,
              child: tag,
            ),
            const WidgetSpan(
              style: _noDecoration,
              child: SizedBox(width: 6),
            ),
            TextSpan(text: standardText),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        // The struck-through price is the text; the tag is an inline widget.
        style: TextStyle(
          fontSize: fontSize,
          color: standardColor,
          decoration: TextDecoration.lineThrough,
          decorationColor: standardColor,
        ),
      ),
    );
  }
}
