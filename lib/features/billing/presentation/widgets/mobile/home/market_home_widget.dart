import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_grid.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/new_order_button.dart';
import 'package:pos_machine/features/billing/presentation/pages/add_product_mobile.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/helpers/product_search_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/product_autocomplete_list_mobile.dart';
import 'package:provider/provider.dart';

class MarketHomeWidget extends StatefulWidget {
  const MarketHomeWidget({
    super.key,
    required this.autocompleteProductKey,
    required this.onProcessBarcode,
    required this.onClearProductFields,
    required this.focusTextField,
  });

  final GlobalKey autocompleteProductKey;
  final ValueChanged<String> onProcessBarcode;
  final VoidCallback onClearProductFields;
  final VoidCallback focusTextField;

  @override
  State<MarketHomeWidget> createState() => _MarketHomeWidgetState();
}

class _MarketHomeWidgetState extends State<MarketHomeWidget> {
  static const _controller = BillingMobileMarketController();
  String _selectedCategory = BillingMobileMarketController.allProductsCategory;
  String _searchQuery = '';
  ProductViewMode _viewMode = ProductViewMode.grid;
  bool _isResyncingProducts = false;
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  void _clearAndRefocusProductSearch() {
    if (!mounted) return;

    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _resyncProductsFromEmptyState() async {
    if (_isResyncingProducts) return;

    setState(() => _isResyncingProducts = true);

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
          message: 'settings_ui.msg_resync_empty'.tr,
        );
      } else {
        showScaffold(
          context: context,
          message: 'settings_ui.msg_resync_success'.trParams({
            'count': '${localProductProvider.sellableProducts.length}',
          }),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'settings_ui.msg_resync_failed'.trParams({
          'error': e.toString(),
        }),
      );
    } finally {
      if (mounted) {
        setState(() => _isResyncingProducts = false);
      }
    }
  }

  Future<void> _openAddProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductMobileScreen(),
      ),
    );
    if (mounted) {
      widget.focusTextField();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Selector<AppSettingsProvider, bool?>(
          selector: (_, provider) => provider.appSettings?.barcodeSales,
          builder: (context, barcodeSales, _) {
            if (barcodeSales == null) {
              return const SizedBox.shrink();
            }

            return Selector<LocalProductProvider, List<GetProduct>>(
              selector: (_, provider) => provider.sellableProducts,
              builder: (context, sellableProducts, _) {
                final itemCodeEnabled =
                    context.select<AppSettingsProvider, bool>(
                        (p) => p.appSettings?.itemCodeEnabled ?? false);
                final products = filterMarketHomeProducts(
                  controller: _controller,
                  products: sellableProducts,
                  query: _searchQuery,
                  selectedCategory: _selectedCategory,
                  itemCodeEnabled: itemCodeEnabled,
                );
                final categories = _controller.categories(sellableProducts);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ProductEntryHeader(
                            barcodeSales: barcodeSales,
                            autocompleteProductKey:
                                widget.autocompleteProductKey,
                            productList: sellableProducts,
                            onProcessBarcode: widget.onProcessBarcode,
                            onClearProductFields: widget.onClearProductFields,
                            focusTextField: widget.focusTextField,
                          ),
                        ),
                        const SizedBox(width: 8),
                        NewOrderButton(
                          onTap: _openAddProduct,
                          compact: MediaQuery.sizeOf(context).width < 380,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: _entryDecoration(
                          hintText: 'billing.search_products'.tr,
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.blueGrey.shade400,
                            size: 22,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _CategoryChips(
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onSelected: (category) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'billing.products'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              if (products.isNotEmpty)
                                Text(
                                  products.length == 1
                                      ? 'billing.item_count_one'.tr
                                      : 'billing.item_count'.trParams({
                                          'count': '${products.length}',
                                        }),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _ViewModeButton(
                          tooltip: 'billing.grid_view'.tr,
                          semanticsLabel: 'billing.grid_view'.tr,
                          icon: Icons.grid_view,
                          selected: _viewMode == ProductViewMode.grid,
                          onTap: () =>
                              setState(() => _viewMode = ProductViewMode.grid),
                        ),
                        _ViewModeButton(
                          tooltip: 'billing.list_view'.tr,
                          semanticsLabel: 'billing.list_view'.tr,
                          icon: Icons.table_rows_outlined,
                          selected: _viewMode == ProductViewMode.list,
                          onTap: () =>
                              setState(() => _viewMode = ProductViewMode.list),
                        ),
                        _ViewModeButton(
                          tooltip: 'billing.compact_view'.tr,
                          semanticsLabel: 'billing.compact_view'.tr,
                          icon: Icons.apps,
                          selected: _viewMode == ProductViewMode.dense,
                          onTap: () =>
                              setState(() => _viewMode = ProductViewMode.dense),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isLoading =
                              context.select<LocalProductProvider, bool>(
                                  (p) => p.isLoading);
                          final catalogLoading =
                              isLoading || _isResyncingProducts;

                          if (sellableProducts.isEmpty) {
                            if (catalogLoading) {
                              return _EmptyCatalogLoading(
                                resyncing: _isResyncingProducts,
                              );
                            }
                            return _EmptyCatalogResync(
                              isResyncing: _isResyncingProducts,
                              onResync: _resyncProductsFromEmptyState,
                            );
                          }

                          return MarketProductGrid(
                            products: products,
                            viewMode: _viewMode,
                            onProductAdded: _clearAndRefocusProductSearch,
                            currency:
                                context.select<AppSettingsProvider, String>(
                                    (p) => p.appSettings?.currency ?? ''),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Category filter via [BillingMobileMarketController], followed by the shared
/// catalog search used on desktop and mobile.
List<GetProduct> filterMarketHomeProducts({
  required BillingMobileMarketController controller,
  required List<GetProduct> products,
  required String query,
  required String selectedCategory,
  required bool itemCodeEnabled,
}) {
  final categoryFiltered = controller.visibleProducts(
    products: products,
    query: '',
    selectedCategory: selectedCategory,
  );

  if (query.trim().isEmpty) {
    return categoryFiltered;
  }
  return ProductSearchHelper.search(categoryFiltered, query);
}

class _EmptyCatalogLoading extends StatelessWidget {
  const _EmptyCatalogLoading({required this.resyncing});

  final bool resyncing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              resyncing
                  ? 'billing.resyncing_products'.tr
                  : 'billing.loading_products'.tr,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              resyncing
                              ? 'billing.products_loading'.tr
                              : 'billing.please_wait'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalogResync extends StatelessWidget {
  const _EmptyCatalogResync({
    required this.isResyncing,
    required this.onResync,
  });

  final bool isResyncing;
  final VoidCallback onResync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 10),
            Text(
              'billing.no_products_loaded'.tr,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'billing.try_resync_products'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            CustomRoundButton(
              title: isResyncing
                  ? 'restaurant.resyncing'.tr
                  : 'restaurant.resync_products'.tr,
              fct: isResyncing ? () {} : onResync,
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
      ),
    );
  }
}

/// Top product entry row — mirrors desktop [ProductEntryHeader] behaviour:
/// barcode field when [barcodeSales] is enabled, autocomplete otherwise.
class _ProductEntryHeader extends StatelessWidget {
  const _ProductEntryHeader({
    required this.barcodeSales,
    required this.autocompleteProductKey,
    required this.productList,
    required this.onProcessBarcode,
    required this.onClearProductFields,
    required this.focusTextField,
  });

  final bool barcodeSales;
  final GlobalKey autocompleteProductKey;
  final List<GetProduct> productList;
  final ValueChanged<String> onProcessBarcode;
  final VoidCallback onClearProductFields;
  final VoidCallback focusTextField;

  @override
  Widget build(BuildContext context) {
    return Selector<BillingProvider, String>(
      selector: (_, billingProvider) => billingProvider.selectedProductName,
      builder: (context, selectedProductName, _) {
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        final size = MediaQuery.sizeOf(context);
        final hasSelectedProductName = selectedProductName.isNotEmpty;

        if (barcodeSales) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: _MobileBarcodeField(
                  controller: billingProvider.barcodeController,
                  focusNode: billingProvider.barcodeNode,
                  autofocus: barcodeSales,
                  readOnly: hasSelectedProductName,
                  onSubmitted: (query) {
                    final trimmed = query.trim();
                    if (trimmed.isEmpty) return;
                    onProcessBarcode(trimmed);
                  },
                ),
              ),
              if (hasSelectedProductName) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: TextField(
                    readOnly: true,
                    controller: billingProvider.selectedProductNameController,
                    decoration: _entryDecoration(
                      hintText: 'billing.product_name_hint'.tr,
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        return SizedBox(
          height: 44,
          child: MobileProductAutocomplete(
            autocompleteProductKey: autocompleteProductKey,
            autofocus: !barcodeSales,
            size: size,
            productList: productList,
            suppressSystemKeyboardOnAndroid: true,
            onSelected: (_, __) {},
            onAdded: () {
              onClearProductFields();
              focusTextField();
            },
          ),
        );
      },
    );
  }
}

class _MobileBarcodeField extends StatelessWidget {
  const _MobileBarcodeField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.autofocus = false,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final bool autofocus;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Colors.black87,
      ),
      decoration: _entryDecoration(
                hintText: 'billing.barcode'.tr,
        prefixIcon: Icon(
          Icons.qr_code_scanner,
          color: Colors.blueGrey.shade400,
          size: 22,
        ),
      ),
    );
  }
}

InputDecoration _entryDecoration({
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      color: Colors.grey.shade500,
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(category),
            onSelected: (_) => onSelected(category),
            selectedColor: ColorManager.kPrimaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color:
                  selected ? ColorManager.kPrimaryColor : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            labelStyle: TextStyle(
              fontFamily: 'Poppins',
              color: selected ? Colors.white : Colors.black87,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          );
        },
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.tooltip,
    required this.semanticsLabel,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final String semanticsLabel;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: semanticsLabel,
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? ColorManager.kPrimaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
