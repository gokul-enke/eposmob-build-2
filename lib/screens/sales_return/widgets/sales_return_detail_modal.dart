import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/sales_return_detail_helper.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'sales_return_responsive.dart';

String? resolveSalesReturnItemReason(
  SalesReturnCart loadedItem,
  Iterable<SalesReturnItem> summaryItems,
) {
  final endpointReason = loadedItem.reason?.trim();
  if (endpointReason != null && endpointReason.isNotEmpty) {
    return endpointReason;
  }

  for (final summaryItem in summaryItems) {
    final matchesCartItem = summaryItem.cartItemId == loadedItem.cartItemId ||
        summaryItem.cartItem.id == loadedItem.cartItemId;
    final summaryReason = summaryItem.reason.trim();
    if (matchesCartItem && summaryReason.isNotEmpty) {
      return summaryReason;
    }
  }

  return null;
}

class SalesReturnDetailModal extends StatefulWidget {
  final SalesReturnOrder order;

  const SalesReturnDetailModal({super.key, required this.order});

  @override
  State<SalesReturnDetailModal> createState() => _SalesReturnDetailModalState();
}

class _SalesReturnDetailModalState extends State<SalesReturnDetailModal> {
  List<SalesReturnCart> _loadedItems = const [];
  bool _isLoadingItems = false;
  String? _itemsError;

