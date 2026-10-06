import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../../domain/supplier_report.dart';

class SupplierReportMobileCard extends StatelessWidget {
  const SupplierReportMobileCard(
      {super.key, required this.summary, required this.onView});
  final SupplierTransactionSummary summary;
  final ValueChanged<SupplierTransactionSummary> onView;
  @override
  Widget build(BuildContext context) {
    final Color balanceColor = summary.balance < 0 ? Colors.red : Colors.green;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SelectableText(
                    summary.displayName ??
                        'supplier_transaction_report.unknown'.tr,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s14, 0.20, ColorManager.textColor),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.visibility,
                      size: 18, color: ColorManager.kPrimaryColor),
                  onPressed: () {
                    onView(summary);
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                _buildMobileCardStat(
                    'supplier_transaction_report.debit_stat'.tr,
                    summary.totalDebit.toStringAsFixed(2)),
                _buildMobileCardStat(
                    'supplier_transaction_report.credit_stat'.tr,
                    summary.totalCredit.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('supplier_transaction_report.balance'.tr,
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s10, 0.15, Colors.grey)),
                      Text(
                        summary.balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMobileCardStat(
                    'supplier_transaction_report.transactions'.tr,
                    summary.transactionCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey)),
          Text(value,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.18, Colors.black87)),
        ],
      ),
    );
  }
}
