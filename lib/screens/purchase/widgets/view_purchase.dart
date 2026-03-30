import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../components/build_back_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/get_product.dart';
import '../../../models/list_purchase.dart';
import '../../../providers/grid_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewPurchaseWidget extends StatelessWidget {
  const ViewPurchaseWidget({super.key});

  static const double _productColumnWidth = 220;
  static const double _categoryColumnWidth = 160;
  static const double _quantityColumnWidth = 120;
  static const double _unitPriceColumnWidth = 140;
  static const double _totalColumnWidth = 140;
  static const double _batchColumnWidth = 120;
  static const double _expiryColumnWidth = 140;
  static const double _statusColumnWidth = 120;

  static const double _minimumTableWidth = _productColumnWidth +
      _categoryColumnWidth +
      _quantityColumnWidth +
      _unitPriceColumnWidth +
      _totalColumnWidth +
      _batchColumnWidth +
      _expiryColumnWidth +
      _statusColumnWidth;

  @override
  Widget build(BuildContext context) {
    final sideBarController = Get.put(SideBarController());
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    final gridProvider = Provider.of<GridSelectionProvider>(context);
    final viewData = _PurchaseViewData.fromProvider(
      purchaseProvider,
      gridProvider,
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: ColorManager.boxShadowColor,
                      blurRadius: 6,
                      offset: Offset(1, 1),
                    ),
                  ],
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 10.0,
                  ),
                  child: viewData == null
                      ? _EmptyPurchaseState(
                          onBack: () => sideBarController.index.value = 81,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomBackButton(
                              onPressed: () {
                                sideBarController.index.value = 81;
                              },
                              text: 'All Purchases',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Purchase Voucher #${viewData.voucherNumber}',
                                    style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s24,
                                      0.2,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                ),
                                _TopActionButton(
                                  label: 'Print',
                                  icon: Icons.print_outlined,
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Print will be added later.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _SectionCard(
                              title: 'Voucher Information',
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 720;
                                  final blockWidth = isCompact
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 40) / 3;

                                  return Wrap(
                                    spacing: 20,
                                    runSpacing: 26,
                                    children: [
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'Voucher Number',
                                          value: viewData.voucherNumber,
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'Purchase Date',
                                          value: _DisplayFormatter.date(
                                            viewData.purchaseDate,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'Total Amount',
                                          value: _DisplayFormatter.currency(
                                            viewData.amountTotal,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'Supplier',
                                          value: viewData.supplierName,
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'Store',
                                          value: viewData.storeName,
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'Status',
                                          value: viewData.statusLabel,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            _SectionCard(
                              title: 'Purchase Items',
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final tableWidth =
                                      constraints.maxWidth < _minimumTableWidth
                                          ? _minimumTableWidth
                                          : constraints.maxWidth;
                                  final columns =
                                      _TableColumns.forWidth(tableWidth);

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints:
                                          BoxConstraints(minWidth: tableWidth),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _TableRowContainer(
                                            width: tableWidth,
                                            color: const Color(0xFFF9FAFB),
                                            child: Row(
                                              children: [
                                                _TableHeaderCell(
                                                  text: 'PRODUCT',
                                                  width: columns.product,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'CATEGORY',
                                                  width: columns.category,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'QUANTITY',
                                                  width: columns.quantity,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'UNIT PRICE',
                                                  width: columns.unitPrice,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'TOTAL',
                                                  width: columns.total,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'BATCH NO.',
                                                  width: columns.batch,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'EXPIRY DATE',
                                                  width: columns.expiry,
                                                ),
                                                _TableHeaderCell(
                                                  text: 'STATUS',
                                                  width: columns.status,
                                                ),
                                              ],
                                            ),
                                          ),
                                          ...viewData.items.map(
                                            (item) => _TableRowContainer(
                                              width: tableWidth,
                                              child: Row(
                                                children: [
                                                  _TableValueCell(
                                                    text: item.productName,
                                                    width: columns.product,
                                                    isBold: true,
                                                  ),
                                                  _TableValueCell(
                                                    text: item.categoryName,
                                                    width: columns.category,
                                                    textColor:
                                                        const Color(0xFF6B7280),
                                                  ),
                                                  _TableValueCell(
                                                    text: item.quantity,
                                                    width: columns.quantity,
                                                    align: TextAlign.center,
                                                  ),
                                                  _TableValueCell(
                                                    text: _DisplayFormatter
                                                        .currency(
                                                            item.unitPrice),
                                                    width: columns.unitPrice,
                                                    align: TextAlign.center,
                                                  ),
                                                  _TableValueCell(
                                                    text: _DisplayFormatter
                                                        .currency(
                                                            item.totalPrice),
                                                    width: columns.total,
                                                    isBold: true,
                                                    align: TextAlign.center,
                                                  ),
                                                  _TableValueCell(
                                                    text: item.batchNumber,
                                                    width: columns.batch,
                                                    align: TextAlign.center,
                                                    textColor:
                                                        const Color(0xFF6B7280),
                                                  ),
                                                  _TableValueCell(
                                                    text: item.expiryDate,
                                                    width: columns.expiry,
                                                    align: TextAlign.center,
                                                    textColor:
                                                        const Color(0xFF6B7280),
                                                  ),
                                                  _TableStatusCell(
                                                    width: columns.status,
                                                    label: item.statusLabel,
                                                    color: item.statusColor,
                                                    backgroundColor:
                                                        item.statusBackground,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          _TableRowContainer(
                                            width: tableWidth,
                                            color: const Color(0xFFF9FAFB),
                                            child: Row(
                                              children: [
                                                _TableEmptyCell(
                                                    width: columns.product),
                                                _TableEmptyCell(
                                                    width: columns.category),
                                                _TableEmptyCell(
                                                    width: columns.quantity),
                                                _TableValueCell(
                                                  text: 'Total Amount:',
                                                  width: columns.unitPrice,
                                                  align: TextAlign.right,
                                                  isBold: true,
                                                ),
                                                _TableValueCell(
                                                  text: _DisplayFormatter
                                                      .currency(
                                                          viewData.amountTotal),
                                                  width: columns.total,
                                                  align: TextAlign.center,
                                                  isBold: true,
                                                ),
                                                _TableEmptyCell(
                                                    width: columns.batch),
                                                _TableEmptyCell(
                                                    width: columns.expiry),
                                                _TableEmptyCell(
                                                    width: columns.status),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TableColumns {
  const _TableColumns({
    required this.product,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.batch,
    required this.expiry,
    required this.status,
  });

  final double product;
  final double category;
  final double quantity;
  final double unitPrice;
  final double total;
  final double batch;
  final double expiry;
  final double status;

  factory _TableColumns.forWidth(double width) {
    final unit = width / ViewPurchaseWidget._minimumTableWidth;
    return _TableColumns(
      product: ViewPurchaseWidget._productColumnWidth * unit,
      category: ViewPurchaseWidget._categoryColumnWidth * unit,
      quantity: ViewPurchaseWidget._quantityColumnWidth * unit,
      unitPrice: ViewPurchaseWidget._unitPriceColumnWidth * unit,
      total: ViewPurchaseWidget._totalColumnWidth * unit,
      batch: ViewPurchaseWidget._batchColumnWidth * unit,
      expiry: ViewPurchaseWidget._expiryColumnWidth * unit,
      status: ViewPurchaseWidget._statusColumnWidth * unit,
    );
  }
}

class _EmptyPurchaseState extends StatelessWidget {
  const _EmptyPurchaseState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No purchase details available.',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s18,
                0.2,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Open a purchase order from the list to view its details.',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s13,
                0.2,
                Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _TopActionButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EAEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
            child: Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s16,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          Container(
            height: 1,
            color: const Color(0xFFF0F2F4),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.2,
            Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontSize: FontSize.s13,
            fontWeight: FontWeightManager.semiBold,
          ),
        ),
      ),
    );
  }
}

class _TableRowContainer extends StatelessWidget {
  const _TableRowContainer({
    this.color,
    required this.width,
    required this.child,
  });

  final Color? color;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: child,
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell({required this.text, required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.6,
            const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _TableValueCell extends StatelessWidget {
  const _TableValueCell({
    required this.text,
    required this.width,
    this.align = TextAlign.left,
    this.textColor = Colors.black87,
    this.isBold = false,
  });

  final String text;
  final double width;
  final TextAlign align;
  final Color textColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Text(
          text,
          textAlign: align,
          style: buildCustomStyle(
            isBold ? FontWeightManager.bold : FontWeightManager.medium,
            FontSize.s14,
            0.2,
            textColor,
          ),
        ),
      ),
    );
  }
}

class _TableEmptyCell extends StatelessWidget {
  const _TableEmptyCell({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width);
  }
}

class _TableStatusCell extends StatelessWidget {
  const _TableStatusCell({
    required this.width,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final double width;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Align(
          alignment: Alignment.center,
          child: _StatusChip(
            label: label,
            color: color,
            backgroundColor: backgroundColor,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.2,
          color,
        ),
      ),
    );
  }
}

class _PurchaseViewData {
  const _PurchaseViewData({
    required this.voucherNumber,
    required this.purchaseDate,
    required this.amountTotal,
    required this.storeName,
    required this.supplierName,
    required this.statusLabel,
    required this.items,
  });

  final String voucherNumber;
  final String purchaseDate;
  final String amountTotal;
  final String storeName;
  final String supplierName;
  final String statusLabel;
  final List<_PurchaseViewItem> items;

  static _PurchaseViewData? fromProvider(
    PurchaseProvider purchaseProvider,
    GridSelectionProvider gridProvider,
  ) {
    final activeDetails = purchaseProvider.activePurchaseOrderDetails;
    if (activeDetails != null) {
      return _PurchaseViewData.fromMap(
        activeDetails,
        purchaseProvider,
        gridProvider,
      );
    }

    final voucher = purchaseProvider.getVoucherDetails;
    final items = purchaseProvider.getlistPurchaseItemView ?? [];
    if (voucher == null && items.isEmpty) {
      return null;
    }

    final filteredItems = voucher?.purchaseId == null
        ? items
        : items
            .where((item) => item.purchaseId == voucher!.purchaseId)
            .toList();

    return _PurchaseViewData(
      voucherNumber: '${voucher?.voucherNumber ?? '-'}',
      purchaseDate: voucher?.purchaseDate ?? '',
      amountTotal: '${voucher?.amountTotal ?? 0}',
      storeName: purchaseProvider.storeName(voucher?.storeId ?? 0) ?? '-',
      supplierName:
          purchaseProvider.supplierName(voucher?.supplierId ?? 0) ?? '-',
      statusLabel: _DisplayFormatter.orderStatus(voucher?.status),
      items: filteredItems
          .map(
            (item) => _PurchaseViewItem.fromPurchaseItem(item, gridProvider),
          )
          .toList(),
    );
  }

  factory _PurchaseViewData.fromMap(
    Map<String, dynamic> raw,
    PurchaseProvider purchaseProvider,
    GridSelectionProvider gridProvider,
  ) {
    final rawItems =
        (raw['items'] as List?) ?? (raw['purchase_items'] as List?) ?? [];

    return _PurchaseViewData(
      voucherNumber: '${raw['voucher_number'] ?? raw['id'] ?? '-'}',
      purchaseDate: _DisplayFormatter.asText(raw['purchase_date']),
      amountTotal: _DisplayFormatter.asText(raw['amount_total']),
      storeName: _DisplayFormatter.entityName(raw['store']) ??
          purchaseProvider
              .storeName(_DisplayFormatter.toInt(raw['store_id'])) ??
          '-',
      supplierName: _DisplayFormatter.entityName(raw['supplier']) ??
          purchaseProvider
              .supplierName(_DisplayFormatter.toInt(raw['supplier_id'])) ??
          '-',
      statusLabel: _DisplayFormatter.orderStatus(raw['status']),
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => _PurchaseViewItem.fromMap(
              Map<String, dynamic>.from(item),
              gridProvider,
            ),
          )
          .toList(),
    );
  }
}

class _PurchaseViewItem {
  const _PurchaseViewItem({
    required this.productName,
    required this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.batchNumber,
    required this.expiryDate,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackground,
  });

  final String productName;
  final String categoryName;
  final String quantity;
  final String unitPrice;
  final String totalPrice;
  final String batchNumber;
  final String expiryDate;
  final String statusLabel;
  final Color statusColor;
  final Color statusBackground;

  factory _PurchaseViewItem.fromMap(
    Map<String, dynamic> raw,
    GridSelectionProvider gridProvider,
  ) {
    final product = _DisplayFormatter.findProduct(
      gridProvider,
      _DisplayFormatter.toInt(raw['product_id']),
    );
    final statusDisplay = _DisplayFormatter.itemStatus(raw['status']);

    return _PurchaseViewItem(
      productName: _DisplayFormatter.firstNonEmpty([
            _DisplayFormatter.asText(raw['product_name']),
            _DisplayFormatter.asText(raw['name']),
            product?.productName,
          ]) ??
          '-',
      categoryName: _DisplayFormatter.firstNonEmpty([
            _DisplayFormatter.entityName(raw['category']),
            product?.category?.name,
          ]) ??
          '-',
      quantity: _DisplayFormatter.number(raw['quantity']),
      unitPrice: _DisplayFormatter.asText(raw['unit_price']),
      totalPrice: _DisplayFormatter.firstNonEmpty([
            _DisplayFormatter.asText(raw['total_price']),
            _DisplayFormatter.calculatedTotal(
              raw['quantity'],
              raw['unit_price'],
            ),
          ]) ??
          '0',
      batchNumber: _DisplayFormatter.firstNonEmpty([
            _DisplayFormatter.asText(raw['batch_number']),
          ]) ??
          '-',
      expiryDate: _DisplayFormatter.firstNonEmpty([
            _DisplayFormatter.date(
                _DisplayFormatter.asText(raw['expiry_date'])),
          ]) ??
          '-',
      statusLabel: statusDisplay.label,
      statusColor: statusDisplay.color,
      statusBackground: statusDisplay.backgroundColor,
    );
  }

  factory _PurchaseViewItem.fromPurchaseItem(
    PurchaseItem item,
    GridSelectionProvider gridProvider,
  ) {
    final product = _DisplayFormatter.findProduct(gridProvider, item.productId);
    final statusDisplay = _DisplayFormatter.itemStatus(item.status);

    return _PurchaseViewItem(
      productName: _DisplayFormatter.firstNonEmpty([
            item.name,
            product?.productName,
          ]) ??
          '-',
      categoryName: product?.category?.name ?? '-',
      quantity: item.quantity?.toString() ?? '0',
      unitPrice: item.unitPrice?.toString() ?? '0',
      totalPrice: _DisplayFormatter.calculatedTotal(
            item.quantity,
            item.unitPrice,
          ) ??
          '0',
      batchNumber: item.batchNumber?.trim().isNotEmpty == true
          ? item.batchNumber!.trim()
          : '-',
      expiryDate: '-',
      statusLabel: statusDisplay.label,
      statusColor: statusDisplay.color,
      statusBackground: statusDisplay.backgroundColor,
    );
  }
}

class _StatusDisplay {
  const _StatusDisplay({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
}

class _DisplayFormatter {
  static String asText(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    if (text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  static String? firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  static int toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(asText(value)) ?? 0;
  }

  static String number(dynamic value) {
    final text = asText(value);
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text.isEmpty ? '0' : text;
    }
    return parsed.toStringAsFixed(2);
  }

  static String currency(dynamic value) {
    final text = asText(value);
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text.isEmpty ? 'SAR 0.00' : 'SAR $text';
    }
    return 'SAR ${parsed.toStringAsFixed(2)}';
  }

  static String? calculatedTotal(dynamic quantity, dynamic unitPrice) {
    final qty = double.tryParse(asText(quantity));
    final price = double.tryParse(asText(unitPrice));
    if (qty == null || price == null) {
      return null;
    }
    return (qty * price).toStringAsFixed(2);
  }

  static String date(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  static String? entityName(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return firstNonEmpty([
        asText(raw['name']),
        asText(raw['title']),
      ]);
    }
    return null;
  }

  static GetProduct? findProduct(
    GridSelectionProvider gridProvider,
    int? productId,
  ) {
    if (productId == null || productId == 0) {
      return null;
    }

    final products = gridProvider.getProducts;
    if (products == null) {
      return null;
    }

    for (final product in products) {
      if (product.productId == productId) {
        return product;
      }
    }
    return null;
  }

  static String orderStatus(dynamic status) {
    final normalized = asText(status).toLowerCase();
    switch (normalized) {
      case 'fully_received':
        return 'Fully Received';
      case 'partially_received':
        return 'Partially Received';
      case 'pending':
        return 'Pending';
      case 'y':
        return 'Active';
      case 'n':
        return 'Inactive';
      default:
        return normalized.isEmpty
            ? '-'
            : normalized
                .split('_')
                .map(
                  (part) => part.isEmpty
                      ? part
                      : '${part[0].toUpperCase()}${part.substring(1)}',
                )
                .join(' ');
    }
  }

  static _StatusDisplay itemStatus(dynamic status) {
    final normalized = asText(status).toUpperCase();
    switch (normalized) {
      case 'Y':
      case 'RECEIVED':
      case 'FULLY_RECEIVED':
        return const _StatusDisplay(
          label: 'Received',
          color: Color(0xFF0F8A44),
          backgroundColor: Color(0xFFDDF7E5),
        );
      case 'PARTIALLY_RECEIVED':
        return const _StatusDisplay(
          label: 'Partial',
          color: Color(0xFF9A6700),
          backgroundColor: Color(0xFFFFF1CC),
        );
      default:
        return const _StatusDisplay(
          label: 'Pending',
          color: Color(0xFF6B7280),
          backgroundColor: Color(0xFFEFF1F4),
        );
    }
  }
}
