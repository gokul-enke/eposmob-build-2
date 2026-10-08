import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class DayCloseMobileCard extends StatelessWidget {
  final DailySalesCloseData data;
  final VoidCallback onTap;
  final String currency;

  const DayCloseMobileCard(
      {required this.data, required this.onTap, required this.currency});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        circleRadius: 10,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: closing period + total sales
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data.businessDate ?? '-',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s13,
                      0.19,
                      ColorManager.textColor,
                    ),
                  ),
                  Text(
                    '$currency ${data.totalSales ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s13,
                      0.19,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Sales executive
              Text(
                data.salesExecutive?.name ?? '-',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.18,
                  Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              // Store
              Text(
                data.store?.name ?? '-',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.18,
                  Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              // Orders + Cash row
              Row(
                children: [
                  Text(
                    'daily_sales_close.orders_prefix'.tr +
                        '${data.totalOrders ?? 0}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.16,
                      Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'daily_sales_close.cash_prefix'.tr +
                        '$currency ${data.totalCash ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.16,
                      Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Online + Credit row
              Row(
                children: [
                  Text(
                    'daily_sales_close.online_prefix'.tr +
                        '$currency ${data.totalOnline ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.16,
                      Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'daily_sales_close.credit_prefix'.tr +
                        '$currency ${data.totalCredit ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.16,
                      Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),
              // Business date
              Text(
                'daily_sales_close.business_date_prefix'.tr +
                    '${data.businessDate ?? "-"}',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.16,
                  Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
