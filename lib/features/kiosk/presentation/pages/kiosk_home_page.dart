import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/models/kiosk_order_draft.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_cart_review_page.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_product_options_page.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_cart_panel.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_cart_summary_bar.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_category_selector.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_header.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_inactivity_guard.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_product_card.dart';
import 'package:pos_machine/models/category_list.dart';
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
  static const double _wideLayoutBreakpoint = 1120;
  static const double _categoryRailBreakpoint = 1180;

  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  String _query = '';
  List<LocalCartItem> _draftCartItems = <LocalCartItem>[];

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

  bool _requiresProductOptions(GetProduct product) {
    return kioskProductHasOptions(product);
  }

  List<LocalCartItem> _cartItems(List<LocalCartItem> providerItems) {
    if (widget.onProductPressed != null || widget.onCheckout != null) {
      return providerItems;
    }
    return _draftCartItems;
  }

  List<LocalCartItem> _ensureDraftCart(List<LocalCartItem> _) {
    return _draftCartItems;
  }

  Future<void> _selectProduct({
    required GetProduct product,
    required String currency,
    required List<LocalCartItem> providerItems,
  }) async {
    if (widget.onProductPressed != null) {
      widget.onProductPressed!(product);
      return;
    }

    final LocalCartItem? item;
    if (_requiresProductOptions(product)) {
      item = await showKioskProductOptionsModal(
        context,
        product: product,
        currency: currency,
      );
    } else {
      item = createKioskDraftItem(product: product, quantity: 1);
    }
    if (!mounted || item == null) return;
    final selectedItem = item;
    setState(() {
      final items = _ensureDraftCart(providerItems);
      final matchingIndex = items.indexWhere(
        (row) =>
            row.product.productId == selectedItem.product.productId &&
            row.variantId == selectedItem.variantId &&
            row.saleUnitId == selectedItem.saleUnitId &&
            row.comment == selectedItem.comment,
      );
      if (matchingIndex < 0) {
        items.add(selectedItem);
      } else {
        items[matchingIndex].quantity += selectedItem.quantity;
      }
    });
  }

  void _increaseItem(
    LocalCartItem item,
    List<LocalCartItem> providerItems,
  ) {
    if (widget.onCartItemIncrease != null) {
      widget.onCartItemIncrease!(item);
      return;
    }
    setState(() {
      final items = _ensureDraftCart(providerItems);
      final index = items.indexWhere((row) => row.lineId == item.lineId);
      if (index < 0) return;
      final row = items[index];
      row.quantity = row.toBaseQuantity(row.displayQuantity + 1);
    });
  }

  void _decreaseItem(
    LocalCartItem item,
    List<LocalCartItem> providerItems,
  ) {
    if (widget.onCartItemDecrease != null) {
      widget.onCartItemDecrease!(item);
      return;
    }
    setState(() {
      final items = _ensureDraftCart(providerItems);
      final index = items.indexWhere((row) => row.lineId == item.lineId);
      if (index < 0) return;
      final row = items[index];
      final next = row.displayQuantity - 1;
      if (next <= 0) {
        items.removeAt(index);
      } else {
        row.quantity = row.toBaseQuantity(next);
      }
    });
  }

  void _removeItem(
    LocalCartItem item,
    List<LocalCartItem> providerItems,
  ) {
    if (widget.onCartItemRemove != null) {
      widget.onCartItemRemove!(item);
      return;
    }
    setState(() {
      _ensureDraftCart(providerItems)
          .removeWhere((row) => row.lineId == item.lineId);
    });
  }

  void _openCartReview({
    required List<LocalCartItem> items,
    required String currency,
  }) {
    if (widget.onCheckout != null) {
      widget.onCheckout!();
      return;
    }
    final draftItems = _ensureDraftCart(items);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KioskCartReviewPage(
          items: draftItems,
          currency: currency,
          onChanged: (updatedItems) {
            if (!mounted) return;
            setState(() {
              _draftCartItems =
                  updatedItems.map(copyKioskCartItem).toList(growable: true);
            });
          },
        ),
      ),
    );
  }

  Future<bool> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'Your selected products will be removed and this kiosk will return to the welcome screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep ordering'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _cancelOrder() async {
    if (_cartItems(context.read<LocalProductProvider>().cartItems).isNotEmpty &&
        !await _confirmCancel()) {
      return;
    }
    if (!mounted) return;
    setState(() => _draftCartItems = <LocalCartItem>[]);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<LocalProductProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final appSettings = context.watch<AppSettingsProvider>().appSettings;
    final store = context.watch<StoreSessionProvider>().activeStore;

    final products = _filteredProducts(productProvider.sellableProducts);
    final configuredCategories = categoryProvider.sellableCategories;
    final categories = configuredCategories.isNotEmpty
        ? configuredCategories
        : _categoriesFromProducts(productProvider.sellableProducts);
    final providerCartItems = productProvider.cartItems;
    final cartItems = _cartItems(providerCartItems);
    final currency = appSettings?.currency.trim() ?? '';
    final storeName = store?.storeName?.trim().isNotEmpty == true
        ? store!.storeName!.trim()
        : 'Our store';

    return KioskInactivityGuard(
      onReset: () {
        setState(() => _draftCartItems = <LocalCartItem>[]);
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: ColorManager.kBgLightColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
              final portrait = constraints.maxHeight > constraints.maxWidth;
              final showCategoryRail =
                  constraints.maxWidth >= _categoryRailBreakpoint ||
                      (portrait && constraints.maxWidth >= 740);
              final pagePadding = constraints.maxWidth < 700
                  ? KioskSpacing.sm
                  : KioskSpacing.lg;
              final cartQuantity = _cartQuantity(cartItems);
              final cartTotal = _cartTotal(cartItems);

              return Stack(
                children: [
                  Column(
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
                          onCancelPressed: _cancelOrder,
                        ),
                      ),
                      Expanded(
                        child: AnimatedPadding(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.fromLTRB(
                            pagePadding,
                            pagePadding,
                            pagePadding,
                            !isWide && cartQuantity > 0 ? 112 : pagePadding,
                          ),
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
                                const SizedBox(width: KioskSpacing.md),
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
                                      const SizedBox(height: KioskSpacing.md),
                                      KioskCategorySelector(
                                        categories: categories,
                                        selectedId: _selectedCategoryId,
                                        onSelected: (id) {
                                          setState(
                                              () => _selectedCategoryId = id);
                                        },
                                        vertical: false,
                                      ),
                                    ],
                                    const SizedBox(height: KioskSpacing.md),
                                    Expanded(
                                      child: _ProductGrid(
                                        products: products,
                                        currency: currency,
                                        quantityFor: (id) =>
                                            _productQuantity(cartItems, id),
                                        bottomPadding: 8,
                                        onAdd: (product) => _selectProduct(
                                          product: product,
                                          currency: currency,
                                          providerItems: providerCartItems,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isWide) ...[
                                const SizedBox(width: KioskSpacing.md),
                                KioskCartPanel(
                                  items: cartItems,
                                  currency: currency,
                                  onIncrease: (item) =>
                                      _increaseItem(item, providerCartItems),
                                  onDecrease: (item) =>
                                      _decreaseItem(item, providerCartItems),
                                  onRemove: (item) =>
                                      _removeItem(item, providerCartItems),
                                  onCheckout: () => _openCartReview(
                                    items: cartItems,
                                    currency: currency,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isWide)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        ignoring: cartQuantity == 0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          offset: cartQuantity > 0
                              ? Offset.zero
                              : const Offset(0, 1.15),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: cartQuantity > 0 ? 1 : 0,
                            child: KioskCartSummaryBar(
                              itemCount: cartQuantity,
                              total: cartTotal,
                              currency: currency,
                              onPressed: () => _openCartReview(
                                items: cartItems,
                                currency: currency,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
      height: 68,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: KioskType.body.copyWith(
          color: ColorManager.kTitleTextColor,
          fontSize: 18,
        ),
        decoration: InputDecoration(
          hintText: 'Search products',
          hintStyle: KioskType.body.copyWith(
            color: ColorManager.kGreyColor,
            fontSize: 18,
          ),
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
            borderRadius: BorderRadius.circular(KioskRadius.control),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KioskRadius.control),
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
  final double bottomPadding;

  const _ProductGrid({
    required this.products,
    required this.currency,
    required this.quantityFor,
    required this.onAdd,
    this.bottomPadding = 8,
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
        final columns = constraints.maxWidth < 720
            ? 2
            : constraints.maxWidth < 860
                ? 3
                : 4;
        final cardHeight = constraints.maxWidth < 520 ? 292.0 : 306.0;
        return GridView.builder(
          padding: EdgeInsets.only(bottom: bottomPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: KioskSpacing.md,
            mainAxisSpacing: KioskSpacing.md,
          ),
          itemCount: products.length,
          itemBuilder: (_, index) {
            final product = products[index];
            return KioskProductCard(
              product: product,
              quantity: quantityFor(product.productId),
              currency: currency,
              customizable: _productRequiresOptions(product),
              onAdd: () => onAdd(product),
            );
          },
        );
      },
    );
  }
}

bool _productRequiresOptions(GetProduct product) {
  return kioskProductHasOptions(product);
}

List<Category> _categoriesFromProducts(List<GetProduct> products) {
  final categories = <int, Category>{};
  for (final product in products) {
    final id = product.categoryId;
    final name = product.category?.name?.trim();
    if (id == null || name == null || name.isEmpty) continue;
    categories.putIfAbsent(
      id,
      () => Category(
        categoryId: id,
        categoryName: name,
        categorySlug: product.category?.slug,
      ),
    );
  }
  final result = categories.values.toList();
  result.sort(
    (a, b) => (a.categoryName ?? '').compareTo(b.categoryName ?? ''),
  );
  return result;
}
