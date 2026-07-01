import 'package:flutter/material.dart';

import 'package:pos_machine/components/build_dialog_box.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';

import 'package:pos_machine/features/billing/domain/product_stock_summary.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_market_add_sheet.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card_actions.dart';

import 'package:pos_machine/features/billing/domain/add_product_with_variant.dart';

import 'package:pos_machine/models/get_product.dart';

import 'package:pos_machine/providers/app_settings_provider.dart';

import 'package:pos_machine/providers/role_provider.dart';

import 'package:pos_machine/resources/color_manager.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/show_product_details.dart';

import 'package:provider/provider.dart';



enum ProductViewMode { grid, list, dense }



void _showProductDetails(BuildContext context, GetProduct product) {
  final appSettingsProvider =
      Provider.of<AppSettingsProvider>(context, listen: false);
  final currency = appSettingsProvider.appSettings?.currency ?? '';

  showProductDetails(
    context,
    product: product,
    isCompact: true,
    currency: currency,
    useBillingProductPermissions: true,
  );
}



Future<void> _openAddSheet(BuildContext context, GetProduct product) async {

  final values = await showMobileMarketAddSheet(

    context: context,

    product: product,

  );

  if (values == null || !context.mounted) return;



  try {

    await addProductWithVariantResolution(

      context: context,

      product: product,

      quantity: values.quantity,

      customPrice: values.customPrice,

      customMrp: values.customMrp,

      selectedSaleUnit: values.selectedSaleUnit,

      addToCartDirectly: true,

    );

  } catch (_) {

    if (context.mounted) {

      showScaffoldError(

        context: context,

        message: BillingMobileErrorMessages.addToCartFailed,

      );

    }

  }

}



class MarketProductGrid extends StatelessWidget {

  const MarketProductGrid({

    super.key,

    required this.products,

    required this.viewMode,

    this.currency = '',

  });



  final List<GetProduct> products;

  final ProductViewMode viewMode;



  /// Tenant currency symbol (from `appSettings.currency`), threaded from

  /// [MarketHomeWidget]. Passed to child cards so they stay provider-free.

  final String currency;



  @override

  Widget build(BuildContext context) {

    final canViewDetails = context.select<RoleProvider, bool>(

      (p) => p.currentUserHasPermissionSync('billing.product.view'),

    );



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

        cacheExtent: 480,

        itemCount: products.length,

        separatorBuilder: (_, __) => const SizedBox(height: 10),

        itemBuilder: (context, index) {

          final product = products[index];

          return ProductListRow(

            product: product,

            currency: currency,

            onInfoTap: canViewDetails

                ? () => _showProductDetails(context, product)

                : null,

            onAddWithOptions: () => _openAddSheet(context, product),

          );

        },

      );

    }



    final isDense = viewMode == ProductViewMode.dense;

    return GridView.builder(

      padding: const EdgeInsets.only(bottom: 16),

      physics: const BouncingScrollPhysics(),

      cacheExtent: 480,

      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: isDense ? 3 : 2,

        mainAxisSpacing: isDense ? 10 : 16,

        crossAxisSpacing: isDense ? 8 : 14,

        childAspectRatio: isDense ? 0.62 : 0.64,

      ),

      itemCount: products.length,

      itemBuilder: (context, index) {

        final product = products[index];

        return ProductCard(

          product: product,

          isDense: isDense,

          currency: currency,

          onInfoTap: canViewDetails

              ? () => _showProductDetails(context, product)

              : null,

          onAddWithOptions: () => _openAddSheet(context, product),

        );

      },

    );

  }

}



class ProductListRow extends StatelessWidget {

  final GetProduct product;

  final VoidCallback? onInfoTap;

  final VoidCallback? onAddWithOptions;

  final String currency;



  const ProductListRow({

    super.key,

    required this.product,

    this.onInfoTap,

    required this.onAddWithOptions,

    this.currency = '',

  });



  bool get _inStock => hasAvailableStock(product.stock?.map((s) => s.quantity));



  String get _displayName => product.productName ?? 'Unnamed Product';



  @override

  Widget build(BuildContext context) {

    final inStock = _inStock;

    final imageUrl = resolveMarketProductImageUrl(product);

    final price = formatMarketProductPrice(product, currency);

    final category = resolveMarketProductCategory(product);



    return Container(

      constraints: const BoxConstraints(minHeight: 88),

      padding: const EdgeInsets.all(10),

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

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.center,

        children: [

          ClipRRect(

            borderRadius: BorderRadius.circular(8),

            child: SizedBox(

              width: 64,

              height: 64,

              child: imageUrl != null

                  ? Image.network(

                      imageUrl,

                      fit: BoxFit.cover,

                      errorBuilder: (context, error, stackTrace) =>

                          _fallbackImage(),

                    )

                  : _fallbackImage(),

            ),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                Tooltip(

                  message: _displayName,

                  waitDuration: const Duration(milliseconds: 400),

                  child: Text(

                    _displayName,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(

                      fontFamily: 'Poppins',

                      fontSize: 14,

                      height: 1.2,

                      fontWeight: FontWeight.w600,

                      color: Colors.black87,

                    ),

                  ),

                ),

                if (category != null) ...[

                  const SizedBox(height: 2),

                  Text(

                    category,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(

                      fontFamily: 'Poppins',

                      fontSize: 11,

                      color: Colors.grey.shade600,

                    ),

                  ),

                ],

                const SizedBox(height: 6),

                Row(

                  children: [

                    Flexible(

                      child: FittedBox(

                        fit: BoxFit.scaleDown,

                        alignment: Alignment.centerLeft,

                        child: Text(

                          price,

                          style: const TextStyle(

                            fontFamily: 'Poppins',

                            color: ColorManager.kPrimaryColor,

                            fontWeight: FontWeight.w700,

                            fontSize: 15,

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 8),

                    _ListStockChip(inStock: inStock),

                  ],

                ),

              ],

            ),

          ),

          const SizedBox(width: 8),

          ProductCardActions(

            onInfoTap: onInfoTap,

            onAddWithOptions: onAddWithOptions,

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

        size: 28,

      ),

    );

  }

}



class _ListStockChip extends StatelessWidget {

  const _ListStockChip({required this.inStock});



  final bool inStock;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),

      decoration: BoxDecoration(

        color: inStock ? Colors.green.shade50 : Colors.red.shade50,

        borderRadius: BorderRadius.circular(4),

      ),

      child: Text(

        inStock ? 'Available' : 'Out of Stock',

        maxLines: 1,

        overflow: TextOverflow.ellipsis,

        style: TextStyle(

          fontFamily: 'Poppins',

          fontSize: 10,

          fontWeight: FontWeight.w600,

          color: inStock ? Colors.green.shade700 : Colors.red.shade700,

        ),

      ),

    );

  }

}


