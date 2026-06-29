import 'package:flutter/material.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/live_time_display.dart';

class CustomerSummaryCard extends StatelessWidget {
  final CustomerListModelData? customer;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  const CustomerSummaryCard({
    super.key,
    this.customer,
    this.onClear,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
        ),
        child: Row(
          children: [
            // Person Icon Badge
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1E5BB5), // Rich blue matching Figma
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Customer Name column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Customer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer?.name ?? 'Default B2C',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066CC),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time column
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Time',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                LiveTimeDisplay(),
              ],
            ),
            if (onClear != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
