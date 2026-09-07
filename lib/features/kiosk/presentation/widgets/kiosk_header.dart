import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskHeader extends StatelessWidget {
  final String storeName;
  final int cartQuantity;
  final VoidCallback? onCartPressed;

  const KioskHeader({
    super.key,
    required this.storeName,
    required this.cartQuantity,
    this.onCartPressed,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 28,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 50 : 58,
            height: compact ? 50 : 58,
            decoration: const BoxDecoration(
              color: ColorManager.kPrimaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: compact ? 12 : 18),
          Expanded(
            child: Text(
              compact ? storeName : 'Welcome to $storeName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ColorManager.kTitleTextColor,
                fontSize: compact ? 22 : 30,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _HeaderAction(
            icon: Icons.language_rounded,
            label: compact ? null : 'English',
            onPressed: () {},
          ),
          if (onCartPressed != null) ...[
            const SizedBox(width: 10),
            Badge(
              isLabelVisible: cartQuantity > 0,
              label: Text('$cartQuantity'),
              backgroundColor: ColorManager.kPrimaryColor,
              child: _HeaderAction(
                icon: Icons.shopping_cart_outlined,
                onPressed: onCartPressed!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;

  const _HeaderAction({
    required this.icon,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: label == null ? const SizedBox.shrink() : Text(label!),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColorManager.kTextColor,
        minimumSize: Size(label == null ? 56 : 130, 56),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 14 : 18),
        side: const BorderSide(color: Color(0xFFDDE3EF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
