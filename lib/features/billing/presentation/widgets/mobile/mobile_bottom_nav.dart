import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Van-sale friendly bottom navigation: floating dock, large tap targets,
/// clear active states, and a prominent cart badge.
class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _animationDuration = Duration(milliseconds: 220);
  static const _animationCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: ColorManager.shadowColor.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: ColorManager.boxShadowColor.withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Selector<LocalProductProvider, int>(
            selector: (_, provider) => provider.cartItems.length,
            builder: (context, cartCount, _) {
              return Row(
                children: [
                  _NavItem(
                    selected: currentIndex == 0,
                    label: 'billing.market'.tr,
                    outlinedIcon: Icons.storefront_outlined,
                    filledIcon: Icons.storefront,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    selected: currentIndex == 1,
                    label: 'billing.billing'.tr,
                    outlinedIcon: Icons.payment_outlined,
                    filledIcon: Icons.payment,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    selected: currentIndex == 2,
                    label: 'billing.order'.tr,
                    outlinedIcon: Icons.receipt_long_outlined,
                    filledIcon: Icons.receipt_long,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    selected: currentIndex == 3,
                    label: 'billing.cart'.tr,
                    outlinedIcon: Icons.shopping_cart_outlined,
                    filledIcon: Icons.shopping_cart,
                    badgeCount: cartCount,
                    onTap: () => onTap(3),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
    required this.onTap,
    this.badgeCount,
  });

  final bool selected;
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    const activeColor = ColorManager.kPrimaryColor;
    const inactiveColor = ColorManager.kGreyColor;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            splashColor: activeColor.withValues(alpha: 0.12),
            highlightColor: activeColor.withValues(alpha: 0.08),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
              child: AnimatedContainer(
                duration: MobileBottomNav._animationDuration,
                curve: MobileBottomNav._animationCurve,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? ColorManager.kPrimaryWithOpacity10
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: selected
                      ? Border.all(
                          color: activeColor.withValues(alpha: 0.18),
                          width: 1,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NavIcon(
                      selected: selected,
                      outlinedIcon: outlinedIcon,
                      filledIcon: filledIcon,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      badgeCount: badgeCount,
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: MobileBottomNav._animationDuration,
                      curve: MobileBottomNav._animationCurve,
                      style: TextStyle(
                        fontSize: selected ? 12 : 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? activeColor : inactiveColor,
                        height: 1.1,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.selected,
    required this.outlinedIcon,
    required this.filledIcon,
    required this.activeColor,
    required this.inactiveColor,
    this.badgeCount,
  });

  final bool selected;
  final IconData outlinedIcon;
  final IconData filledIcon;
  final Color activeColor;
  final Color inactiveColor;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = (badgeCount ?? 0) > 0;

    return SizedBox(
      width: 32,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: MobileBottomNav._animationDuration,
            curve: MobileBottomNav._animationCurve,
            child: Icon(
              selected ? filledIcon : outlinedIcon,
              size: 26,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
          if (showBadge)
            Positioned(
              right: -10,
              top: -6,
              child: _CartBadge(count: badgeCount!),
            ),
        ],
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final horizontalPadding = count > 9 ? 5.0 : 6.0;

    return Semantics(
      label: '$count items in cart',
      child: AnimatedContainer(
        duration: MobileBottomNav._animationDuration,
        curve: MobileBottomNav._animationCurve,
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: ColorManager.kBadgeColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: ColorManager.kBadgeColor.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
