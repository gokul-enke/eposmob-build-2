import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../../domain/supplier_report.dart';
import 'supplier_report_empty_state.dart';
import 'supplier_report_mobile_card.dart';

class SupplierReportTable extends StatelessWidget {
  const SupplierReportTable(
      {super.key,
      required this.rows,
      required this.initializing,
      required this.onView});
  final Map<String, SupplierTransactionSummary> rows;
  final bool initializing;
  final ValueChanged<SupplierTransactionSummary> onView;
  @override
  Widget build(BuildContext context) {
    if (initializing) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator.adaptive()));
    }

    if (MediaQuery.of(context).size.width < 768) {
      return Expanded(
        child: rows.isEmpty
            ? const SupplierReportEmptyState()
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (ctx, i) {
                  final entry = rows.entries.elementAt(i);
                  return SupplierReportMobileCard(
                      summary: entry.value, onView: onView);
                },
              ),
      );
    }

    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.only(top: 5),
        circleRadius: 7,
        offsetValue: const Offset(2, 2),
        blurRadius: 8.0,
        color: Colors.white,
        child: Column(
          children: [
            // Fixed table header
            Container(
              decoration: const BoxDecoration(
                color: ColorManager.tableBGColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 2.0,
                  ),
                ],
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.0), // Supplier Name
                  1: FlexColumnWidth(1.5), // Total Debit
                  2: FlexColumnWidth(1.5), // Total Credit
                  3: FlexColumnWidth(1.5), // Balance
                  4: FlexColumnWidth(1.2), // Transaction Count
                  5: FlexColumnWidth(1.0), // Action
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeader(
                          'supplier_transaction_report.supplier_name_col'.tr),
                      _buildTableHeader(
                          'supplier_transaction_report.total_debit_col'.tr),
                      _buildTableHeader(
                          'supplier_transaction_report.total_credit_col'.tr),
                      _buildTableHeader(
                          'supplier_transaction_report.balance'.tr),
                      _buildTableHeader(
                          'supplier_transaction_report.transactions'.tr),
                      _buildTableHeader(
                          'supplier_transaction_report.action_col'.tr),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable table body
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: rows.isEmpty
                      ? const SupplierReportEmptyState()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2.0), // Supplier Name
                              1: FlexColumnWidth(1.5), // Total Debit
                              2: FlexColumnWidth(1.5), // Total Credit
                              3: FlexColumnWidth(1.5), // Balance
                              4: FlexColumnWidth(1.2), // Transaction Count
                              5: FlexColumnWidth(1.0), // Action
                            },
                            border: null,
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: rows.entries
                                .map((entry) =>
                                    _buildSupplierRow(entry.value, context))
                                .toList(),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  TableRow _buildSupplierRow(
      SupplierTransactionSummary summary, BuildContext context) {
    // Alternate row colors for better readability
    final int index = rows.keys.toList().indexOf(summary.supplierId);

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: SelectableText(
                summary.displayName ?? 'supplier_transaction_report.unknown'.tr,
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black,
                ),
              ),
            ),
          ),
        ),
        _buildTableCell(
          summary.totalDebit.toStringAsFixed(2),
        ),
        _buildTableCell(
          summary.totalCredit.toStringAsFixed(2),
        ),
        _buildTableCell(
          summary.balance.toStringAsFixed(2),
          isBalance: true,
          balance: summary.balance,
        ),
        _buildTableCell(
          summary.transactionCount.toString(),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: BuildBoxShadowContainer(
              margin: const EdgeInsets.only(left: 5, right: 5),
              circleRadius: 5,
              child: IconButton(
                icon: Icon(
                  Icons.visibility,
                  size: 18,
                  color: ColorManager.kPrimaryColor.withOpacity(0.9),
                ),
                onPressed: () {
                  onView(summary);
                },
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String content,
      {bool isBalance = false, double? balance}) {
    Color textColor = Colors.black;
    if (isBalance && balance != null) {
      textColor = balance < 0 ? Colors.red : Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        content,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          textColor,
        ),
      ),
    );
  }
}
