import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CartActionButtons extends StatelessWidget {
  const CartActionButtons({
    super.key,
    required this.hasItems,
    required this.onProceedToPayment,
    required this.onSaveOrder,
    required this.onClearCart,
    this.isSavingOrder = false,
    this.isClearingCart = false,
  });

  final bool hasItems;
  final VoidCallback onProceedToPayment;
  final VoidCallback onSaveOrder;
  final VoidCallback onClearCart;
  final bool isSavingOrder;
  final bool isClearingCart;

  bool get _isCartActionBusy => isSavingOrder || isClearingCart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: hasItems ? onProceedToPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E69C8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                'billing.proceed_to_payment'.tr,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _IconActionButton(
          icon: Icons.receipt_long_outlined,
          backgroundColor: Colors.blue.shade50,
          iconColor: const Color(0xFF2E69C8),
          isLoading: isSavingOrder,
          semanticsLabel: 'billing.save_order'.tr,
          onTap: (hasItems && !_isCartActionBusy) ? onSaveOrder : null,
        ),
        const SizedBox(width: 10),
        _IconActionButton(
          icon: Icons.delete_outline,
          backgroundColor: Colors.red.shade50,
          iconColor: Colors.red.shade400,
          isLoading: isClearingCart,
          semanticsLabel: 'billing.clear_cart_button'.tr,
          onTap: (hasItems && !_isCartActionBusy) ? onClearCart : null,
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    required this.semanticsLabel,
    this.isLoading = false,
  });

  static const double _minTouchTarget = 44;

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _minTouchTarget,
            height: _minTouchTarget,
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  )
                : Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}
