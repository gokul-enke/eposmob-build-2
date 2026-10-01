import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Card colour for a membership tier name; unknown tiers get the copper
/// (bronze) colour.
abstract final class LoyaltyTierPalette {
  static Color of(String? tier) => switch (tier?.trim().toLowerCase()) {
        'platinum' => Colors.blueGrey.shade400,
        'gold' => Colors.amber.shade700,
        'silver' => Colors.grey.shade500,
        _ => Colors.brown.shade400,
      };
}

/// The gradient "membership card" at the top of the loyalty tab.
class CustomerLoyaltyCard extends StatelessWidget {
  const CustomerLoyaltyCard({
    super.key,
    required this.holderName,
    required this.cardNumber,
    required this.tierName,
  });

  final String holderName;
  final String cardNumber;

  /// Membership name; null shows the default tier.
  final String? tierName;

  @override
  Widget build(BuildContext context) {
    final hasTier = tierName?.trim().isNotEmpty == true;
    final color = LoyaltyTierPalette.of(tierName);
    final radius = BorderRadius.circular(AppRadius.card);
    const onCard = AppColors.onPrimary;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 170),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: .8)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            PositionedDirectional(
              end: -60,
              bottom: -60,
              child: Icon(
                Icons.stars,
                size: 180,
                color: onCard.withValues(alpha: .1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'customer_loyalty.card_title'.tr,
                          style: const TextStyle(
                            color: onCard,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: onCard.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          hasTier
                              ? tierName!
                              : 'customer_loyalty.tier_default'.tr,
                          style: const TextStyle(
                            color: onCard,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    holderName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: onCard,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    cardNumber,
                    style: TextStyle(
                      color: onCard.withValues(alpha: .9),
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
