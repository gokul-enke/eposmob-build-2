import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_cart_panel.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_cart_summary_bar.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_category_selector.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_header.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_product_card.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Responsive customer-facing kiosk catalogue.
///
/// This page reads the app's current products, categories, cart, store, and
/// currency. Business actions remain callbacks until kiosk orchestration is
/// implemented in the next phase.
class KioskHomePage extends StatefulWidget {
  final ValueChanged<GetProduct>? onProductPressed;
  final ValueChanged<LocalCartItem>? onCartItemIncrease;
  final ValueChanged<LocalCartItem>? onCartItemDecrease;
  final ValueChanged<LocalCartItem>? onCartItemRemove;
  final VoidCallback? onCheckout;

  const KioskHomePage({
    super.key,
    this.onProductPressed,
    this.onCartItemIncrease,
    this.onCartItemDecrease,
    this.onCartItemRemove,
    this.onCheckout,
  });

  @override
  State<KioskHomePage> createState() => _KioskHomePageState();
}

class _KioskHomePageState extends State<KioskHomePage> {
  static const double _wideLayoutBreakpoint = 1080;
  static const double _categoryRailBreakpoint = 1260;

  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GetProduct> _filteredProducts(List<GetProduct> products) {
    final normalizedQuery = _query.trim().toLowerCase();
    return products.where((product) {
      final categoryMatches = _selectedCategoryId == null ||
          product.categoryId == _selectedCategoryId;
      final queryMatches = normalizedQuery.isEmpty ||
          (product.localizedName ?? product.productName ?? '')
              .toLowerCase()
              .contains(normalizedQuery) ||
          (product.barcode ?? '').toLowerCase().contains(normalizedQuery) ||
          (product.itemCode ?? '').toLowerCase().contains(normalizedQuery);
      return categoryMatches && queryMatches;
    }).toList();
  }

  num _productQuantity(List<LocalCartItem> cart, int? productId) {
    if (productId == null) return 0;
    return cart
        .where((item) => item.product.productId == productId)
        .fold<num>(0, (sum, item) => sum + item.displayQuantity);
  }

  int _cartQuantity(List<LocalCartItem> cart) {
    return cart.fold<num>(0, (sum, item) => sum + item.displayQuantity).ceil();
  }

  double _cartTotal(List<LocalCartItem> cart) {
    return cart.fold<double>(
      0,
      (sum, item) => sum + ((item.price ?? 0) * item.quantity),
    );
  }

  void _showCartSheet({
    required List<LocalCartItem> items,
    required String currency,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: KioskCartPanel(
          items: items,
          currency: currency,
          sheetMode: true,
          onIncrease: widget.onCartItemIncrease,
          onDecrease: widget.onCartItemDecrease,
          onRemove: widget.onCartItemRemove,
          onCheckout: widget.onCheckout ?? () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<LocalProductProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final appSettings = context.watch<AppSettingsProvider>().appSettings;
    final store = context.watch<StoreSessionProvider>().activeStore;

    final products = _filteredProducts(productProvider.sellableProducts);
    final categories = categoryProvider.sellableCategories;
    final cartItems = productProvider.cartItems;
    final currency = appSettings?.currency.trim() ?? '';
    final storeName = store?.storeName?.trim().isNotEmpty == true
        ? store!.storeName!.trim()
        : 'Our store';

    return Scaffold(
      backgroundColor: ColorManager.kBgLightColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
            final showCategoryRail =
                constraints.maxWidth >= _categoryRailBreakpoint;
            final pagePadding = constraints.maxWidth < 700 ? 12.0 : 18.0;
            final cartQuantity = _cartQuantity(cartItems);
            final cartTotal = _cartTotal(cartItems);

            void openCart() => _showCartSheet(
                  items: cartItems,
                  currency: currency,
                );

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding,
                    pagePadding,
                    pagePadding,
                    0,
                  ),
                  child: KioskHeader(
                    storeName: storeName,
                    cartQuantity: cartQuantity,
                    onCartPressed: isWide ? null : openCart,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(pagePadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showCategoryRail) ...[
                          KioskCategorySelector(
                            categories: categories,
                            selectedId: _selectedCategoryId,
                            onSelected: (id) {
                              setState(() => _selectedCategoryId = id);
                            },
                            vertical: true,
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: Column(
                            children: [
                              _SearchField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() => _query = value);
                                },
                              ),
                              if (!showCategoryRail) ...[
                                const SizedBox(height: 14),
                                KioskCategorySelector(
                                  categories: categories,
                                  selectedId: _selectedCategoryId,
                                  onSelected: (id) {
                                    setState(() => _selectedCategoryId = id);
                                  },
                                  vertical: false,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Expanded(
                                child: _ProductGrid(
                                  products: products,
                                  currency: currency,
                                  quantityFor: (id) =>
                                      _productQuantity(cartItems, id),
                                  onAdd: (product) =>
                                      widget.onProductPressed?.call(product),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isWide) ...[
                          const SizedBox(width: 16),
                          KioskCartPanel(
                            items: cartItems,
                            currency: currency,
                            onIncrease: widget.onCartItemIncrease,
                            onDecrease: widget.onCartItemDecrease,
                            onRemove: widget.onCartItemRemove,
                            onCheckout: widget.onCheckout ?? () {},
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isWide)
                  KioskCartSummaryBar(
                    itemCount: cartQuantity,
                    total: cartTotal,
                    currency: currency,
                    onPressed: openCart,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          hintText: 'Search products',
          hintStyle: const TextStyle(color: ColorManager.kGreyColor),
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.search_rounded,
              size: 30,
              color: ColorManager.kGreyColor,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 62),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: ColorManager.kPrimaryColor,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<GetProduct> products;
  final String currency;
  final num Function(int? productId) quantityFor;
  final ValueChanged<GetProduct> onAdd;

  const _ProductGrid({
    required this.products,
    required this.currency,
    required this.quantityFor,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: ColorManager.kGreyColor,
            ),
            SizedBox(height: 12),
            Text(
              'No products available',
              style: TextStyle(
                color: ColorManager.kTitleTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardExtent = constraints.maxWidth < 520 ? 210.0 : 235.0;
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: cardExtent,
            mainAxisExtent: constraints.maxWidth < 520 ? 260 : 285,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: products.length,
          itemBuilder: (_, index) {
            final product = products[index];
            return KioskProductCard(
              product: product,
              quantity: quantityFor(product.productId),
              currency: currency,
              onAdd: () => onAdd(product),
            );
          },
        );
      },
    );
  }
}
