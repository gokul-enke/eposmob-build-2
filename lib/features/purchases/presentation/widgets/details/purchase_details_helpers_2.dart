part of 'purchase_details_view.dart';

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
    required this.discountAmount,
    required this.grossAmount,
    required this.storeName,
    required this.supplierName,
    required this.statusLabel,
    required this.items,
  });

  final String voucherNumber;
  final String purchaseDate;
  final String amountTotal;
  final String discountAmount;
  final String grossAmount;
  final String storeName;
  final String supplierName;
  final String statusLabel;
  final List<_PurchaseViewItem> items;

  static _PurchaseViewData? fromProvider(
    PurchaseDetailsInput purchaseProvider,
    List<GetProduct>? gridProvider,
    List<Category> categoryProvider,
  ) {
    final activeDetails = purchaseProvider.activePurchaseOrderDetails;
    if (activeDetails != null) {
      return _PurchaseViewData.fromMap(
        activeDetails,
        purchaseProvider,
        gridProvider,
        categoryProvider,
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
      discountAmount: '0',
      grossAmount: '${voucher?.amountTotal ?? 0}',
      storeName: purchaseProvider.storeName(voucher?.storeId ?? 0) ?? '-',
      supplierName:
          purchaseProvider.supplierName(voucher?.supplierId ?? 0) ?? '-',
      statusLabel: _DisplayFormatter.orderStatus(voucher?.status),
      items: filteredItems
          .map(
            (item) => _PurchaseViewItem.fromPurchaseItem(
              item,
              gridProvider,
              categoryProvider,
            ),
          )
          .toList(),
    );
  }

  factory _PurchaseViewData.fromMap(
    Map<String, dynamic> raw,
    PurchaseDetailsInput purchaseProvider,
    List<GetProduct>? gridProvider,
    List<Category> categoryProvider,
  ) {
    final rawItems =
        (raw['items'] as List?) ?? (raw['purchase_items'] as List?) ?? [];
    final amountTotal = _DisplayFormatter.toDouble(raw['amount_total']);
    final discountAmount = _DisplayFormatter.toDouble(raw['discount']);

    return _PurchaseViewData(
      voucherNumber: '${raw['voucher_number'] ?? raw['id'] ?? '-'}',
      purchaseDate: _DisplayFormatter.asText(raw['purchase_date']),
      amountTotal: amountTotal.toString(),
      discountAmount: discountAmount.toString(),
      grossAmount: (amountTotal + discountAmount).toString(),
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
              categoryProvider,
            ),
          )
          .toList(),
    );
  }
}

class _PurchaseViewItem {
  const _PurchaseViewItem({
    required this.productName,
    this.variantName,
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
  final String? variantName;
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
    List<GetProduct>? gridProvider,
    List<Category> categoryProvider,
  ) {
    debugPrint('🔍 variant_name raw: ${raw['variant_name']}');
    final product = _DisplayFormatter.findProduct(
      gridProvider,
      _DisplayFormatter.toInt(raw['product_id']),
    );
    final statusDisplay = _DisplayFormatter.itemStatus(raw['status']);

    final categoryId = _DisplayFormatter.toInt(raw['category_id']);
    final categoryNameFromList =
        _DisplayFormatter.findCategoryName(categoryProvider, categoryId);

    return _PurchaseViewItem(
      productName: _DisplayFormatter.firstNonEmpty([
            _DisplayFormatter.asText(raw['product_name']),
            _DisplayFormatter.asText(raw['name']),
            product?.productName,
          ]) ??
          '-',
      variantName: _DisplayFormatter.asText(raw['variant_name']),
      categoryName: _DisplayFormatter.firstNonEmpty([
            categoryNameFromList,
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
    List<GetProduct>? gridProvider,
    List<Category> categoryProvider,
  ) {
    final product = _DisplayFormatter.findProduct(gridProvider, item.productId);
    final statusDisplay = _DisplayFormatter.itemStatus(item.status);

    final categoryId = product?.categoryId;
    final categoryNameFromList =
        _DisplayFormatter.findCategoryName(categoryProvider, categoryId);

    return _PurchaseViewItem(
      productName: _DisplayFormatter.firstNonEmpty([
            item.name,
            product?.productName,
          ]) ??
          '-',
      variantName: null,
      categoryName: categoryNameFromList ?? product?.category?.name ?? '-',
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
