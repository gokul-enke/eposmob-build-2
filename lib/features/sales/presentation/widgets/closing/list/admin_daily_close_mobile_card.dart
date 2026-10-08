import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../../../domain/models/daily_sales_close.dart';

class AdminDailyCloseMobileCard extends StatelessWidget {
  const AdminDailyCloseMobileCard(
      {super.key, required this.data, required this.onView});
  final DailySalesCloseData data;
  final VoidCallback onView;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.salesExecutive?.name ??
                      'daily_sales_close.card_unknown'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.15,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.closingDate ?? '-',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.0,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.orders_prefix'.tr.trim(),
                  data.totalOrders?.toString() ?? '0',
                ),
              ),
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.total_sales'.tr,
                  data.totalSales ?? '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.card_user_id'.tr,
                  data.salesExecutive?.id?.toString() ?? '-',
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildItemDetail(
                  'daily_sales_close.sales_executive'.tr,
                  data.salesExecutive?.name ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.cash_sales'.tr,
                  data.totalCash ?? '0.00',
                ),
              ),
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.online_sales'.tr,
                  data.totalOnline ?? '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onView,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('daily_sales_close.btn_view_details'.tr),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.0,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.0,
            Colors.black87,
          ),
        ),
      ],
    );
  }
}
