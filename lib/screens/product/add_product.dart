import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/screens/product/widgets/mobile_filters.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import 'package:provider/provider.dart';
import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../models/get_product.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // Controllers
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController createdByController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController hsnCodeController = TextEditingController();
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController propertySearchController =
      TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController supplierSearchController =
      TextEditingController();
  GetStoreModelData? storeSelected;
  GetSuppliersModelData? supplier;
  final TextEditingController supplierIdController = TextEditingController();
  final TextEditingController itemCodeController = TextEditingController();
  GetProduct? selectedProduct;

  // Variables for selected filters
  String? selectedCategoryId;
  String? selectedProperties;
  String? selectedSupplierId;
  int page = 1;
  bool initLoading = false;
  bool _showFilters = false;

  String? selectedProperty;
  final List<String> propertyList = [
    'MANUFACTURER',
    'COLOR',
    'SHIRT_SIZE',
    'SHOE_SIZE',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final isMobile = MediaQuery.of(context).size.width < 600;
      setState(() {
        _showFilters = !isMobile;
      });
      loadInitData();
    });
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      // Load categories from CategoryProvider with caching (same as sidebar and stock)
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (!categoryProvider.isCategoriesLoaded) {
        debugPrint('📥 Ensuring sellable categories are loaded...');
        await categoryProvider.ensureCategoriesLoaded();
        debugPrint('✅ Categories ready');
      } else {
        debugPrint(
            "📋 Using cached categories (${categoryProvider.category?.length ?? 0} items)");
      }

      LocalProductProvider localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      localProductProvider.listAllProducts(
        categoryId:
            selectedCategoryId != null ? int.parse(selectedCategoryId!) : null,
        filterName: productNameController.text,
        filterPrice: amountController.text,
        filterBarcode: barcodeController.text,
        filterHsnCode: hsnCodeController.text,
        filterCreatedBy: createdByController.text,
        filterProperties: selectedProperty,
        filterStore: storeController.text,
        filterSupplier: supplierIdController.text,
        filterItemCode: itemCodeController.text,
        page: page,
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchProducts(page) async {
    try {
      setState(() {
        initLoading = true;
      });

      LocalProductProvider localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      localProductProvider.listAllProducts(
        categoryId:
            selectedCategoryId != null ? int.parse(selectedCategoryId!) : null,
        filterName: productNameController.text,
        filterPrice: amountController.text,
        filterBarcode: barcodeController.text,
        filterHsnCode: hsnCodeController.text,
        filterCreatedBy: createdByController.text,
        filterProperties: selectedProperty,
        filterStore: storeController.text,
        filterSupplier: supplierIdController.text.isNotEmpty
            ? supplierIdController.text
            : null,
        filterItemCode: itemCodeController.text.isNotEmpty
            ? itemCodeController.text
            : null,
        page: page,
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      productNameController.clear();
      storeController.clear();
      amountController.clear();
      barcodeController.clear();
      hsnCodeController.clear();
      createdByController.clear();
      supplierIdController.clear();
      itemCodeController.clear();

      // Reset dropdown selections
      selectedCategoryId = null;
      selectedProperties = null;
      selectedSupplierId = null;
      selectedProperty = null;
      storeSelected = null;
      supplier = null;

      page = 1;
      if (_isMobile(context)) {
        _showFilters = false;
      }
    });
    loadInitData();
  }

  void _showProductDetails(GetProduct product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProductDetailsDialog(
        product: product,
      ),
    );
  }

  void _confirmDelete(GetProduct product) {
    if (product.productId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              'product.confirm_delete_title'.tr,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s18,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'product.confirm_delete_message'.tr,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.15,
                Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'product.delete_product_label'.tr.replaceAll('@name', '${product.productName}'),
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.15,
                      Colors.black,
                    ),
                  ),
                  if (product.barcode != null && product.barcode!.isNotEmpty)
                    Text(
                      'product.barcode_label'.tr.replaceAll('@code', '${product.barcode}'),
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.1,
                        Colors.black54,
                      ),
                    ),
                  if (product.itemCode != null && product.itemCode!.isNotEmpty)
                    Text(
                      'product.item_code_label'.tr.replaceAll('@code', '${product.itemCode}'),
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.1,
                        Colors.black54,
                      ),
                    ),
                  Text(
                    'product.price_label'.tr.replaceAll('@price', '${product.price?.price ?? 'product.na'.tr}'),
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.1,
                      Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'general.cancel'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.1,
                Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();

              setState(() {
                initLoading = true;
              });

              final success = await Provider.of<LocalProductProvider>(context, listen: false)
                  .deleteProductAPI(product.productId!);

              setState(() {
                initLoading = false;
              });

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('product.deleted_success'.tr),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('product.delete_failed'.tr),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'product.delete'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.1,
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  bool _hasActiveFilters() {
    return productNameController.text.isNotEmpty ||
        amountController.text.isNotEmpty ||
        barcodeController.text.isNotEmpty ||
        hsnCodeController.text.isNotEmpty ||
        itemCodeController.text.isNotEmpty ||
        selectedCategoryId != null ||
        selectedProperty != null;
  }

  Widget _buildFilterToggleButton() {
    final hasFilters = _hasActiveFilters();

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: _showFilters ? 'product.hide_filters'.tr : 'product.show_filters'.tr,
          ),
          if (hasFilters)
            PositionedDirectional(
              end: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = _isMobile(context);
    final double horizontalMargin = isMobile ? 8 : 12;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: isMobile ? 10 : 20,
          ),
          padding: EdgeInsets.all(isMobile ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 12.0 : 5.0,
                  horizontal: isMobile ? 12.0 : 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'product.title'.tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s20,
                                        0.30,
                                        ColorManager.kTitleTextColor,
                                      ),
                                    ),
                                  ),
                                  _buildFilterToggleButton(),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CustomRoundButton(
                                title: 'product.add'.tr,
                                fct: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const AddProductWithBarcodeModal(),
                                  );
                                },
                                fontSize: 12,
                                height: 45,
                                width: double.infinity,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'product.title'.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s20,
                                    0.30,
                                    ColorManager.kTitleTextColor,
                                  ),
                                ),
                              ),
                              CustomRoundButton(
                                title: 'product.add'.tr,
                                fct: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const AddProductWithBarcodeModal(),
                                  );
                                },
                                fontSize: 12,
                                height: 45,
                                width: 150,
                              ),
                            ],
                          ),
                    const SizedBox(height: 15),
                    if (isMobile && !_showFilters) const SizedBox.shrink()
                    else if (isMobile)
                      ProductMobileFilters(
                        productNameController: productNameController,
                        amountController: amountController,
                        barcodeController: barcodeController,
                        hsnCodeController: hsnCodeController,
                        itemCodeController: itemCodeController,
                        propertySearchController: propertySearchController,
                        selectedProperty: selectedProperty,
                        propertyList: propertyList,
                        categoryField: Consumer<CategoryProvider>(
                          builder: (context, categoryProvider, child) {
                            return _buildCategoryDropdown(categoryProvider);
                          },
                        ),
                        onSearch: (value) {
                          searchProducts(1);
                        },
                        onPropertyChanged: (String? newValue) {
                          setState(() {
                            selectedProperty = newValue;
                          });
                          searchProducts(1);
                        },
                        onReset: resetSearch,
                      )
                    else
                      LayoutBuilder(
                      builder: (context, constraints) {
                        final bool stackFilters = constraints.maxWidth < 700;
                        Widget wrapField(Widget child) => stackFilters
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: child,
                              )
                            : Expanded(flex: 1, child: child);

                        return Column(
                          children: [
                            stackFilters
                                ? Column(
                                    children: [
                                      wrapField(buildColumnWidgetForTextFields(
                                        height: 45,
                                        onchanged: (value) {
                                          searchProducts(1);
                                        },
                                        controller: productNameController,
                                        size: size,
                                        hintText: 'product.product_name'.tr,
                                      )),
                                      wrapField(Consumer<CategoryProvider>(
                                        builder:
                                            (context, categoryProvider, child) {
                                          return _buildCategoryDropdown(
                                              categoryProvider);
                                        },
                                      )),
                                      wrapField(buildColumnWidgetForTextFields(
                                        height: 45,
                                        onchanged: (value) {
                                          searchProducts(1);
                                        },
                                        controller: amountController,
                                        size: size,
                                        hintText: 'product.price'.tr,
                                      )),
                                      wrapField(buildColumnWidgetForTextFields(
                                        height: 45,
                                        onchanged: (value) {
                                          searchProducts(1);
                                        },
                                        controller: barcodeController,
                                        size: size,
                                        hintText: 'product.barcode'.tr,
                                      )),
                                      wrapField(buildColumnWidgetForTextFields(
                                        height: 45,
                                        onchanged: (value) {
                                          searchProducts(1);
                                        },
                                        controller: hsnCodeController,
                                        size: size,
                                        hintText: 'product.hsn_code'.tr,
                                      )),
                                      wrapField(BuildDropDownWithSearch<String>(
                                        title: null,
                                        showName: false,
                                        hintText: 'product.select_property'.tr,
                                        value: selectedProperty,
                                        items: propertyList,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedProperty = newValue;
                                          });
                                          searchProducts(1);
                                        },
                                        displayText: (property) => property,
                                        searchController:
                                            propertySearchController,
                                        height: 45,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 0),
                                      )),
                                      Consumer<AppSettingsProvider>(
                                        builder: (context,
                                            appSettingsProvider, child) {
                                          final itemCodeEnabled =
                                              appSettingsProvider.appSettings
                                                      ?.itemCodeEnabled ??
                                                  false;
                                          if (!itemCodeEnabled) {
                                            return const SizedBox.shrink();
                                          }
                                          return wrapField(
                                              buildColumnWidgetForTextFields(
                                            height: 45,
                                            onchanged: (value) {
                                              searchProducts(1);
                                            },
                                            controller: itemCodeController,
                                            size: size,
                                            hintText: 'product.item_code'.tr,
                                          ));
                                        },
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          wrapField(
                                              buildColumnWidgetForTextFields(
                                            height: 45,
                                            onchanged: (value) {
                                              searchProducts(1);
                                            },
                                            controller: productNameController,
                                            size: size,
                                            hintText: 'product.product_name'.tr,
                                          )),
                                          const SizedBox(width: 15),
                                          wrapField(Consumer<CategoryProvider>(
                                            builder: (context,
                                                categoryProvider, child) {
                                              return _buildCategoryDropdown(
                                                  categoryProvider);
                                            },
                                          )),
                                          const SizedBox(width: 15),
                                          wrapField(
                                              buildColumnWidgetForTextFields(
                                            height: 45,
                                            onchanged: (value) {
                                              searchProducts(1);
                                            },
                                            controller: amountController,
                                            size: size,
                                            hintText: 'product.price'.tr,
                                          )),
                                          const SizedBox(width: 15),
                                          wrapField(
                                              buildColumnWidgetForTextFields(
                                            height: 45,
                                            onchanged: (value) {
                                              searchProducts(1);
                                            },
                                            margin: const EdgeInsetsDirectional
                                                .only(start: 5),
                                            controller: barcodeController,
                                            size: size,
                                            hintText: 'product.barcode'.tr,
                                          )),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          wrapField(
                                              buildColumnWidgetForTextFields(
                                            height: 45,
                                            onchanged: (value) {
                                              searchProducts(1);
                                            },
                                            controller: hsnCodeController,
                                            size: size,
                                            hintText: 'product.hsn_code'.tr,
                                          )),
                                          const SizedBox(width: 15),
                                          wrapField(
                                              BuildDropDownWithSearch<String>(
                                            title: null,
                                            showName: false,
                                            hintText: 'product.select_property'.tr,
                                            value: selectedProperty,
                                            items: propertyList,
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                selectedProperty = newValue;
                                              });
                                              searchProducts(1);
                                            },
                                            displayText: (property) =>
                                                property,
                                            searchController:
                                                propertySearchController,
                                            height: 45,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 0, vertical: 0),
                                          )),
                                          const SizedBox(width: 15),
                                          Consumer<AppSettingsProvider>(
                                            builder: (context,
                                                appSettingsProvider, child) {
                                              final itemCodeEnabled =
                                                  appSettingsProvider
                                                          .appSettings
                                                          ?.itemCodeEnabled ??
                                                      false;
                                              if (!itemCodeEnabled) {
                                                return const Expanded(
                                                    flex: 1,
                                                    child: SizedBox());
                                              }
                                              return wrapField(
                                                  buildColumnWidgetForTextFields(
                                                height: 45,
                                                onchanged: (value) {
                                                  searchProducts(1);
                                                },
                                                controller:
                                                    itemCodeController,
                                                size: size,
                                                hintText: 'product.item_code'.tr,
                                              ));
                                            },
                                          ),
                                          const SizedBox(width: 15),
                                          const Expanded(
                                              flex: 1, child: SizedBox()),
                                        ],
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: stackFilters
                                  ? Alignment.center
                                  : Alignment.centerRight,
                              child: CustomRoundButton(
                                title: 'general.reset'.tr,
                                boxColor: Colors.white,
                                textColor: ColorManager.kPrimaryColor,
                                fct: resetSearch,
                                height: 45,
                                width: stackFilters ? double.infinity : 120,
                                fontSize: FontSize.s12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (isMobile && _showFilters) const SizedBox(height: 20),
                  ],
                ),
              ),
              // Expanded area for table and pagination
              Expanded(
                child: Column(
                  children: [
                    // Table Area - Takes remaining space with scrolling table body
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : 20.0),
                        child: Consumer<LocalProductProvider>(
                          builder: (context, productProvider, child) {
                            List<GetProduct> productList =
                                productProvider.paginatedProducts;
                            final itemCodeEnabled = Provider.of<
                                        AppSettingsProvider>(context,
                                    listen: false)
                                .appSettings
                                ?.itemCodeEnabled ?? false;

                            if (initLoading) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: ColorManager.kPrimaryColor,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'product.loading'.tr,
                                      style: const TextStyle(
                                        color: ColorManager.kGreyColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (productList.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 88,
                                      width: 88,
                                      decoration: BoxDecoration(
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 40,
                                        color: ColorManager.kPrimaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'product.no_products'.tr,
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s16,
                                        0.18,
                                        ColorManager.kTitleTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (isMobile) {
                              return ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: productList.length,
                                itemBuilder: (context, index) {
                                  final product = productList[index];
                                  final categoryName = product.category != null
                                      ? product.category!.name ?? 'product.unknown'.tr
                                      : 'product.no_category'.tr;
                                  final serialNumber =
                                      productProvider.paginationFrom + index;
                                  return _buildMobileProductCard(
                                    product: product,
                                    serialNumber: serialNumber,
                                    categoryName: categoryName,
                                    itemCodeEnabled: itemCodeEnabled,
                                  );
                                },
                              );
                            }

                            return BuildBoxShadowContainer(
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              width: double.infinity,
                              circleRadius: 14,
                              offsetValue: const Offset(0, 3),
                              blurRadius: 10.0,
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Column(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: ColorManager.tableBGColor,
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Color(0x1F000000),
                                            width: 1),
                                      ),
                                    ),
                                    child: Table(
                                      columnWidths: const {
                                        0: FractionColumnWidth(0.05), // No
                                        1: FractionColumnWidth(
                                            0.24), // Product Name
                                        2: FractionColumnWidth(
                                            0.08), // Item Code
                                        3: FractionColumnWidth(
                                            0.11), // Category Name
                                        4: FractionColumnWidth(0.07), // Price
                                        5: FractionColumnWidth(0.07), // MRP
                                        6: FractionColumnWidth(
                                            0.07), // Purchase Price
                                        7: FractionColumnWidth(0.07), // Unit
                                        8: FractionColumnWidth(0.12), // Barcode
                                        9: FractionColumnWidth(0.12), // Action
                                      },
                                      border: null,
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      children: [
                                        TableRow(
                                          children: [
                                            _buildTableHeader('product.col_no'.tr),
                                            _buildTableHeader('product.product_name'.tr),
                                            _buildTableHeader(
                                                itemCodeEnabled
                                                    ? 'product.item_code'.tr
                                                    : ""),
                                            _buildTableHeader('product.category_name'.tr),
                                            _buildTableHeader('product.price'.tr),
                                            _buildTableHeader('product.mrp'.tr),
                                            _buildTableHeader('product.purchase_price'.tr),
                                            _buildTableHeader('product.unit'.tr),
                                            _buildTableHeader('product.barcode'.tr),
                                            _buildTableHeader('product.action'.tr),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Scrollable table body
                                  Expanded(
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: ScrollConfiguration(
                                        behavior:
                                            ScrollConfiguration.of(context)
                                                .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.mouse,
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.stylus,
                                            PointerDeviceKind.trackpad,
                                          },
                                        ),
                                        child: SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
                                          scrollDirection: Axis.vertical,
                                          child: Table(
                                            columnWidths: const {
                                              0: FractionColumnWidth(
                                                  0.05), // No
                                              1: FractionColumnWidth(
                                                  0.24), // Product Name
                                              2: FractionColumnWidth(
                                                  0.08), // Item Code
                                              3: FractionColumnWidth(
                                                  0.11), // Category Name
                                              4: FractionColumnWidth(
                                                  0.07), // Price
                                              5: FractionColumnWidth(
                                                  0.07), // MRP
                                              6: FractionColumnWidth(
                                                  0.07), // Purchase Price
                                              7: FractionColumnWidth(
                                                  0.07), // Unit
                                              8: FractionColumnWidth(
                                                  0.12), // Barcode
                                              9: FractionColumnWidth(
                                                  0.12), // Action
                                            },
                                            border: null,
                                            defaultVerticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            children: [
                                              ...productList
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                int index = entry.key;
                                                var product = entry.value;
                                                String categoryName =
                                                    product.category != null
                                                        ? product.category!
                                                                .name ??
                                                            'product.unknown'.tr
                                                        : 'product.no_category'.tr;

                                                // Calculate serial number based on pagination
                                                int serialNumber =
                                                    productProvider
                                                            .paginationFrom +
                                                        index;

                                                return TableRow(
                                                  decoration: BoxDecoration(
                                                    color: index % 2 == 0
                                                        ? Colors.white
                                                        : Colors.grey
                                                            .withOpacity(0.1),
                                                  ),
                                                  children: [
                                                    _buildTableCell(
                                                        "$serialNumber"),
                                                    TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment.middle,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Center(
                                                          child: SelectableText(
                                                            "${product.productName}",
                                                            textAlign: TextAlign.center,
                                                            style: buildCustomStyle(
                                                              FontWeightManager.medium,
                                                              FontSize.s11,
                                                              0.13,
                                                              ColorManager.kTextColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment.middle,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Center(
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  itemCodeEnabled ? (product.itemCode ?? '') : '',
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  textAlign: TextAlign.center,
                                                                  style: buildCustomStyle(
                                                                    FontWeightManager.medium,
                                                                    FontSize.s11,
                                                                    0.13,
                                                                    ColorManager.kTextColor,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (itemCodeEnabled && product.itemCode != null && product.itemCode!.isNotEmpty) ...[
                                                                const SizedBox(width: 6),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    Clipboard.setData(ClipboardData(
                                                                        text: product.itemCode!));
                                                                    showScaffold(
                                                                      context: context,
                                                                      message: 'product.item_code_copied'.tr,
                                                                    );
                                                                  },
                                                                  child: const Icon(
                                                                    Icons.copy,
                                                                    size: 14,
                                                                    color: Colors.black38,
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment.middle,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Center(
                                                          child: SelectableText(
                                                            categoryName,
                                                            textAlign: TextAlign.center,
                                                            style: buildCustomStyle(
                                                              FontWeightManager.medium,
                                                              FontSize.s11,
                                                              0.13,
                                                              ColorManager.kTextColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildTableCell(
                                                        "${product.price?.price ?? 'product.na'.tr}"),
                                                    _buildTableCell(
                                                        "${product.mrp ?? 'product.na'.tr}"),
                                                    _buildTableCell(() {
                                                      // Debug purchase price resolution
                                                      final productPurchasePrice =
                                                          product.purchasePrice;
                                                      final stockPurchasePrice =
                                                          product.stock !=
                                                                      null &&
                                                                  product.stock!
                                                                      .isNotEmpty
                                                              ? product
                                                                  .stock!
                                                                  .first
                                                                  .purchasePrice
                                                              : null;
                                                      final finalPrice =
                                                          productPurchasePrice ??
                                                              stockPurchasePrice ??
                                                              'product.na'.tr;

                                                      debugPrint(
                                                          "🔍 PURCHASE PRICE DEBUG for ${product.productName}:");
                                                      debugPrint(
                                                          "  - Product Purchase Price: $productPurchasePrice");
                                                      debugPrint(
                                                          "  - Stock Purchase Price: $stockPurchasePrice");
                                                      debugPrint(
                                                          "  - Final Display Price: $finalPrice");
                                                      debugPrint(
                                                          "  - Stock Count: ${product.stock?.length ?? 0}");

                                                      return finalPrice
                                                          .toString();
                                                    }()),
                                                    _buildTableCell(
                                                        product.unit ?? 'product.na'.tr),
                                                    TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment.middle,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Center(
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  product.barcode ?? 'product.na'.tr,
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  textAlign: TextAlign.center,
                                                                  style: buildCustomStyle(
                                                                    FontWeightManager.medium,
                                                                    FontSize.s11,
                                                                    0.13,
                                                                    ColorManager.kTextColor,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (product.barcode != null && product.barcode!.isNotEmpty && product.barcode != 'N/A') ...[
                                                                const SizedBox(width: 6),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    Clipboard.setData(ClipboardData(
                                                                        text: product.barcode!));
                                                                    showScaffold(
                                                                      context: context,
                                                                      message: 'product.barcode_copied'.tr,
                                                                    );
                                                                  },
                                                                  child: const Icon(
                                                                    Icons.copy,
                                                                    size: 14,
                                                                    color: Colors.black38,
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            BuildBoxShadowContainer(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 2,
                                                                      right: 2),
                                                              circleRadius: 5,
                                                              child: IconButton(
                                                                icon: Icon(
                                                                  Icons.visibility,
                                                                  size: 18,
                                                                  color: ColorManager
                                                                      .kPrimaryColor
                                                                      .withOpacity(
                                                                          0.9),
                                                                ),
                                                                onPressed: () {
                                                                  _showProductDetails(
                                                                      product);
                                                                },
                                                                constraints:
                                                                    const BoxConstraints(
                                                                  minWidth: 32,
                                                                  minHeight: 32,
                                                                ),
                                                                padding:
                                                                    EdgeInsets.zero,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 5),
                                                            BuildBoxShadowContainer(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 2,
                                                                      right: 2),
                                                              circleRadius: 5,
                                                              child: IconButton(
                                                                icon: Icon(
                                                                  Icons.delete_outline,
                                                                  size: 18,
                                                                  color: Colors.red.shade400,
                                                                ),
                                                                onPressed: () {
                                                                  _confirmDelete(product);
                                                                },
                                                                constraints:
                                                                    const BoxConstraints(
                                                                  minWidth: 32,
                                                                  minHeight: 32,
                                                                ),
                                                                padding:
                                                                    EdgeInsets.zero,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Pagination Always at Bottom
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12.0 : 20.0, vertical: 10),
                      child: Consumer<LocalProductProvider>(
                        builder: (context, productProvider, child) {
                          if (productProvider.paginatedProducts.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return PaginationControl(
                            currentPage: productProvider.currentPage,
                            totalPages: productProvider.totalPages,
                            onPageChanged: (int page) {
                              searchProducts(page);
                            },
                          );
                        },
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
  }

  Widget _buildCategoryDropdown(CategoryProvider categoryProvider) {
    List<Category>? categoryList = categoryProvider.category;
    Category? selectedCategory;
    if (selectedCategoryId != null && categoryList != null) {
      try {
        selectedCategory = categoryList.firstWhere(
          (cat) => cat.categoryId.toString() == selectedCategoryId,
          orElse: () => categoryList.first,
        );
      } catch (e) {
        selectedCategory = null;
      }
    }

    return BuildDropDownWithSearch<Category>(
      title: null,
      showName: false,
      hintText: 'product.please_select'.tr,
      value: selectedCategory,
      items: categoryList != null && categoryList.isNotEmpty
          ? categoryList
              .where((category) => category.categoryName != "ALL")
              .toList()
          : [],
      onChanged: (Category? selected) async {
        if (selected != null) {
          setState(() {
            selectedCategoryId = selected.categoryId.toString();
          });
          searchProducts(1);
        }
      },
      displayText: (category) => category.categoryName ?? 'product.unknown'.tr,
      searchController: categorySearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildMobileProductCard({
    required GetProduct product,
    required int serialNumber,
    required String categoryName,
    required bool itemCodeEnabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BuildBoxShadowContainer(
        circleRadius: 14,
        padding: const EdgeInsets.all(16),
        showShadow: true,
        blurRadius: 10,
        offsetValue: const Offset(0, 3),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    product.productName ?? 'product.unnamed'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.18,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
                Text(
                  '#$serialNumber',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.13,
                    ColorManager.kGreyColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              categoryName,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.13,
                Colors.black54,
              ),
            ),
            if (itemCodeEnabled &&
                product.itemCode != null &&
                product.itemCode!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'product.item_label'.tr.replaceAll('@code', '${product.itemCode}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.13,
                          Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: product.itemCode!));
                        showScaffold(
                          context: context,
                          message: 'product.item_code_copied'.tr,
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            if (product.barcode != null && product.barcode!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'product.barcode_label'.tr.replaceAll('@code', '${product.barcode}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.13,
                          Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: product.barcode!));
                        showScaffold(
                          context: context,
                          message: 'product.barcode_copied'.tr,
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'product.price_label'.tr.replaceAll('@price', '${product.price?.price ?? 'product.na'.tr}'),
                      maxLines: 1,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: Icon(Icons.visibility,
                            size: 20, color: ColorManager.kPrimaryColor),
                        onPressed: () => _showProductDetails(product),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: Colors.red.shade400),
                        onPressed: () => _confirmDelete(product),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.18,
              ColorManager.kTitleTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.13,
              ColorManager.kTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
