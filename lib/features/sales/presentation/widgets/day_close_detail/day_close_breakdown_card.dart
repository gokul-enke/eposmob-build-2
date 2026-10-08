import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';

class DayCloseBreakdownCard extends StatelessWidget {
  const DayCloseBreakdownCard(
      {super.key,
      required this.inputs,
      required this.title,
      required this.subtitle,
      required this.rows,
      required this.currency});
  final DailyCloseDetailInputs inputs;
  final String title;
  final String subtitle;
  final List<dynamic>? rows;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final normalizedRows = rows
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        [];

    return DayCloseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.21,
                Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            if (normalizedRows.isEmpty)
              Text(
                'daily_sales_close.no_denominations_available'.tr,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                  columns: [
                    DataColumn(
                        label: Text('daily_sales_close.denomination'.tr)),
                    DataColumn(label: Text('daily_sales_close.count'.tr)),
                    DataColumn(label: Text('daily_sales_close.total_col'.tr)),
                  ],
                  rows: normalizedRows.map((row) {
                    final denomination = row['denomination']?.toString() ?? '-';
                    final countText = row['count']?.toString() ?? '0';
                    final count = int.tryParse(countText) ?? 0;
                    final denominationValue = num.tryParse(denomination) ?? 0;
                    final total = denominationValue * count;
                    return DataRow(
                      cells: [
                        DataCell(Text(denomination)),
                        DataCell(Text(count.toString())),
                        DataCell(Text('$currency ${total.toStringAsFixed(2)}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        inputs: inputs);
  }
}
