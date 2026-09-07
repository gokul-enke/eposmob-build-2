import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Read-only, store-scoped variant and variant-stock information shared by the
/// mobile sheet and desktop product-details dialog.
class ProductVariantDetailsSection extends StatelessWidget {
  const ProductVariantDetailsSection({
    super.key,
    required this.product,
    required this.stocks,
    required this.currency,
    this.activeStoreId,
    this.selectedVariantId,
    this.showPurchasePrice = false,
    this.showMrp = true,
  });

  final GetProduct product;
  final List<Stock> stocks;
  final String currency;
  final int? activeStoreId;
  final int? selectedVariantId;
  final bool showPurchasePrice;
  final bool showMrp;

  String _money(double? value) {
    if (value == null) return 'N/A';
    final amount = value.toStringAsFixed(2);
    return currency.isEmpty ? amount : '$currency $amount';
  }

  String _value(num? value) => value?.toString() ?? 'N/A';

  @override
  Widget build(BuildContext context) {
    final variants = ProductVariantSelection.variantsForStore(
      product,
      activeStoreId: activeStoreId,
    );
    if (variants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 20,
              color: ColorManager.kPrimaryColor,
            ),
            const SizedBox(width: 8),
            const Text(
              'Variants & Variant Stock',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(width: 8),
            _Badge(label: '${variants.length}'),
          ],
        ),
        const SizedBox(height: 10),
        for (final variant in variants)
          _VariantCard(
            variant: variant,
            stocks: stocks
                .where((stock) => stock.productVariantId == variant.id)
                .toList(growable: false),
            selected: variant.id == selectedVariantId,
            money: _money,
            value: _value,
            showPurchasePrice: showPurchasePrice,
            showMrp: showMrp,
          ),
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.stocks,
    required this.money,
    required this.value,
    required this.selected,
    required this.showPurchasePrice,
    required this.showMrp,
  });

  final ProductVariant variant;
  final List<Stock> stocks;
  final String Function(double?) money;
  final String Function(num?) value;
  final bool selected;
  final bool showPurchasePrice;
  final bool showMrp;

  @override
  Widget build(BuildContext context) {
    final label = variant.formattedAttributes.isNotEmpty
        ? variant.formattedAttributes
        : (variant.sku ?? 'Variant ${variant.id}');
    final stockQuantity = stocks.fold<num>(
      0,
      (total, stock) => total + (stock.quantity ?? 0),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? ColorManager.kPrimaryColor : Colors.grey.shade200,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected) ...[
                const _Badge(label: 'Selected'),
                const SizedBox(width: 6),
              ],
              _Badge(label: variant.active ? 'Active' : 'Inactive'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Fact(label: 'product_detail.variant_id'.tr, value: '${variant.id}'),
              _Fact(label: 'product_detail.store_id'.tr, value: '${variant.storeId ?? 'product_detail.all_stores'.tr}'),
              _Fact(label: 'product_detail.sku'.tr, value: variant.sku ?? 'general.na'.tr),
              _Fact(label: 'product_detail.barcode'.tr, value: variant.barcode ?? 'general.na'.tr),
              _Fact(label: 'product_detail.price'.tr, value: money(variant.price)),
              if (showMrp) _Fact(label: 'product_detail.mrp'.tr, value: money(variant.mrp)),
              if (showPurchasePrice)
                _Fact(
                  label: 'product_detail.purchase_price'.tr,
                  value: money(variant.purchasePrice),
                ),
              _Fact(
                label: 'product_detail.available_qty'.tr,
                value: value(variant.availableQuantity ?? variant.quantity),
              ),
              _Fact(label: 'product_detail.stock_row_qty'.tr, value: value(stockQuantity)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stocks.isEmpty
                ? 'product_detail.no_stock_rows'.tr
                : 'product_detail.variant_stock_rows'.trParams({'count': '${stocks.length}'}),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: stocks.isEmpty ? Colors.grey.shade600 : Colors.black87,
            ),
          ),
          if (stocks.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final stock in stocks)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _Fact(label: 'Stock ID', value: '${stock.id ?? 'N/A'}'),
                    _Fact(label: 'Qty', value: value(stock.quantity)),
                    _Fact(
                      label: 'Price',
                      value: stock.price == null
                          ? 'N/A'
                          : money(double.tryParse(stock.price!)),
                    ),
                    if (showMrp)
                      _Fact(
                        label: 'MRP',
                        value: stock.mrp == null
                            ? 'N/A'
                            : money(double.tryParse(stock.mrp!)),
                      ),
                    _Fact(label: 'Supplier', value: stock.supplier ?? 'N/A'),
                    _Fact(label: 'Expiry', value: stock.expiryDate ?? 'N/A'),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorManager.kPrimaryColor,
          ),
        ),
      );
}
