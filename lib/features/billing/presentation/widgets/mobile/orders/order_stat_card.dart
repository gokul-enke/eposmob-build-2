import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class OrderStatCard extends StatelessWidget {
  const OrderStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  final String title;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveOrdersStatCard extends StatelessWidget {
  const ActiveOrdersStatCard({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return OrderStatCard(
      title: 'Active Orders',
      value: value,
      valueColor: ColorManager.kPrimaryColor,
    );
  }
}

class ReadyOrdersStatCard extends StatelessWidget {
  const ReadyOrdersStatCard({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return OrderStatCard(
      title: 'Ready for Pickup',
      value: value,
      valueColor: Colors.green,
    );
  }
}
