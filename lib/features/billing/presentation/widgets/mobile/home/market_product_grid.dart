import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';

enum ProductViewMode { grid, list, dense }

class MarketProductGrid extends StatelessWidget {
  const MarketProductGrid({
    super.key,
    required this.products,
    required this.viewMode,
  });

  final List<GetProduct> products;
  final ProductViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (viewMode == ProductViewMode.list) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          final inStock = (product.stock?.fold<num>(
                    0,
                    (sum, stock) => sum + (stock.quantity ?? 0),
                  ) ??
                  0) >
              0;

          return ProductListRow(
            product: product,
            onAdd: inStock
                ? () => ProductCartHelper.handleProductSelection(
                      context: context,
                      product: product,
                      addToCartDirectly: true,
                    )
                : null,
          );
        },
      );
    }

    final isDense = viewMode == ProductViewMode.dense;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDense ? 3 : 2,
        mainAxisSpacing: isDense ? 12 : 20,
        crossAxisSpacing: isDense ? 10 : 16,
        childAspectRatio: isDense ? 0.72 : 0.82,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final inStock = (product.stock?.fold<num>(
                  0,
                  (sum, stock) => sum + (stock.quantity ?? 0),
                ) ??
                0) >
            0;

        return ProductCard(
          product: product,
          isDense: isDense,
          onAdd: inStock
              ? () => ProductCartHelper.handleProductSelection(
                    context: context,
                    product: product,
                    addToCartDirectly: true,
                  )
              : null,
        );
      },
    );
  }
}

class ProductListRow extends StatelessWidget {
  final GetProduct product;
  final VoidCallback? onAdd;

  const ProductListRow({
    super.key,
    required this.product,
    required this.onAdd,
  });

  bool get _inStock {
    return (product.stock?.fold<num>(
              0,
              (sum, stock) => sum + (stock.quantity ?? 0),
            ) ??
            0) >
        0;
  }

  String? get _imageUrl {
    final attachments = product.attachment ?? const <Attachment>[];
    if (attachments.isEmpty) return null;
    final raw = attachments.first.file?.toString().trim().isNotEmpty == true
        ? attachments.first.file.toString().trim()
        : attachments.first.filePath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  String get _displayPrice {
    final rawPrice = product.price?.price?.toString() ?? '0';
    final parsed = double.tryParse(rawPrice) ?? 0;
    return 'SAR ${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final inStock = _inStock;

    return Container(
      height: 76,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 60,
              height: 60,
              child: _imageUrl != null
                  ? Image.network(
                      _imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _fallbackImage(),
                    )
                  : _fallbackImage(),
            ),
          ),
          const SizedBox(width: 12),
          // Info (Name, Stock state, Price)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.productName ?? 'Unnamed Product',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _displayPrice,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: ColorManager.kPrimaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            inStock ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        inStock ? 'Available' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: inStock
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Add button
          Material(
            color: inStock ? Colors.green : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: inStock ? onAdd : null,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 36,
                width: 64,
                child: Center(
                  child: inStock
                      ? const Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Icon(
                          Icons.shopping_cart_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.blueGrey.shade200,
        size: 24,
      ),
    );
  }
}
