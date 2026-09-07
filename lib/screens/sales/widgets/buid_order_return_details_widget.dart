import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/responsive.dart';
import 'package:provider/provider.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_payment_row.dart';
import '../../../models/order_details.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class OrderReturnsWidget extends StatelessWidget {
  final OrderReturns? orderReturns;
  final List<OrderDetailsModelDataCartItem>? cartItems;
  final OrderDetailsModelDataPriceSummary? priceSummary;

  const OrderReturnsWidget({
    Key? key,
    required this.orderReturns,
    this.cartItems,
    this.priceSummary,
  }) : super(key: key);

  // Calculate return item details by matching with cart items
  Map<String, dynamic> _getReturnItemDetails(OrderReturnItem returnItem) {
    String itemMrp = '0.00';
    String itemRate = '0.00';
    String itemAmount = '0.00';
    final itemQuantity = returnItem.quantity ?? 0;

    // Look for matching item in cartItems
    if (cartItems != null) {
      for (var cartItem in cartItems!) {
        if (cartItem.productName == returnItem.productName) {
          itemRate = cartItem.unitPrice ?? '0.00';
          itemMrp = cartItem.mrp ?? '0.00';
          final amount = itemQuantity * (double.tryParse(itemRate) ?? 0.0);
          itemAmount = amount.toStringAsFixed(2);
          break;
        }
      }
    }

    // If no match found, fall back to average rate calculation
    if (itemRate == '0.00' &&
        itemAmount == '0.00' &&
        orderReturns?.returnTotalAmount != null) {
      final totalReturnAmount =
          double.tryParse(orderReturns!.returnTotalAmount ?? '0.00') ?? 0.0;
      num totalQuantity = 0;
      for (var item in orderReturns!.returnItems!) {
        totalQuantity += item.quantity ?? 0;
      }
      final averageRate =
          totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
      final amount = itemQuantity * averageRate;
      itemRate = averageRate.toStringAsFixed(2);
      itemAmount = amount.toStringAsFixed(2);
    }

    return {
      'mrp': itemMrp,
      'rate': itemRate,
      'amount': itemAmount,
    };
  }

  // Calculate total return amount
  double _calculateReturnTotal() {
    double total = 0.0;
    if (orderReturns?.returnItems != null) {
      for (var returnItem in orderReturns!.returnItems!) {
        final details = _getReturnItemDetails(returnItem);
        total += double.tryParse(details['amount']) ?? 0.0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (orderReturns == null) {
      return Center(
        child: Text('sales_return.no_items_available'.tr),
      );
    }

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? '';
        final returnTotal = _calculateReturnTotal();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Return Items Section
              BuildBoxShadowContainer(
                circleRadius: 7,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(top: 0, left: 8, right: 8),
                offsetValue: const Offset(1, 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Return Order Details",
                      style: ResponsiveWidget.isMobile(context)
                          ? buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s12, 0.30, ColorManager.textColor)
                          : buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s20, 0.35, ColorManager.textColor),
                    ),
                    const SizedBox(height: 15),
                    // Return Items Table
                    _buildReturnItemsTable(context, currency),
                    const SizedBox(height: 20),
                    // Return Summary
                    _buildReturnSummary(context, currency, returnTotal),
                  ],
                ),
              ),
              // Final Summary Section (only if we have price summary)
              if (priceSummary != null)
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  offsetValue: const Offset(1, 1),
                  child: _buildFinalSummary(context, currency, returnTotal),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReturnItemsTable(BuildContext context, String currency) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.6),
        1: FlexColumnWidth(3.5),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(0.8),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.3),
      },
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
          ),
          children: [
            _buildTableCell('Sl#', isHeader: true),
            _buildTableCell('DESCRIPTION', isHeader: true),
            _buildTableCell('MRP', isHeader: true, align: TextAlign.right),
            _buildTableCell('QTY', isHeader: true, align: TextAlign.center),
            _buildTableCell('RATE', isHeader: true, align: TextAlign.right),
            _buildTableCell('AMOUNT', isHeader: true, align: TextAlign.right),
          ],
        ),
        // Data Rows
        ...List.generate(
          orderReturns!.returnItems?.length ?? 0,
          (index) {
            final item = orderReturns!.returnItems![index];
            final details = _getReturnItemDetails(item);
            return TableRow(
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : Colors.grey.shade50,
              ),
              children: [
                _buildTableCell('${index + 1}', align: TextAlign.center),
                _buildTableCell(item.productName ?? 'N/A'),
                _buildTableCell('$currency ${details['mrp']}',
                    align: TextAlign.right),
                _buildTableCell('${item.quantity ?? 0}',
                    align: TextAlign.center),
                _buildTableCell('$currency ${details['rate']}',
                    align: TextAlign.right),
                _buildTableCell('$currency ${details['amount']}',
                    align: TextAlign.right),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTableCell(String text,
      {bool isHeader = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: isHeader ? 12.0 : 10.0,
      ),
      child: Text(
        text,
        textAlign: align,
        style: buildCustomStyle(
          isHeader ? FontWeightManager.semiBold : FontWeightManager.regular,
          isHeader ? FontSize.s12 : FontSize.s11,
          0.18,
          isHeader ? ColorManager.textColor : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildReturnSummary(
      BuildContext context, String currency, double returnTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RETURN SUMMARY',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 10),
        BuildPaymentRow(
          amount: '${orderReturns!.returnItems?.length ?? 0}',
          title: "Total Items",
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount: "$currency ${returnTotal.toStringAsFixed(2)}",
          title: "Total MRP",
          color: ColorManager.textColor,
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount: "$currency ${returnTotal.toStringAsFixed(2)}",
          title: "Net Total",
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColorRed,
          ),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColorRed,
          ),
          color: ColorManager.textColorRed,
        ),
      ],
    );
  }

  Widget _buildFinalSummary(
      BuildContext context, String currency, double returnTotal) {
    final orderTotal =
        priceSummary?.netPayable ?? priceSummary?.netTotal ?? 0.0;
    final finalTotal = orderTotal - returnTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINAL SUMMARY',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s16,
            0.24,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 10),
        BuildPaymentRow(
          amount: "$currency ${orderTotal.toStringAsFixed(2)}",
          title: "Total Purchase",
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount: "$currency ${returnTotal.toStringAsFixed(2)}",
          title: "Total Return",
          color: ColorManager.textColorRed,
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount: "$currency ${finalTotal.toStringAsFixed(2)}",
          title: "Net Total",
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.kButtonGreen,
          ),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.kButtonGreen,
          ),
          color: ColorManager.kButtonGreen,
        ),
      ],
    );
  }
}
