import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/keyboard_focus_highlight_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/models/get_product.dart';
import '../../../../components/build_container_box.dart';
import '../../../../components/build_dialog_box.dart';
import '../../../../components/build_round_button.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';

enum MenuCardMode { compact, medium, large }

class MenuPanel extends StatefulWidget {
  final ValueChanged<int?> onCategoryChanged;
  final int? activeCategoryId;
  final Function(GetProduct product, int quantity) onItemAdd;
  final bool isCompact;
  final bool useFontCardModeInCompact;
  final Size screenSize;
  final dynamic selectedOrder; // New parameter to receive selected order

  /// Header title — "Menu" for restaurant, "Products" in store mode.
  final String headerTitle;

  const MenuPanel({
    super.key,
    required this.onCategoryChanged,
    required this.activeCategoryId,
    required this.onItemAdd,
    this.isCompact = false,
    this.useFontCardModeInCompact = false,
    required this.screenSize,
    this.selectedOrder, // Make it optional for now, as it might be null
    this.headerTitle = 'Menu',
  });

  @override
  State<MenuPanel> createState() => MenuPanelState();
}

class MenuPanelState extends State<MenuPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();
  final FocusNode _gridFocusNode = FocusNode();
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();
  final List<GlobalKey> _categoryItemKeys = [];
  String _searchQuery = '';
  bool _isResyncingProducts = false;
  int _focusedCategoryIndex = 0;
  int _focusedMenuItemIndex = 0;
  int _gridColumnCount = 1;
  double _gridRowExtent = 120;

  bool get _focusOutlineEnabled {
    try {
      return context.watch<KeyboardFocusHighlightProvider>().enabled;
    } on ProviderNotFoundException {
      return true;
    }
  }

  void focusSearch() {
    _searchFocusNode.requestFocus();
  }

  void focusCategories() {
    _categoryFocusNode.requestFocus();
    _scrollFocusedCategoryIntoView();
  }

  void focusMenuGrid() {
    _gridFocusNode.requestFocus();
  }

  bool get _isConstrainedDesktop =>
      widget.screenSize.width >= 900 &&
      (widget.screenSize.width < 1180 || widget.screenSize.height <= 800);

  MenuCardMode _resolveCardMode(int fontLevel) {
    if (widget.isCompact && !widget.useFontCardModeInCompact) {
      return MenuCardMode.compact;
    }
    if (fontLevel <= 0) return MenuCardMode.compact;
    if (fontLevel == 1) return MenuCardMode.medium;
    return MenuCardMode.large;
  }

  String? _resolvePrimaryImage(GetProduct product) {
    if (product.attachment == null || product.attachment!.isEmpty) return null;
    for (var attachment in product.attachment!) {
      if (attachment.isPrimary == 1 && (attachment.filePath ?? '').isNotEmpty) {
        return attachment.filePath;
      }
    }
    return product.attachment!.first.filePath;
  }

  String _formatMenuPrice(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed?.toStringAsFixed(2) ?? '0.00';
  }

  bool _hasPositiveStock(GetProduct product) {
    return product.stock?.any((stock) => (stock.quantity ?? 0) > 0) ?? false;
  }

  bool _isOutOfStock(GetProduct product, bool stockEnabled) {
    if (!stockEnabled) return false;
    final stock = product.stock;
    return stock != null && stock.isNotEmpty && !_hasPositiveStock(product);
  }

  bool _isMenuItemAvailable(GetProduct product, bool stockEnabled) {
    return !_isOutOfStock(product, stockEnabled);
  }

  void _showProductInfoDialog(
      BuildContext context, GetProduct product, bool compact) {
    final stockEnabled =
        Provider.of<LocalProductProvider>(context, listen: false)
            .isStockEnabled;
    final isOutOfStock = _isOutOfStock(product, stockEnabled);

    // Resolve primary image
    String? primaryImage;
    if (product.attachment != null && product.attachment!.isNotEmpty) {
      for (var attachment in product.attachment!) {
        if (attachment.isPrimary == 1) {
          primaryImage = attachment.filePath;
          break;
        }
      }
      primaryImage ??= product.attachment!.first.filePath;
    }

    // Resolve category name from product model directly
    final String? categoryName = product.category?.name;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 14 : 20,
            vertical: widget.isCompact ? 14 : 20,
          ),
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: widget.isCompact ? 380 : 520,
              constraints: const BoxConstraints(maxHeight: 720),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_menu,
                              color: Color(0xFF059669), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.productName ?? 'Product',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.21,
                                  const Color(0xFF1E293B),
                                ),
                              ),
                              if (product.price?.price != null)
                                Text(
                                  '${product.price!.price}',
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s14,
                                    0.21,
                                    const Color(0xFF059669),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close,
                              color: Colors.grey.shade600, size: 20),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          Container(
                            height: widget.isCompact ? 220 : 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: primaryImage != null
                                ? Image.network(
                                    primaryImage,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey.shade500),
                                  )
                                : Center(
                                    child: Icon(Icons.image,
                                        color: Colors.grey.shade400, size: 36),
                                  ),
                          ),
                          const SizedBox(height: 12),

                          // Tags (VEG/NON-VEG, stock)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ..._buildFoodTypeTags(product, compact),
                              if (isOutOfStock)
                                _buildCompactTag('No Stock',
                                    const Color(0xFF6B7280), compact),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Basic details
                          if (categoryName != null && categoryName.isNotEmpty)
                            _buildKeyValueRow('Category', categoryName),
                          if (product.sku != null &&
                              (product.sku ?? '').toString().isNotEmpty)
                            _buildKeyValueRow('SKU', product.sku!),
                          if (product.mrp != null)
                            _buildKeyValueRow('MRP', '${product.mrp}'),
                          if (product.price?.price != null)
                            _buildKeyValueRow(
                                'Price', '${product.price!.price}'),

                          if (product.barcode != null &&
                              (product.barcode ?? '').toString().isNotEmpty)
                            _buildKeyValueRow(
                                'Barcode', product.barcode.toString()),
                          if (stockEnabled &&
                              product.stock != null &&
                              product.stock!.isNotEmpty)
                            _buildKeyValueRow(
                              'Stock Qty',
                              product.stock!
                                  .map((s) => (s.quantity ?? 0).toString())
                                  .toList()
                                  .join(' / '),
                            ),
                          if (product.description != null &&
                              product.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                product.description!,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.21,
                                  const Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Footer with actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                widget.onItemAdd(product, 1);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: widget.isCompact ? 44 : 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF059669)
                                          .withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_shopping_cart,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add to Order',
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s14,
                                        0.21,
                                        Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
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
        );
      },
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.21,
                const Color(0xFF1E293B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.21,
                const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _categoryFocusNode.dispose();
    _gridFocusNode.dispose();
    _categoryScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _focusedMenuItemIndex = 0;
    });
  }

  List<GetProduct> _rankSearchMatches(
    List<GetProduct> products,
    String query,
  ) {
    if (query.isEmpty) return products;

    final normalizedQuery = query.trim().toLowerCase();
    final indexedProducts = products.indexed.toList();

    int matchRank(GetProduct product) {
      final productNames = _productSearchNames(product)
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty);
      if (productNames.any((name) => name.startsWith(normalizedQuery))) {
        return 0;
      }
      return 1;
    }

    indexedProducts.sort((first, second) {
      final rankCompare = matchRank(first.$2).compareTo(matchRank(second.$2));
      if (rankCompare != 0) return rankCompare;
      return first.$1.compareTo(second.$1);
    });

    return indexedProducts.map((entry) => entry.$2).toList();
  }

  List<String> _productSearchNames(GetProduct product) {
    final names = <String>[];

    void addName(dynamic value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        names.add(text);
      }
    }

    void extractNames(dynamic value) {
      if (value == null) return;

      if (value is String || value is num || value is bool) {
        addName(value);
        return;
      }

      if (value is Map) {
        for (final key in const ['name', 'product_name', 'value', 'text']) {
          if (value.containsKey(key)) {
            addName(value[key]);
          }
        }

        for (final entry in value.entries) {
          final entryKey = entry.key?.toString().toLowerCase() ?? '';
          if (entryKey.contains('language') || entryKey == 'id') {
            continue;
          }
          extractNames(entry.value);
        }
        return;
      }

      if (value is Iterable) {
        for (final item in value) {
          extractNames(item);
        }
      }
    }

    addName(product.productName);
    extractNames(product.names);

    return names.toSet().toList();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _focusedMenuItemIndex = 0;
    });
  }

  void _ensureCategoryItemKeys(int count) {
    while (_categoryItemKeys.length < count) {
      _categoryItemKeys.add(GlobalKey());
    }
    if (_categoryItemKeys.length > count) {
      _categoryItemKeys.removeRange(count, _categoryItemKeys.length);
    }
  }

  KeyEventResult _handleSearchKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      focusMenuGrid();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      focusCategories();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCategoryKey(
    KeyEvent event,
    List<dynamic> categories,
    LocalProductProvider productProvider,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final totalCategories = categories.length + 1;
    if (totalCategories <= 0) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _focusedCategoryIndex =
            (_focusedCategoryIndex + 1).clamp(0, totalCategories - 1);
      });
      _scrollFocusedCategoryIntoView();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _focusedCategoryIndex =
            (_focusedCategoryIndex - 1).clamp(0, totalCategories - 1);
      });
      _scrollFocusedCategoryIntoView();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      focusSearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _selectFocusedCategory(categories, productProvider);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleGridKey(KeyEvent event, List<GetProduct> items) {
    if (event is! KeyDownEvent || items.isEmpty) return KeyEventResult.ignored;
    final maxIndex = items.length - 1;
    int? nextIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      nextIndex = (_focusedMenuItemIndex + 1).clamp(0, maxIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      nextIndex = (_focusedMenuItemIndex - 1).clamp(0, maxIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      nextIndex = (_focusedMenuItemIndex + _gridColumnCount).clamp(0, maxIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusedMenuItemIndex < _gridColumnCount) {
        focusSearch();
        return KeyEventResult.handled;
      }
      nextIndex = (_focusedMenuItemIndex - _gridColumnCount).clamp(0, maxIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      final item = items[_focusedMenuItemIndex.clamp(0, maxIndex)];
      final stockEnabled =
          Provider.of<LocalProductProvider>(context, listen: false)
              .isStockEnabled;
      if (_isMenuItemAvailable(item, stockEnabled)) {
        widget.onItemAdd(item, 1);
      }
      return KeyEventResult.handled;
    }

    if (nextIndex != null) {
      setState(() => _focusedMenuItemIndex = nextIndex!);
      _scrollFocusedMenuItemIntoView();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectFocusedCategory(
    List<dynamic> categories,
    LocalProductProvider productProvider,
  ) {
    setState(() => _focusedMenuItemIndex = 0);
    if (_focusedCategoryIndex == 0) {
      widget.onCategoryChanged(0);
      productProvider.refreshProducts();
      return;
    }

    final category = categories[_focusedCategoryIndex - 1];
    final categoryId = category.categoryId;
    widget.onCategoryChanged(categoryId);
    if (categoryId == 0) {
      productProvider.refreshProducts();
    } else {
      productProvider.listAllProducts(categoryId: categoryId);
    }
  }

  void _scrollFocusedCategoryIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_categoryScrollController.hasClients) return;
      if (_focusedCategoryIndex >= 0 &&
          _focusedCategoryIndex < _categoryItemKeys.length) {
        final keyContext =
            _categoryItemKeys[_focusedCategoryIndex].currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: 0.5,
          );
          return;
        }
      }
      final viewportWidth =
          _categoryScrollController.position.viewportDimension;
      final target =
          (_focusedCategoryIndex * 150.0 - viewportWidth / 2 + 75).clamp(
        0.0,
        _categoryScrollController.position.maxScrollExtent,
      );
      _categoryScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollFocusedMenuItemIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_gridScrollController.hasClients) return;
      final row = (_focusedMenuItemIndex / _gridColumnCount).floor();
      final target = (row * _gridRowExtent).clamp(
        0.0,
        _gridScrollController.position.maxScrollExtent,
      );
      _gridScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _withKeyboardOutline({
    required Widget child,
    required bool focused,
    required BorderRadius borderRadius,
  }) {
    final shouldOutline = _focusOutlineEnabled && focused;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: shouldOutline ? const Color(0xFFF59E0B) : Colors.transparent,
          width: shouldOutline ? 3 : 0,
        ),
        boxShadow: shouldOutline
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  int _resolveGridColumnCount(MenuCardMode cardMode, double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return widget.isCompact ? 1 : 2;
    }

    final targetCardWidth = switch (cardMode) {
      MenuCardMode.compact =>
        widget.isCompact ? (_isConstrainedDesktop ? 96.0 : 136.0) : 190.0,
      MenuCardMode.medium => _isConstrainedDesktop ? 88.0 : 112.0,
      MenuCardMode.large => _isConstrainedDesktop ? 146.0 : 180.0,
    };
    final minColumns = widget.isCompact ? 1 : 2;
    final maxColumns = switch (cardMode) {
      MenuCardMode.compact =>
        widget.isCompact ? (_isConstrainedDesktop ? 6 : 5) : 7,
      MenuCardMode.medium => _isConstrainedDesktop ? 7 : 9,
      MenuCardMode.large => _isConstrainedDesktop ? 4 : 6,
    };

    return (availableWidth / targetCardWidth)
        .floor()
        .clamp(minColumns, maxColumns)
        .toInt();
  }

  double _resolveGridAspectRatio(MenuCardMode cardMode) {
    return switch (cardMode) {
      MenuCardMode.compact =>
        widget.isCompact ? (_isConstrainedDesktop ? 1.24 : 1.56) : 1.70,
      MenuCardMode.medium => _isConstrainedDesktop ? 0.90 : 0.64,
      MenuCardMode.large => _isConstrainedDesktop ? 1.18 : 1.42,
    };
  }

  Future<void> _resyncProductsFromEmptyState() async {
    if (_isResyncingProducts) return;

    setState(() {
      _isResyncingProducts = true;
    });

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      await localProductProvider.fetchProductsFromAPI(refresh: true);

      if (localProductProvider.sellableProducts.isEmpty) {
        await syncProvider.syncAllData(context);
      }

      if (!mounted) return;

      if (localProductProvider.sellableProducts.isEmpty) {
        showScaffoldError(
          context: context,
          message:
              'Resync finished but no products were returned. Check tenant/API key or internet.',
        );
      } else {
        showScaffold(
          context: context,
          message: 'Products resynced successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Failed to resync products: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResyncingProducts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CategoryProvider, LocalProductProvider>(
      builder: (context, categoryProvider, productProvider, _) {
        final fontProvider =
            Provider.of<AppFontProvider>(context, listen: true);
        if (categoryProvider.isLoading &&
            (categoryProvider.category?.isEmpty ?? true)) {
          return const BuildBoxShadowContainer(
            circleRadius: 10,
            margin: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final categories = categoryProvider.category ?? [];
        final selectedCategoryId = widget.activeCategoryId ?? 0;
        final bool isProductsLoading =
            productProvider.isLoading || _isResyncingProducts;

        // Get products for selected category - only show sellable products in billing
        List<GetProduct> items = [];
        if (selectedCategoryId == 0) {
          // "ALL" category - show all sellable products
          items = productProvider.sellableFilteredProducts;
        } else {
          // Specific category - filter sellable products by category
          items = productProvider.sellableProducts
              .where((product) => product.categoryId == selectedCategoryId)
              .toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          items = items.where((product) {
            return _productSearchNames(product)
                .any((name) => name.toLowerCase().contains(_searchQuery));
          }).toList();
          items = _rankSearchMatches(items, _searchQuery);
        }

        final int fontLevel = fontProvider.fontSizeLevel;
        final cardMode = _resolveCardMode(fontLevel);
        _ensureCategoryItemKeys(categories.length + 1);

        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced header
              Container(
                padding: EdgeInsets.all(widget.isCompact ? 10.0 : 12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF059669).withOpacity(0.05),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade100,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: const Color(0xFF059669),
                        size: widget.isCompact ? 14 : 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.headerTitle,
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          widget.isCompact ? FontSize.s14 : FontSize.s16,
                          0.30,
                          const Color(0xFF1E293B)),
                    ),
                    SizedBox(width: widget.isCompact ? 10 : 14),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Focus(
                          onKeyEvent: (node, event) => _handleSearchKey(event),
                          child: TextField(
                            focusNode: _searchFocusNode,
                            controller: _searchController,
                            onTap: focusSearch,
                            onSubmitted: (_) => focusMenuGrid(),
                            onEditingComplete: focusMenuGrid,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search menu items...',
                              hintStyle: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s13,
                                0.21,
                                Colors.grey.shade500,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey.shade500,
                                size: widget.isCompact ? 16 : 18,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.grey.shade500,
                                        size: widget.isCompact ? 16 : 18,
                                      ),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                              border: InputBorder.none,
                              isDense: true,
                              alignLabelWithHint: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: widget.isCompact ? 10 : 12,
                                vertical: widget.isCompact ? 10 : 12,
                              ),
                            ),
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.21,
                              const Color(0xFF1E293B),
                            ),
                            textAlignVertical: TextAlignVertical.center,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: widget.isCompact ? 10 : 12),
                    if (items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${items.length} items',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s11, 0.21, const Color(0xFF059669)),
                        ),
                      ),
                  ],
                ),
              ),
              // Enhanced categories with modern styling
              if (categories.isNotEmpty)
                Container(
                  height: widget.isCompact ? 56 : 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.touch,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: Focus(
                        focusNode: _categoryFocusNode,
                        onKeyEvent: (node, event) => _handleCategoryKey(
                          event,
                          categories,
                          productProvider,
                        ),
                        child: ListView.separated(
                          controller: _categoryScrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                              horizontal: widget.isCompact ? 12 : 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length + 1,
                          itemBuilder: (_, idx) {
                            final isAll = idx == 0;
                            final category = isAll ? null : categories[idx - 1];
                            final categoryId = isAll ? 0 : category!.categoryId;
                            final categoryName = isAll
                                ? 'All'
                                : category!.categoryName ?? 'Unknown';
                            final active = isAll
                                ? selectedCategoryId == 0
                                : categoryId == selectedCategoryId;
                            final isKeyboardFocused =
                                _categoryFocusNode.hasFocus &&
                                    _focusedCategoryIndex == idx;
                            final chip = KeyedSubtree(
                              key: _categoryItemKeys[idx],
                              child: _withKeyboardOutline(
                                focused: isKeyboardFocused,
                                borderRadius: BorderRadius.circular(26),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _focusedCategoryIndex = idx;
                                          _focusedMenuItemIndex = 0;
                                        });
                                        if (isAll) {
                                          widget.onCategoryChanged(0);
                                          productProvider.refreshProducts();
                                        } else if (categoryId == 0) {
                                          widget.onCategoryChanged(categoryId);
                                          productProvider.refreshProducts();
                                        } else {
                                          widget.onCategoryChanged(categoryId);
                                          productProvider.listAllProducts(
                                              categoryId: categoryId);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              widget.isCompact ? 16 : 20,
                                          vertical: widget.isCompact ? 8 : 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? const Color(0xFF2563EB)
                                              : Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                            color: active
                                                ? const Color(0xFF2563EB)
                                                : Colors.grey.shade200,
                                            width: 1,
                                          ),
                                          boxShadow: active
                                              ? [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF2563EB)
                                                            .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            categoryName,
                                            style: buildCustomStyle(
                                              FontWeightManager.semiBold,
                                              widget.isCompact
                                                  ? FontSize.s12
                                                  : FontSize.s13,
                                              0.21,
                                              active
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                            return chip;
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              // Menu items
              Expanded(
                child: isProductsLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Loading menu items...',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s14,
                                0.21,
                                ColorManager.textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  size: 48,
                                  color:
                                      ColorManager.textColor.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No items in this category',
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s14,
                                      0.21,
                                      ColorManager.textColor.withOpacity(0.7)),
                                ),
                                const SizedBox(height: 12),
                                CustomRoundButton(
                                  title: _isResyncingProducts
                                      ? 'Resyncing...'
                                      : 'Resync Products',
                                  fct: _isResyncingProducts
                                      ? () {}
                                      : _resyncProductsFromEmptyState,
                                  width: 170,
                                  height: 36,
                                  fontSize: 11,
                                  boxColor: ColorManager.kPrimaryColor,
                                  borderColor: ColorManager.kPrimaryColor,
                                  textColor: Colors.white,
                                  radius: 8,
                                ),
                              ],
                            ),
                          )
                        : MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: ScrollConfiguration(
                              behavior:
                                  ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.stylus,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      _resolveGridColumnCount(
                                    cardMode,
                                    constraints.maxWidth,
                                  );
                                  final childAspectRatio =
                                      _resolveGridAspectRatio(cardMode);
                                  final gridSpacing =
                                      widget.isCompact && _isConstrainedDesktop
                                          ? 4.0
                                          : (widget.isCompact ? 6.0 : 8.0);
                                  final gridPadding =
                                      widget.isCompact && _isConstrainedDesktop
                                          ? 4.0
                                          : (widget.isCompact ? 6.0 : 8.0);
                                  _gridColumnCount = crossAxisCount;
                                  final itemWidth = (constraints.maxWidth -
                                          (gridPadding * 2) -
                                          ((crossAxisCount - 1) *
                                              gridSpacing)) /
                                      crossAxisCount;
                                  _gridRowExtent =
                                      (itemWidth / childAspectRatio) +
                                          gridSpacing;
                                  if (_focusedMenuItemIndex >= items.length) {
                                    _focusedMenuItemIndex = items.length - 1;
                                  }

                                  return Focus(
                                    focusNode: _gridFocusNode,
                                    onKeyEvent: (node, event) =>
                                        _handleGridKey(event, items),
                                    child: GridView.builder(
                                      controller: _gridScrollController,
                                      padding: EdgeInsets.all(gridPadding),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: gridSpacing,
                                        crossAxisSpacing: gridSpacing,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                      itemCount: items.length,
                                      itemBuilder: (_, idx) {
                                        final item = items[idx];
                                        final isKeyboardFocused =
                                            _gridFocusNode.hasFocus &&
                                                _focusedMenuItemIndex == idx;
                                        Widget card;
                                        switch (cardMode) {
                                          case MenuCardMode.compact:
                                            card = _buildMenuItem(item,
                                                widget.isCompact, context);
                                            break;
                                          case MenuCardMode.medium:
                                            card = _buildLegacyImageMenuItem(
                                                item, context);
                                            break;
                                          case MenuCardMode.large:
                                            card = _buildMenuItemRich(
                                              item,
                                              context,
                                              imageFlex: 6,
                                              detailsFlex: 9,
                                              titleLines: 2,
                                              showCategory: false,
                                            );
                                        }
                                        return _withKeyboardOutline(
                                          focused: isKeyboardFocused,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: card,
                                        );
                                      },
                                      physics: const BouncingScrollPhysics(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItemRich(
    GetProduct item,
    BuildContext context, {
    required int imageFlex,
    required int detailsFlex,
    required int titleLines,
    required bool showCategory,
  }) {
    final stockEnabled =
        Provider.of<LocalProductProvider>(context, listen: false)
            .isStockEnabled;
    final isAvailable = _isMenuItemAvailable(item, stockEnabled);
    final imageUrl = _resolvePrimaryImage(item);
    final denseMode = !showCategory;

    return Container(
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? () => widget.onItemAdd(item, 1) : null,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: imageFlex,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImageFallback(),
                          )
                        : _buildImageFallback(),
                  ),
                ),
              ),
              Expanded(
                flex: detailsFlex,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    denseMode ? 8 : 10,
                    denseMode ? 6 : 8,
                    denseMode ? 8 : 10,
                    denseMode ? 6 : 10,
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.productName ?? 'Unknown Product',
                                maxLines: titleLines,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  denseMode ? FontSize.s12 : FontSize.s13,
                                  0.21,
                                  isAvailable
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF059669).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatMenuPrice(item.price?.price),
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  denseMode ? FontSize.s11 : FontSize.s12,
                                  0.21,
                                  const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: denseMode ? 6 : 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: denseMode ? 3 : 4,
                                runSpacing: denseMode ? 2 : 4,
                                children: [
                                  ..._buildFoodTypeTags(item, false),
                                  if (!_hasFoodType(item) && isAvailable)
                                    _buildCompactTag('Available',
                                        const Color(0xFF059669), false),
                                  if (!isAvailable)
                                    _buildCompactTag('No Stock',
                                        const Color(0xFF6B7280), false),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showProductInfoDialog(
                                    context, item, false),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF2563EB),
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (showCategory)
                          Text(
                            item.category?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s11,
                              0.21,
                              const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade400,
        size: 30,
      ),
    );
  }

  Widget _buildLegacyImageMenuItem(GetProduct item, BuildContext context) {
    final stockEnabled =
        Provider.of<LocalProductProvider>(context, listen: false)
            .isStockEnabled;
    final isAvailable = _isMenuItemAvailable(item, stockEnabled);

    final imageUrl = _resolvePrimaryImage(item);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
    final price = _formatMenuPrice(item.price?.price);
    final denseMode = _isConstrainedDesktop;

    return Container(
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? () => widget.onItemAdd(item, 1) : null,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: denseMode ? 3 : 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: Container(
                        color: Colors.grey.shade50,
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(
                                Icons.inventory_2_outlined,
                                size: 32,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: !isAvailable
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: denseMode ? 4 : 6,
                                vertical: denseMode ? 2 : 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                'No Stock',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  denseMode ? FontSize.s8 : FontSize.s9,
                                  0.21,
                                  const Color(0xFF64748B),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              _showProductInfoDialog(context, item, false),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: EdgeInsets.all(denseMode ? 3 : 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.48),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: denseMode ? 13 : 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: denseMode ? 5 : 7,
                          vertical: denseMode ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: ColorManager.kPrimaryColor.withOpacity(0.92),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          '$currency $price',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            denseMode ? FontSize.s9 : FontSize.s11,
                            0.21,
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: denseMode ? 2 : 3,
                child: Padding(
                  padding: EdgeInsets.all(denseMode ? 6 : 8),
                  child: Text(
                    '${item.productName ?? 'Unknown Product'} / ${item.unit ?? ''}',
                    maxLines: denseMode ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      denseMode ? FontSize.s11 : FontSize.s13,
                      0.21,
                      isAvailable
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(GetProduct item, bool compact, BuildContext context) {
    final stockEnabled =
        Provider.of<LocalProductProvider>(context, listen: false)
            .isStockEnabled;
    final isAvailable = _isMenuItemAvailable(item, stockEnabled);
    final extraDense = compact && _isConstrainedDesktop;

    return Container(
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(extraDense ? 8 : 12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(extraDense ? 0.03 : 0.04),
            blurRadius: extraDense ? 4 : 8,
            offset: Offset(0, extraDense ? 1 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable
              ? () {
                  widget.onItemAdd(item, 1);
                }
              : null,
          borderRadius: BorderRadius.circular(extraDense ? 8 : 12),
          child: Padding(
            padding: EdgeInsets.all(extraDense ? 6.0 : (compact ? 8.0 : 12.0)),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween, // Distribute content evenly
                children: [
                  // Top section: Image, name, price, description
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with name and price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.productName ?? 'Unknown Product',
                              maxLines: extraDense ? 3 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                extraDense
                                    ? FontSize.s10
                                    : (compact ? FontSize.s10 : FontSize.s12),
                                0.21,
                                isAvailable
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(width: extraDense ? 3 : 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: extraDense ? 3 : (compact ? 4 : 6),
                              vertical: extraDense ? 2 : (compact ? 2 : 3),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(extraDense ? 5 : 6),
                            ),
                            child: Text(
                              _formatMenuPrice(item.price?.price),
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                extraDense
                                    ? FontSize.s9
                                    : (compact ? FontSize.s9 : FontSize.s11),
                                0.23,
                                isAvailable
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF059669).withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: extraDense ? 1 : (compact ? 2 : 4)),
                      // productName
                      if (!extraDense && item.productName != null)
                        Text(
                          item.productName.toString(),
                          maxLines: compact ? 1 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            compact ? FontSize.s8 : FontSize.s10,
                            0.21,
                            const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),

                  // Bottom section: Tags and add button with proper spacing
                  Column(
                    children: [
                      SizedBox(
                          height: extraDense
                              ? 3
                              : compact
                                  ? 4
                                  : 6), // Keep separation while avoiding tiny bottom overflow
                      // Tags and add button
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: compact ? 3 : 4,
                              runSpacing: 2,
                              children: [
                                // Check for FOOD_TYPE in product_props
                                if (!extraDense)
                                  ...(_buildFoodTypeTags(item, compact)),
                                // Show unit if no food type is available
                                if ((extraDense || !_hasFoodType(item)) &&
                                    isAvailable)
                                  _buildCompactTag('Available',
                                      const Color(0xFF059669), true),
                                if (!isAvailable)
                                  _buildCompactTag('No Stock',
                                      const Color(0xFF6B7280), true),
                              ],
                            ),
                          ),
                          if (isAvailable)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showProductInfoDialog(
                                    context, item, compact),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: EdgeInsets.all(
                                      extraDense ? 3 : (compact ? 3 : 4)),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: const Color(0xFF2563EB),
                                    size: extraDense ? 11 : (compact ? 12 : 14),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTag(String text, Color color, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: buildCustomStyle(
            FontWeightManager.semiBold, FontSize.s8, 0.14, color),
      ),
    );
  }

  /// Check if product has FOOD_TYPE property
  bool _hasFoodType(GetProduct product) {
    if (product.productProps == null || product.productProps!.isEmpty) {
      return false;
    }
    return product.productProps!.any((prop) => prop.propsCode == 'FOOD_TYPE');
  }

  /// Get food type from product props
  String? _getFoodType(GetProduct product) {
    if (product.productProps == null || product.productProps!.isEmpty) {
      return null;
    }

    final foodTypeProp = product.productProps!.firstWhere(
        (prop) => prop.propsCode == 'FOOD_TYPE',
        orElse: () => ProductProp());

    return foodTypeProp.masterValue;
  }

  /// Build food type tags (VEG/NON-VEG)
  List<Widget> _buildFoodTypeTags(GetProduct product, bool compact) {
    final foodType = _getFoodType(product);
    if (foodType == null) return [];

    switch (foodType.toUpperCase()) {
      case 'VEG':
        return [
          _buildVegNonVegTag('VEG', const Color(0xFF059669), compact, true)
        ];
      case 'NON-VEG':
      case 'NONVEG':
      case 'NON VEG':
      case 'NON_VEG':
        return [
          _buildVegNonVegTag('NON VEG', const Color(0xFFDC2626), compact, false)
        ];
      default:
        // If it's some other food type, show it as is
        return [_buildCompactTag(foodType, const Color(0xFF2563EB), compact)];
    }
  }

  /// Build VEG/NON-VEG tag with dot indicator
  Widget _buildVegNonVegTag(
      String text, Color color, bool compact, bool isVeg) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicator
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s8,
              0.14,
              color,
            ),
          ),
        ],
      ),
    );
  }
}
