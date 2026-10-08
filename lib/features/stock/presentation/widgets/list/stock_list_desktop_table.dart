import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'stock_list_quantity_colors.dart';

class StockListDesktopTable extends StatelessWidget {
  final List<ListStockModelData> listStockModelDataList;
  final bool canViewPurchasePrice;
  final bool variantEnabled;
  final Widget Function(ListStockModelData) buildActions;
  const StockListDesktopTable(
      {super.key,
      required this.listStockModelDataList,
      required this.canViewPurchasePrice,
      required this.variantEnabled,
      required this.buildActions});
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
              columnWidths:
                  _desktopStockColumnWidths(context, canViewPurchasePrice),
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('stock.col_product'.tr),
                    _buildTableHeader('stock.barcode'.tr),
                    _buildTableHeader('stock.retail_price'.tr),
                    _buildTableHeader('stock.mrp'.tr),
                    if (canViewPurchasePrice)
                      _buildTableHeader('stock.purchase_price'.tr),
                    _buildTableHeader('stock.quantity'.tr),
                    _buildTableHeader('stock.unit'.tr),
                    _buildTableHeader('stock.rack'.tr),
                    _buildTableHeader('stock.order_date'.tr),
                    _buildTableHeader('stock.action'.tr),
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
                    columnWidths: _desktopStockColumnWidths(
                        context, canViewPurchasePrice),
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...listStockModelDataList.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final stock = entry.value;
                        final barcode = stock.barCode ?? 'stock.na'.tr;
                        debugPrint(
                            '🔍 DISPLAY BARCODE: "$barcode" for product: ${stock.productName}');
                        final qtyColors = stockListQuantityColors(stock);
                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.1),
                          ),
                          children: [
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SelectableText(
                                          '${stock.productName}',
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.13,
                                            Colors.black,
                                          ),
                                        ),
                                        if (variantEnabled &&
                                            stock.productVariantId != null)
                                          Text(
                                            stock.variantName
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? stock.variantName!
                                                : 'Variant #${stock.productVariantId}',
                                            textAlign: TextAlign.center,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s10,
                                              0.13,
                                              Colors.deepPurple.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          barcode,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.13,
                                            Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (barcode.isNotEmpty &&
                                          barcode != 'stock.na'.tr) ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(
                                                ClipboardData(text: barcode));
                                            showScaffold(
                                              context: context,
                                              message:
                                                  'stock.copied_to_clipboard'
                                                      .tr
                                                      .replaceAll('@label',
                                                          'stock.barcode'.tr),
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
                            _buildTableCell('${stock.retailPrice}'),
                            _buildTableCell(stock.mrp ?? 'stock.na'.tr),
                            if (canViewPurchasePrice)
                              _buildTableCell(
                                  stock.purchaseRate ?? 'stock.na'.tr),
                            _buildTableCell(
                              '${stock.qty}',
                              textColor: qtyColors.$1 ?? Colors.black,
                              bgColor: qtyColors.$2,
                            ),
                            _buildTableCell('${stock.unit}'),
                            _buildTableCell(stock.rack ?? 'stock.na'.tr),
                            _buildTableCell(
                              DateHelper.formatISODate(stock.orderDate ?? ""),
                            ),
                            Center(
                              child: buildActions(stock),
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

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {Color? textColor, Color? bgColor}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              textColor ?? Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Map<int, TableColumnWidth> _desktopStockColumnWidths(
      BuildContext context, bool showPurchasePrice) {
    final widths = <double>[
      1.7,
      1.1,
      1.0,
      0.9,
      if (showPurchasePrice) 0.9,
      0.7,
      0.8,
      0.9,
      1.2,
      MediaQuery.of(context).size.width < 1200 ? 2.5 : 1.8,
    ];
    return {
      for (var index = 0; index < widths.length; index++)
        index: FlexColumnWidth(widths[index]),
    };
  }
}
