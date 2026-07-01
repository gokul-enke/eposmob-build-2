import 'package:flutter/material.dart';

class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.inStock,
    this.compact = false,
  });

  final bool inStock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = inStock ? 'Available' : 'Out Of Stock';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: inStock ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        compact ? (inStock ? 'In' : 'Out') : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 8 : 9,
        ),
      ),
    );
  }
}
