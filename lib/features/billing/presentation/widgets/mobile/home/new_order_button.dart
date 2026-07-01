import 'package:flutter/material.dart';

class NewOrderButton extends StatelessWidget {
  const NewOrderButton({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  final VoidCallback onTap;
  final bool compact;

  static const double _minTouchTarget = 44;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTouchTarget,
            minHeight: _minTouchTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 22),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Add Product',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
