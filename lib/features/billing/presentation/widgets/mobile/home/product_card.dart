import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/stock_badge.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
    this.isDense = false,
  });

  final GetProduct product;
  final VoidCallback? onAdd;
  final bool isDense;

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProductImage(imageUrl: _imageUrl),
                Positioned(
                  top: 8,
                  right: 8,
                  child: StockBadge(inStock: inStock),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDense ? 8 : 12,
              isDense ? 8 : 10,
              isDense ? 8 : 12,
              isDense ? 8 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.productName ?? 'Unnamed Product',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isDense ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isDense ? 4 : 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayPrice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: ColorManager.kPrimaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: isDense ? 13 : 17,
                        ),
                      ),
                    ),
                    _AddPill(
                      enabled: inStock,
                      isDense: isDense,
                      onTap: onAdd,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return _ProductImageFallback();
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _ProductImageFallback(),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.blueGrey.shade200,
        size: 38,
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({
    required this.enabled,
    required this.onTap,
    this.isDense = false,
  });

  final bool enabled;
  final VoidCallback? onTap;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.green : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(isDense ? 8 : 10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(isDense ? 8 : 10),
        child: SizedBox(
          height: isDense ? 28 : 32,
          width: isDense ? 28 : 52,
          child: Center(
            child: isDense
                ? (enabled
                    ? const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.white,
                      )
                    : Icon(
                        Icons.shopping_cart_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ))
                : (enabled
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
                        size: 17,
                        color: Colors.grey.shade500,
                      )),
          ),
        ),
      ),
    );
  }
}
