import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';
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
    this.onDirectAdd,
    this.isDense = false,
    this.currency = '',
    this.stockEnabled = false,
  });

  final GetProduct product;
  final VoidCallback? onInfoTap;
  final VoidCallback? onAddWithOptions;

  /// Tapping the card body (image, name, price) — not the action buttons.
  final VoidCallback? onDirectAdd;
  final bool isDense;

  /// Tenant currency symbol (from `appSettings.currency`), supplied by the
  /// parent grid. Defaults to empty so this stays a provider-free widget.
  final String currency;

  /// When false, cards show only available/out-of-stock (no low-stock state).
  final bool stockEnabled;

  String get _displayName => product.productName ?? 'Unnamed Product';

  @override
  Widget build(BuildContext context) {
    final stockStatus = resolveProductStockDisplayStatus(
      product,
      stockEnabled: stockEnabled,
    );
    final imageUrl = resolveMarketProductImageUrl(product);
    final price = formatMarketProductPrice(product, currency);
    final category = resolveMarketProductCategory(product);

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _CardBodyTapTarget(
              onTap: onDirectAdd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProductImage(
                          imageUrl: imageUrl,
                          compact: isDense,
                        ),
                        Positioned(
                          top: isDense ? 4 : 6,
                          right: isDense ? 4 : 6,
                          child: StockBadge(
                            status: stockStatus,
                            compact: isDense,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDense ? 5 : 8,
                      isDense ? 4 : 6,
                      isDense ? 5 : 8,
                      isDense ? 3 : 4,
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
                              fontSize: isDense ? 10 : 13,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (category != null) ...[
                          SizedBox(height: isDense ? 1 : 2),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: isDense ? 8 : 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        SizedBox(height: isDense ? 2 : 4),
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
                                fontSize: isDense ? 11 : 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDense ? 5 : 8,
              0,
              isDense ? 5 : 8,
              isDense ? 5 : 6,
            ),
            child: ProductCardActions(
              isDense: isDense,
              expandAdd: true,
              onInfoTap: onInfoTap,
              onAddWithOptions: onAddWithOptions,
            ),
          ),
        ],
      ),
    );
  }
}

/// InkWell tap target for the card body. Action buttons are siblings so their
/// taps do not bubble to this handler.
class _CardBodyTapTarget extends StatelessWidget {
  const _CardBodyTapTarget({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }

    return Semantics(
      label: 'Add product to cart',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
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
        size: compact ? 24 : 32,
      ),
    );
  }
}
