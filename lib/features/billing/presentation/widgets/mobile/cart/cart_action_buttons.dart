import 'package:flutter/material.dart';

class CartActionButtons extends StatelessWidget {
  const CartActionButtons({
    super.key,
    required this.hasItems,
    required this.onProceedToPayment,
    required this.onSaveOrder,
    required this.onClearCart,
  });

  final bool hasItems;
  final VoidCallback onProceedToPayment;
  final VoidCallback onSaveOrder;
  final VoidCallback onClearCart;

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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(
                'Proceed to Payment',
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
          onTap: hasItems ? onSaveOrder : null,
        ),
        const SizedBox(width: 10),
        _IconActionButton(
          icon: Icons.delete_outline,
          backgroundColor: Colors.red.shade50,
          iconColor: Colors.red.shade400,
          onTap: hasItems ? onClearCart : null,
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
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
