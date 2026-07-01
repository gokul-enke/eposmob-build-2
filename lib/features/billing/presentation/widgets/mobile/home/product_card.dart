import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/domain/product_stock_summary.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card_actions.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/stock_badge.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onInfoTap,
    required this.onAddWithOptions,
    this.isDense = false,
    this.currency = '',
  });

  final GetProduct product;
  final VoidCallback? onInfoTap;
  final VoidCallback? onAddWithOptions;
  final bool isDense;

  /// Tenant currency symbol (from `appSettings.currency`), supplied by the
  /// parent grid. Defaults to empty so this stays a provider-free widget.
  final String currency;

  bool get _inStock => hasAvailableStock(product.stock?.map((s) => s.quantity));

  String get _displayName => product.productName ?? 'Unnamed Product';

  @override
  Widget build(BuildContext context) {
    final inStock = _inStock;
    final imageUrl = resolveMarketProductImageUrl(product);
    final price = formatMarketProductPrice(product, currency);
    final category = resolveMarketProductCategory(product);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: isDense ? 5 : 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProductImage(imageUrl: imageUrl, compact: isDense),
                Positioned(
                  top: isDense ? 4 : 8,
                  right: isDense ? 4 : 8,
                  child: StockBadge(inStock: inStock, compact: isDense),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDense ? 6 : 10,
              isDense ? 6 : 8,
              isDense ? 6 : 10,
              isDense ? 6 : 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: _displayName,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    _displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: isDense ? 11 : 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (category != null) ...[
                  SizedBox(height: isDense ? 2 : 4),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: isDense ? 9 : 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                SizedBox(height: isDense ? 4 : 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      price,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: ColorManager.kPrimaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: isDense ? 12 : 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isDense ? 4 : 8),
                ProductCardActions(
                  isDense: isDense,
                  expandAdd: true,
                  onInfoTap: onInfoTap,
                  onAddWithOptions: onAddWithOptions,
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
  const _ProductImage({
    this.imageUrl,
    this.compact = false,
  });

  final String? imageUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return _ProductImageFallback(compact: compact);
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _ProductImageFallback(compact: compact),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.blueGrey.shade200,
        size: compact ? 28 : 38,
      ),
    );
  }
}
