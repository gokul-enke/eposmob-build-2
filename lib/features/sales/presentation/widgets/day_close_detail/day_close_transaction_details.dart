import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_text_fields.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';

class DayCloseTransactionDetails extends StatelessWidget {
  const DayCloseTransactionDetails(this.size,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final Size size;
  @override
  Widget build(BuildContext context) {
    return DayCloseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomMinimalTextField(
                      size: size,
                      controller: inputs.controller.orderNumberController,
                      title: 'daily_sales_close.order_number'.tr,
                      hintText: 'daily_sales_close.enter_order_number'.tr,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: CustomDropDownWithSearch<String>(
                      title: 'daily_sales_close.payment_type'.tr,
                      hintText: 'common.all'.tr,
                      value: inputs.controller.paymentTypeFilter,
                      items: const [
                        'All',
                        'CREDIT',
                        'RETURN',
                        'REFUND',
                        'ONLINE',
                        'UPI',
                        'CARD',
                        'CASH',
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          inputs.controller.update(() {
                            inputs.controller.paymentTypeFilter = val;
                            inputs.controller.filterTransactions();
                          });
                        }
                      },
                      displayText: (item) {
                        if (item == 'All') return 'common.all'.tr;
                        final key = item.toLowerCase();
                        return 'billing.payment_method_labels.$key'.tr;
                      },
                      height: size.height *
                          0.048, // Match minimal text field height
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TextButton(
                      onPressed: inputs.controller.resetFilters,
                      child: Text(
                        'general.reset'.tr,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Builder(
                builder: (context) {
                  final currency = inputs.currency;
                  return DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                    columns: [
                      DataColumn(label: Text('daily_sales_close.sl_no'.tr)),
                      DataColumn(label: Text('daily_sales_close.customer'.tr)),
                      DataColumn(label: Text('daily_sales_close.order_no'.tr)),
                      DataColumn(
                        label: Text('daily_sales_close.order_amount'.tr),
                      ),
                      DataColumn(
                          label: Text('daily_sales_close.paid_amount'.tr)),
                      DataColumn(
                        label: Text('daily_sales_close.payment_type'.tr),
                      ),
                      DataColumn(label: Text('daily_sales_close.date'.tr)),
                      DataColumn(label: Text('daily_sales_close.time'.tr)),
                    ],
                    rows: inputs.controller.filteredTransactions
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key + 1;
                      final tx = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(Text(index.toString())),
                          DataCell(Text(tx.customerName ?? '-')),
                          DataCell(Text(tx.orderNumber ?? '-')),
                          DataCell(Text('$currency ${tx.orderAmount ?? 0}')),
                          DataCell(
                            Text(
                              '$currency ${tx.paidAmount ?? 0}',
                              style: const TextStyle(
                                color: ColorManager.kSuccessColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                tx.paymentType ?? '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(Text(tx.date ?? '-')),
                          DataCell(Text(tx.time ?? '-')),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            if (inputs.controller.filteredTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('daily_sales_close.no_transactions_found'.tr),
                ),
              ),
          ],
        ),
        inputs: inputs);
  }
}
