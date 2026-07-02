import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'sales_return_responsive.dart';

class SalesReturnDetailModal extends StatelessWidget {
  final SalesReturnOrder order;

  const SalesReturnDetailModal({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isPhone = salesReturnIsPhone(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 40,
        vertical: isPhone ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isPhone ? screenSize.width : 640,
          maxHeight: screenSize.height * (isPhone ? 0.92 : 0.85),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(isPhone ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Return Details',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.28,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SalesReturnContentCard(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SalesReturnLabelPill(label: 'ORDER INFORMATION'),
                            const SizedBox(height: 14),
                            _buildInfoRow(
                              'Order Number',
                              order.order?.orderNumber ??
                                  '#${order.orderId}',
                            ),
                            _buildInfoRow(
                              'Customer',
                              order.order?.customer?.user?.name ?? 'N/A',
                            ),
                            Consumer<AppSettingsProvider>(
                              builder: (context, settings, _) {
                                final currency =
                                    settings.appSettings?.currency ?? 'INR';
                                final raw =
                                    order.order?.grandTotal ?? '0.00';
                                final parsed = double.tryParse(raw);
                                final amount = parsed != null
                                    ? parsed.toStringAsFixed(2)
                                    : raw;
                                return _buildInfoRow(
                                    'Grand Total', '$currency $amount');
                              },
                            ),
                            _buildInfoRow(
                              'Payment Method',
                              order.order?.paymentMethod?.join(', ') ??
                                  'N/A',
                            ),
                            _buildInfoRow(
                              'Date',
                              DateHelper.formatDate(order.createdAt)
                                  .toString(),
                            ),
                            Consumer<AppSettingsProvider>(
                              builder: (context, settings, _) {
                                final currency =
                                    settings.appSettings?.currency ?? 'INR';
                                final parsed =
                                    double.tryParse(order.totalAmount);
                                final amount = parsed != null
                                    ? parsed.toStringAsFixed(2)
                                    : order.totalAmount;
                                return _buildInfoRow(
                                    'Return Total', '$currency $amount');
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Status: ',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s13,
                                    0.20,
                                    Colors.grey.shade600,
                                  ),
                                ),
                                SalesReturnStatusBadge(
                                  label: order.status.toString() == '1'
                                      ? 'Completed'
                                      : 'Pending',
                                  isCompleted:
                                      order.status.toString() == '1',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Return Items',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.22,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isPhone)
                        ...order.items.map(_buildMobileItemCard)
                      else
                        _buildItemsTable(context),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SalesReturnActionRow(
                children: [
                  CustomRoundButton(
                    fct: () {
                      List<OrderReturnItem> returnItems =
                          order.items.map((item) {
                        return OrderReturnItem(
                          id: item.id,
                          productName:
                              item.cartItem.product?.name ?? 'Unknown',
                          quantity: item.quantity is int
                              ? item.quantity as int
                              : (item.quantity as double).toInt(),
                          reason: item.reason,
                        );
                      }).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReturnBillPrintPage(
                            returnItems: returnItems,
                            returnTotalAmount: order.totalAmount,
                            orderDate: order.createdAt.toString(),
                            orderNumber: order.order?.orderNumber ??
                                order.orderId.toString(),
                            customerName:
                                order.order?.customer?.user?.name,
                          ),
                        ),
                      );
                    },
                    title: 'Print',
                    fontSize: FontSize.s12,
                    height: 44,
                    width: isPhone ? double.infinity : 100,
                  ),
                  CustomRoundButton(
                    fct: () => Navigator.of(context).pop(),
                    title: 'Close',
                    fontSize: FontSize.s12,
                    height: 44,
                    width: isPhone ? double.infinity : 100,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 400;
          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  '$label:',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.20,
                    Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileItemCard(SalesReturnItem item) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.cartItem.product?.name ?? 'Unknown Product',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.20,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildItemMetric('Qty', item.quantity.toString()),
              ),
              Expanded(
                child: Consumer<AppSettingsProvider>(
                  builder: (context, settings, _) {
                    final currency =
                        settings.appSettings?.currency ?? 'INR';
                    final raw = item.price;
                    final parsed = double.tryParse(raw);
                    final amount = parsed != null
                        ? parsed.toStringAsFixed(2)
                        : raw;
                    return _buildItemMetric('Price', '$currency $amount');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: ${item.reason}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.18,
              Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s10,
            0.15,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable(BuildContext context) {
    return SalesReturnResponsiveTable(
      minWidth: 560,
      table: DataTable(
        headingTextStyle: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
        dataTextStyle: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.15,
          ColorManager.textColor,
        ),
        horizontalMargin: 16,
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Price'), numeric: true),
          DataColumn(label: Text('Reason')),
        ],
        rows: order.items.map((item) {
          return DataRow(cells: [
            DataCell(Text(
              item.cartItem.product?.name ?? 'Unknown Product',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )),
            DataCell(Text(item.quantity.toString())),
            DataCell(
              Consumer<AppSettingsProvider>(
                builder: (context, settings, _) {
                  final currency =
                      settings.appSettings?.currency ?? 'INR';
                  final raw = item.price;
                  final parsed = double.tryParse(raw);
                  final amount = parsed != null
                      ? parsed.toStringAsFixed(2)
                      : raw;
                  return Text('$currency $amount');
                },
              ),
            ),
            DataCell(Text(
              item.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
