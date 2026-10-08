import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'admin_daily_close_action_buttons.dart';
import 'admin_daily_close_table_cell.dart';
import 'admin_daily_close_table_header.dart';
import 'daily_close_list_inputs.dart';

class AdminDailyCloseDailySalesTable extends StatelessWidget {
  const AdminDailyCloseDailySalesTable({super.key, required this.inputs});
  final DailyCloseListInputs inputs;
  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8.0,
      color: Colors.white,
      child: Column(
        children: [
          // Table Header
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
                0: FixedColumnWidth(60), // ID
                1: FlexColumnWidth(2), // Sales Executive
                2: FlexColumnWidth(2), // Phone
                3: FlexColumnWidth(2), // Store
                4: FlexColumnWidth(2), // Closing Period
                5: FlexColumnWidth(1.5), // Total Orders
                6: FlexColumnWidth(2), // Total Sales
                7: FlexColumnWidth(2), // Online Sales
                8: FlexColumnWidth(2), // Cash Sales
                9: FlexColumnWidth(2), // Credit Amount
                10: FixedColumnWidth(100), // Action
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    AdminDailyCloseTableHeader('daily_sales_close.col_id'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.sales_executive'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader('daily_sales_close.col_phone'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader('daily_sales_close.col_store'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.col_closing_period'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.total_orders'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.total_sales'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.online_sales'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.cash_sales'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader(
                        'daily_sales_close.credit_amount'.tr,
                        inputs: inputs),
                    AdminDailyCloseTableHeader('daily_sales_close.action'.tr,
                        inputs: inputs),
                  ],
                ),
              ],
            ),
          ),
          // Table Body
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(60), // ID
                      1: FlexColumnWidth(2), // Sales Executive
                      2: FlexColumnWidth(2), // Phone
                      3: FlexColumnWidth(2), // Store
                      4: FlexColumnWidth(2), // Closing Period
                      5: FlexColumnWidth(1.5), // Total Orders
                      6: FlexColumnWidth(2), // Total Sales
                      7: FlexColumnWidth(2), // Online Sales
                      8: FlexColumnWidth(2), // Cash Sales
                      9: FlexColumnWidth(2), // Credit Amount
                      10: FixedColumnWidth(100), // Action
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...inputs.rows.asMap().entries.map((entry) {
                        int index = entry.key;
                        DailySalesCloseData data = entry.value;

                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.1),
                          ),
                          children: [
                            SizedBox(
                              height: 55,
                              child: AdminDailyCloseTableCell(
                                  data.salesExecutive?.id?.toString() ?? '-',
                                  inputs: inputs),
                            ),
                            SizedBox(
                              height: 55,
                              child: AdminDailyCloseTableCell(
                                  data.salesExecutive?.name ?? '-',
                                  inputs: inputs),
                            ),
                            SizedBox(
                              height: 55,
                              child: AdminDailyCloseTableCell(
                                  data.salesExecutive?.phone ?? '-',
                                  inputs: inputs),
                            ),
                            SizedBox(
                              height: 55,
                              child: AdminDailyCloseTableCell(
                                  data.store?.name ?? '-',
                                  inputs: inputs),
                            ),
                            SizedBox(
                              height: 55,
                              child: AdminDailyCloseTableCell(
                                  data.closingPeriod ?? '-',
                                  inputs: inputs),
                            ),
                            SizedBox(
                              height: 55,
                              child: AdminDailyCloseTableCell(
                                  data.totalOrders?.toString() ?? '0',
                                  inputs: inputs),
                            ),
                            SizedBox(
                              height: 55,
                              child: Builder(
                                builder: (context) {
                                  final currency = inputs.currency;
                                  return AdminDailyCloseTableCell(
                                      "$currency ${data.totalSales ?? '0.00'}",
                                      inputs: inputs);
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Builder(
                                builder: (context) {
                                  final currency = inputs.currency;
                                  return AdminDailyCloseTableCell(
                                      "$currency ${data.totalOnline ?? '0.00'}",
                                      inputs: inputs);
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Builder(
                                builder: (context) {
                                  final currency = inputs.currency;
                                  return AdminDailyCloseTableCell(
                                      "$currency ${data.totalCash ?? '0.00'}",
                                      inputs: inputs);
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Builder(
                                builder: (context) {
                                  final currency = inputs.currency;
                                  return AdminDailyCloseTableCell(
                                      "$currency ${data.totalCredit ?? '0.00'}",
                                      inputs: inputs);
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Center(
                                  child: AdminDailyCloseActionButtons(data,
                                      inputs: inputs)),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
