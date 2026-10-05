import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';
import 'day_close_detail_item.dart';
import 'day_close_section_header.dart';

class DayCloseSalesSummary extends StatelessWidget {
  const DayCloseSalesSummary(this.data, {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final currency = inputs.currency;

        // Build payment breakdown rows dynamically
        final List<Widget> breakdownRows = [];
        final breakdown = data.paymentMethodBreakdown ??
            {
              'BANK': '0.00',
              'CARD': '0.00',
              'CASH': '0.00',
              'COD': '0.00',
              'ONLINE': '0.00',
              'UPI': '0.00',
              'CHEQUE': '0.00',
              'CREDIT': '0.00',
            };

        String translatePaymentMethod(String key) {
          final lower = key.toLowerCase();
          return 'billing.payment_method_labels.$lower'.tr;
        }

        final entries = breakdown.entries.toList();
        for (int i = 0; i < entries.length; i += 2) {
          final entry1 = entries[i];
          final hasSecond = i + 1 < entries.length;
          final entry2 = hasSecond ? entries[i + 1] : null;

          breakdownRows.add(
            Row(
              children: [
                Expanded(
                  child: DayCloseDetailItem(translatePaymentMethod(entry1.key),
                      '$currency ${entry1.value ?? '0.00'}',
                      inputs: inputs),
                ),
                if (entry2 != null)
                  Expanded(
                    child: DayCloseDetailItem(
                        translatePaymentMethod(entry2.key),
                        '$currency ${entry2.value ?? '0.00'}',
                        inputs: inputs),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
          if (i + 2 < entries.length) {
            breakdownRows.add(const SizedBox(height: 20));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DayCloseSectionHeader('daily_sales_close.day_close_summary'.tr,
                Icons.summarize_outlined,
                inputs: inputs),
            const SizedBox(height: 10),
            DayCloseCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_orders'.tr,
                              data.totalOrders?.toString() ?? '0',
                              isValueBold: true,
                              inputs: inputs),
                        ),
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_sales'.tr,
                              '$currency ${data.totalSales ?? '0.00'}',
                              valueColor: ColorManager.kSuccessColor,
                              isValueBold: true,
                              inputs: inputs),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_payment_received'.tr,
                              '$currency ${data.totalPaymentReceived ?? '0.00'}',
                              isValueBold: true,
                              inputs: inputs),
                        ),
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_amount_collected_on_sale'
                                  .tr,
                              '$currency ${data.totalAmountCollectedOnSale ?? '0.00'}',
                              inputs: inputs),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_credit_collected_prev'
                                  .tr,
                              '$currency ${data.totalCreditCollected ?? '0.00'}',
                              inputs: inputs),
                        ),
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.business_date'.tr,
                              data.businessDate ?? data.openingDate ?? '-',
                              inputs: inputs),
                        ),
                      ],
                    ),
                  ],
                ),
                inputs: inputs),
            const SizedBox(height: 20),
            DayCloseSectionHeader('daily_sales_close.collection_summary'.tr,
                Icons.payments_outlined,
                inputs: inputs),
            const SizedBox(height: 10),
            DayCloseCard(
                child: Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.total_cash_sales'.tr,
                          '$currency ${data.totalCash ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.total_online_sales'.tr,
                          '$currency ${data.totalOnline ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.total_credit_amount'.tr,
                          '$currency ${data.totalCredit ?? '0.00'}',
                          inputs: inputs),
                    ),
                  ],
                ),
                inputs: inputs),
            const SizedBox(height: 20),
            DayCloseSectionHeader('daily_sales_close.return_refund'.tr,
                Icons.assignment_return_outlined,
                inputs: inputs),
            const SizedBox(height: 10),
            DayCloseCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_returns_sales_return'.tr,
                              '$currency ${data.totalReturns ?? '0.00'}',
                              valueColor: Colors.red,
                              inputs: inputs),
                        ),
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.total_refunds_vouchers'.tr,
                              '$currency ${data.totalRefunds ?? '0.00'}',
                              valueColor: Colors.red,
                              inputs: inputs),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.refund_cash'.tr,
                              '$currency ${data.refundCash ?? '0.00'}',
                              valueColor: Colors.red,
                              inputs: inputs),
                        ),
                        Expanded(
                          child: DayCloseDetailItem(
                              'daily_sales_close.refund_online'.tr,
                              '$currency ${data.refundOnline ?? '0.00'}',
                              valueColor: Colors.red,
                              inputs: inputs),
                        ),
                      ],
                    ),
                  ],
                ),
                inputs: inputs),
            const SizedBox(height: 20),
            DayCloseSectionHeader(
                'daily_sales_close.payment_method_breakdown'.tr,
                Icons.list_alt_outlined,
                inputs: inputs),
            const SizedBox(height: 10),
            DayCloseCard(
                child: Column(children: breakdownRows), inputs: inputs),
          ],
        );
      },
    );
  }
}
