import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'daily_close_list_inputs.dart';

class DailyCloseEmptyState extends StatelessWidget {
  const DailyCloseEmptyState({super.key, required this.inputs});
  final DailyCloseListInputs inputs;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'daily_sales_close.no_closes_found'.tr,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'daily_sales_close.adjust_filters_hint'.tr,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
