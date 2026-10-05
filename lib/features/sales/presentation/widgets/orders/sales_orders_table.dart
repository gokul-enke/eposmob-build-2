import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'sales_status_chip.dart';
import 'sales_table_cell.dart';
import 'sales_table_header.dart';

class SalesOrdersTable extends StatelessWidget {
  const SalesOrdersTable(
      {super.key,
      required this.displayedOrders,
      required this.paginationFrom,
      required this.currency,
      required this.actionsBuilder});
  final List<ListOrderModelData> displayedOrders;
  final int paginationFrom;
  final String currency;
  final Widget Function(BuildContext, ListOrderModelData) actionsBuilder;
  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 14,
      offsetValue: const Offset(0, 3),
      blurRadius: 10.0,
      color: Colors.white,
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth =
              constraints.maxWidth < 860 ? 860 : constraints.maxWidth;
          final bool needsHorizontalScroll = constraints.maxWidth < 860;

          Widget buildTableContent() {
            return SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: ColorManager.tableBGColor,
                      border: Border(
                        bottom: BorderSide(color: Color(0x1F000000), width: 1),
                      ),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(60),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(3),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(2),
                        6: FlexColumnWidth(1.8),
                        7: FixedColumnWidth(150),
                      },
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            SalesTableHeader(text: 'sales.si_no'.tr),
                            SalesTableHeader(
                                text: 'sales.order_number_short'.tr),
                            SalesTableHeader(text: 'billing.customer'.tr),
                            SalesTableHeader(text: 'sales.date_col'.tr),
                            SalesTableHeader(text: 'sales.items_col'.tr),
                            SalesTableHeader(text: 'sales.amount_col'.tr),
                            SalesTableHeader(text: 'sales.status'.tr),
                            SalesTableHeader(text: 'billing.table_actions'.tr),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                              0: FixedColumnWidth(60),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(3),
                              3: FlexColumnWidth(2),
                              4: FlexColumnWidth(1.5),
                              5: FlexColumnWidth(2),
                              6: FlexColumnWidth(1.8),
                              7: FixedColumnWidth(150),
                            },
                            border: null,
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              ...displayedOrders.asMap().entries.map((entry) {
                                int index = entry.key;
                                ListOrderModelData order = entry.value;

                                int serialNumber = paginationFrom + index;

                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0
                                        ? Colors.white
                                        : Colors.grey.withOpacity(0.1),
                                  ),
                                  children: [
                                    SizedBox(
                                      height: 55,
                                      child:
                                          SalesTableCell(text: "$serialNumber"),
                                    ),
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: SizedBox(
                                        height: 55,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "#${order.orderNumber}",
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s9,
                                                        0.13,
                                                        Colors.black,
                                                      ),
                                                    ),
                                                    if (order.receiptNumber
                                                            ?.trim()
                                                            .isNotEmpty ==
                                                        true)
                                                      Text(
                                                        order.receiptNumber!
                                                            .trim(),
                                                        textAlign:
                                                            TextAlign.center,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .regular,
                                                          FontSize.s8,
                                                          0.10,
                                                          ColorManager
                                                              .kPrimaryColor,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (order.customerReceiptNumber !=
                                                  null) ...[
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () {
                                                    Clipboard.setData(ClipboardData(
                                                        text: order
                                                            .customerReceiptNumber!));
                                                    showScaffold(
                                                      context: context,
                                                      message:
                                                          'sales.order_number_copied'
                                                              .tr,
                                                    );
                                                  },
                                                  child: const Icon(
                                                    Icons.copy,
                                                    size: 14,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 55,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 16.0),
                                        child: Center(
                                          child: SelectableText(
                                            (order.customerName?.isNotEmpty ==
                                                    true)
                                                ? order.customerName!
                                                : (order.customerDetails?.phone
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? order
                                                        .customerDetails!.phone!
                                                    : "NA"),
                                            textAlign: TextAlign.center,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s11,
                                              0.18,
                                              ColorManager.kTextColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 55,
                                      child: SalesTableCell(
                                          text: DateHelper.formatYearMonthDay(
                                              order.orderDate!)),
                                    ),
                                    SizedBox(
                                      height: 55,
                                      child: SalesTableCell(
                                          text:
                                              "${order.cartItems?.length ?? 0}"),
                                    ),
                                    SizedBox(
                                      height: 55,
                                      child: Builder(
                                        builder: (context) {
                                          return SalesTableCell(
                                              text:
                                                  "$currency ${AmountHelper.formatAmount(order.grantTotal ?? 0.0)}");
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      height: 55,
                                      child: Center(
                                          child: SalesStatusChip(
                                              status:
                                                  order.status ?? "pending")),
                                    ),
                                    SizedBox(
                                      height: 55,
                                      child: Center(
                                          child:
                                              actionsBuilder(context, order)),
                                    ),
                                  ],
                                );
                              }),
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

          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: needsHorizontalScroll
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: constraints.maxHeight,
                      child: buildTableContent(),
                    ),
                  )
                : buildTableContent(),
          );
        },
      ),
    );
  }
}