  SalesReturnOrder get order => widget.order;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReturnItems();
    });
  }

  Future<void> _loadReturnItems() async {
    final orderNumber = order.order?.orderNumber;
    if (orderNumber == null || orderNumber.trim().isEmpty) return;

    setState(() {
      _isLoadingItems = true;
      _itemsError = null;
    });

    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;
      await salesProvider.fetchSalesReturnItems(
        accessToken: accessToken ?? '',
        orderId: orderNumber,
      );

      if (!mounted) return;
      setState(() {
        _loadedItems = List<SalesReturnCart>.from(
          salesProvider.salesReturnItems,
        );
        _isLoadingItems = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _itemsError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<OrderReturnItem> _returnItemsForPrint() {
    return buildTransactionReturnPrintItems(order.items, _loadedItems);
  }

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
                      'sales_return.details_title'.tr,
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
                            SalesReturnLabelPill(
                              label: 'sales_return.order_info'.tr,
                            ),
                            const SizedBox(height: 14),
                            _buildInfoRow(
                              'sales.order_number_hint'.tr,
                              order.order?.orderNumber ?? '#${order.orderId}',
                            ),
                            _buildInfoRow(
                              'billing.customer'.tr,
                              order.order?.customer?.user?.name ??
                                  'confirmed_orders.na'.tr,
                            ),
                            Consumer<AppSettingsProvider>(
                              builder: (context, settings, _) {
                                final currency =
                                    settings.appSettings?.currency ?? 'INR';
                                final raw = order.order?.grandTotal ?? '0.00';
                                final parsed = double.tryParse(raw);
                                final amount = parsed != null
                                    ? parsed.toStringAsFixed(2)
                                    : raw;
                                return _buildInfoRow(
                                  'sales_return.grand_total'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            _buildInfoRow(
                              'confirmed_orders.payment_method'.tr,
                              order.order?.paymentMethod?.join(', ') ??
                                  'confirmed_orders.na'.tr,
                            ),
                            _buildInfoRow(
                              'sales.date_col'.tr,
                              DateHelper.formatDate(order.createdAt).toString(),
                            ),
                            Consumer<AppSettingsProvider>(
                              builder: (context, settings, _) {
                                final currency =
                                    settings.appSettings?.currency ?? 'INR';
                                final parsed = double.tryParse(
                                  order.totalAmount,
                                );
                                final amount = parsed != null
                                    ? parsed.toStringAsFixed(2)
                                    : order.totalAmount;
                                return _buildInfoRow(
                                  'sales_return.return_total'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'sales_return.status_prefix'.tr,
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s13,
                                    0.20,
                                    Colors.grey.shade600,
                                  ),
                                ),
                                SalesReturnStatusBadge(
                                  label: order.status.toString() == '1'
                                      ? 'sales_return.status_completed'.tr
                                      : 'sales_return.status_pending'.tr,
                                  isCompleted: order.status.toString() == '1',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'sales_return.return_items'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.22,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (order.items.isNotEmpty)
                        if (isPhone)
                          ...order.items.map(_buildMobileItemCard)
                        else
                          _buildItemsTable(context)
                      else if (_isLoadingItems)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _itemsError == null
                                ? 'sales_return.no_items_available'.tr
                                : 'sales_return.err_load_items'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SalesReturnActionRow(
                children: [
                  CustomRoundButton(
                    fct: () {
                      final returnItems = _returnItemsForPrint();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReturnBillPrintPage(
                            returnItems: returnItems,
                            returnTotalAmount: order.totalAmount,
                            orderDate: order.createdAt.toString(),
                            orderNumber: order.order?.orderNumber ??
                                order.orderId.toString(),
                            customerName: order.order?.customer?.user?.name,
                          ),
                        ),
                      );
                    },
                    title: 'general.print'.tr,
                    fontSize: FontSize.s12,
                    height: 44,
                    width: isPhone ? double.infinity : 100,
                  ),
                  CustomRoundButton(
                    fct: () => Navigator.of(context).pop(),
                    title: 'confirmed_orders.close'.tr,
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
                SelectableText(
                  value,
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
                child: SelectableText(
                  value,
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
            salesReturnItemDisplayName(item, _loadedItems),
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
                child: _buildItemMetric(
                  'billing.table_qty'.tr,
                  item.quantity.toString(),
                ),
              ),
              Expanded(
                child: Consumer<AppSettingsProvider>(
                  builder: (context, settings, _) {
                    final currency = settings.appSettings?.currency ?? 'INR';
                    final raw = salesReturnItemUnitPrice(item, _loadedItems);
                    final parsed = double.tryParse(raw);
                    final amount =
                        parsed != null ? parsed.toStringAsFixed(2) : raw;
                    return _buildItemMetric(
                      'sales.price'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: ${salesReturnItemReason(item, _loadedItems)}',
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

  Widget _buildLoadedItemsTable(BuildContext context, bool isPhone) {
    final returnedItems = _loadedItems
        .where((item) => item.isReturned || item.returnedQuantity > 0)
        .toList();
    final items = returnedItems.isNotEmpty ? returnedItems : _loadedItems;

    return _buildItemsTableShell(
      Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FixedColumnWidth(70),
          2: FixedColumnWidth(105),
          3: FlexColumnWidth(2.0),
        },
        children: [
          _buildItemsHeaderRow(),
          ...items.map((item) {
            final quantity = item.returnedQuantity > 0
                ? item.returnedQuantity
                : double.tryParse(item.quantity) ?? 0;
            final reason = resolveSalesReturnItemReason(item, order.items) ??
                (item.isReturned
                    ? 'sales_return.reason_returned_fallback'.tr
                    : '—');
            return TableRow(
              children: [
                _buildTableValue(
                  item.productName.trim().isEmpty
                      ? 'sales_return.unknown_product'.tr
                      : item.productName,
                ),
                _buildTableValue(quantity.toString()),
                _buildTableValueWidget(
                  Consumer<AppSettingsProvider>(
                    builder: (context, settings, _) {
                      final currency = settings.appSettings?.currency ?? 'INR';
                      final parsed = double.tryParse(item.unitPrice);
                      final amount = parsed != null
                          ? parsed.toStringAsFixed(2)
                          : item.unitPrice;
                      return Text('$currency $amount');
                    },
                  ),
                ),
                _buildTableValue(reason),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context) {
    return _buildItemsTableShell(
      Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FixedColumnWidth(70),
          2: FixedColumnWidth(105),
          3: FlexColumnWidth(2.0),
        },
        children: [
          _buildItemsHeaderRow(),
          ...order.items.map((item) {
            return TableRow(
              children: [
                _buildTableValue(
                  salesReturnItemDisplayName(item, _loadedItems),
                ),
                _buildTableValue(item.quantity.toString()),
                _buildTableValueWidget(
                  Consumer<AppSettingsProvider>(
                    builder: (context, settings, _) {
                      final currency = settings.appSettings?.currency ?? 'INR';
                      final raw = salesReturnItemUnitPrice(item, _loadedItems);
                      final parsed = double.tryParse(raw);
                      final amount =
                          parsed != null ? parsed.toStringAsFixed(2) : raw;
                      return Text('$currency $amount');
                    },
                  ),
                ),
                _buildTableValue(salesReturnItemReason(item, _loadedItems)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsTableShell(Widget table) {
    return SalesReturnResponsiveTable(minWidth: 560, table: table);
  }

  TableRow _buildItemsHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      children: [
        _SalesReturnTableHeaderCell('confirmed_orders.product'.tr),
        _SalesReturnTableHeaderCell('billing.table_qty'.tr),
        _SalesReturnTableHeaderCell('sales.price'.tr),
        _SalesReturnTableHeaderCell('sales_return.reason'.tr),
      ],
    );
  }

  Widget _buildTableValue(String value) {
    return _buildTableValueWidget(
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildTableValueWidget(Widget child) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: DefaultTextStyle(
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.15,
          ColorManager.textColor,
        ),
        child: child,
      ),
    );
  }
}

class _SalesReturnTableHeaderCell extends StatelessWidget {
  final String label;

  const _SalesReturnTableHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }
}
