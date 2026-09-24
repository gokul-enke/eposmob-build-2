import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskProductCard extends StatelessWidget {
  final GetProduct product;
  final num quantity;
  final String currency;
  final bool customizable;
  final VoidCallback onAdd;

  const KioskProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.currency,
    required this.customizable,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = product.localizedName?.trim().isNotEmpty == true
        ? product.localizedName!.trim()
        : product.productName?.trim().isNotEmpty == true
            ? product.productName!.trim()
            : 'Unnamed product';

    return Semantics(
      button: true,
      label: customizable ? 'Customize $name' : 'Add $name to order',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KioskRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE1E8F1)),
              borderRadius: BorderRadius.circular(KioskRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProductImage(product: product),
                      if (quantity > 0)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 38),
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ColorManager.kPrimaryColor,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              '${quantity.toInt()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(KioskSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KioskType.productTitle,
                      ),
                      const SizedBox(height: KioskSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatMarketProductPrice(product, currency),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KioskType.price,
                            ),
                          ),
                          Container(
                            constraints: BoxConstraints(
                              minWidth: customizable ? 104 : 74,
                            ),
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: customizable
                                  ? const Color(0xFFF0F4F9)
                                  : ColorManager.kPrimaryWithOpacity10,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  customizable
                                      ? Icons.tune_rounded
                                      : Icons.add_rounded,
                                  color: customizable
                                      ? ColorManager.kTitleTextColor
                                      : ColorManager.kPrimaryColor,
                                  size: 21,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  customizable ? 'Customize' : 'Add',
                                  style: TextStyle(
                                    color: customizable
                                        ? ColorManager.kTitleTextColor
                                        : ColorManager.kPrimaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final GetProduct product;

  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMarketProductImageUrl(product);
    return ColoredBox(
      color: const Color(0xFFF3F6FA),
      child: imageUrl == null
          ? const _ImageFallback()
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _ImageFallback(),
            ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 82,
        height: 82,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: ColorManager.kPrimaryWithOpacity10,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.shopping_bag_outlined,
          size: 42,
          color: ColorManager.kPrimaryColor,
        ),
      ),
    );
  }
}
