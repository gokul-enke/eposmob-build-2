import 'package:flutter/material.dart';

/// Empty-state placeholder for the mobile Orders tab. Extracted verbatim from
/// `orders_tab.dart`'s `_buildEmptyState`.
class OrdersEmptyState extends StatelessWidget {
  final bool hasSearchQuery;

  const OrdersEmptyState({super.key, required this.hasSearchQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchQuery
                ? 'Try adjusting your search or filter'
                : 'Saved orders will appear here',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
