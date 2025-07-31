import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
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
  GetStoreModelData? storeSelected;
  GetSuppliersModelData? supplier;
  final TextEditingController supplierIdController = TextEditingController();
  GetProduct? selectedProduct;

  // Variables for selected filters
  String? selectedCategoryId;
  String? selectedProperties;
  String? selectedSupplierId;
  int page = 1;
  bool initLoading = false;

  String? selectedProperty;
  final List<String> propertyList = [
    'MANUFACTURER',
    'COLOR',
    'SHIRT_SIZE',
    'SHOE_SIZE',
  ];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadInitData();
    });
    super.initState();
  }

  void loadInitData() async {
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
        filterCreatedBy: createdByController.text,
        filterProperties: selectedProperty,
        filterStore: storeController.text,
        filterSupplier: supplierIdController.text,
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
        filterCreatedBy: createdByController.text,
        filterProperties: selectedProperty,
        filterStore: storeController.text,
        filterSupplier: supplierIdController.text.isNotEmpty 
          ? supplierIdController.text 
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
    createdByController.clear();
    supplierIdController.clear();
    
    // Reset dropdown selections
    selectedCategoryId = null;
    selectedProperties = null;
    selectedSupplierId = null;
    selectedProperty = null;
    storeSelected = null;
    supplier = null;
    
    page = 1;
  });
  loadInitData();
}

  void _showProductDetails(GetProduct product) {
    setState(() {
      selectedProduct = product;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow(
                        'Product Name', product.productName ?? 'N/A'),
                    _buildDetailRow(
                        'Category', product.category?.name ?? 'N/A'),
                    _buildDetailRow('Slug', product.productSlug ?? 'N/A'),
                    _buildDetailRow('Barcode', product.barcode ?? 'N/A'),
                    _buildDetailRow('Unit', product.unit ?? 'N/A'),
                    _buildDetailRow(
                        'Price', product.price?.price?.toString() ?? 'N/A'),
                    _buildDetailRow(
                        'Product ID', product.productId?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Close",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
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

  @override
  Widget build(BuildContext context) {
    CategoryProvider categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    Size size = MediaQuery.of(context).size;
    

    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;
    List<GetSuppliersModelData>? supplierList =
        purchaseProvider.getSupplierList;

    List<Category>? categoryList = categoryProvider.category;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
              color: Colors.white),
          child: Column(
            children: [
              // Fixed Header Section
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Product List",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s20, 0.30, ColorManager.textColor),
                        ),
                        CustomRoundButton(
                          title: "Add Product",
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

                    const SizedBox(height: 25),

                    // First row of filters - Name, Category, Price, Barcode
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name filter
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Name",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                controller: productNameController,
                                size: size,
                                hintText: 'Product Name',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Category filter
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Category",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 15),
                                height: 45,
                                child: DropdownButtonFormField<Category>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  value: categoryProvider
                                              .selectedCategoryIndex >=
                                          0
                                      ? (categoryList != null &&
                                              categoryList.isNotEmpty &&
                                              categoryProvider
                                                      .selectedCategoryIndex <
                                                  categoryList.length)
                                          ? categoryList[categoryProvider
                                              .selectedCategoryIndex]
                                          : null
                                      : null,
                                  hint: Text(
                                    'Please Select',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  items: categoryList != null &&
                                          categoryList.isNotEmpty
                                      ? categoryList
                                          .map((Category category) {
                                            return DropdownMenuItem<Category>(
                                              value: category,
                                              child: Text(
                                                category.categoryName == "ALL"
                                                    ? 'Please Select'
                                                    : category.categoryName ??
                                                        '',
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          })
                                          .toSet()
                                          .toList()
                                      : [],
                                  onChanged:
                                      (Category? selectedCategory) async {
                                    if (selectedCategory != null) {
                                      setState(() {
                                        selectedCategoryId = selectedCategory
                                            .categoryId
                                            .toString();
                                      });
                                      searchProducts(1);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Price filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Price",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                controller: amountController,
                                size: size,
                                hintText: 'Price',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Barcode filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Barcode",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                margin: const EdgeInsets.only(left: 5),
                                controller: barcodeController,
                                size: size,
                                hintText: 'Barcode',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Second row of filters - Properties, Store, Supplier, Reset Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Product Properties
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Product Properties",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                margin: const EdgeInsets.only(left: 5),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                height: 45,
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedProperty,
                                    isExpanded: true,
                                    hint: Text(
                                      'Select Property',
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                    ),
                                    items: propertyList.map((String property) {
                                      return DropdownMenuItem<String>(
                                        value: property,
                                        child: Text(
                                          property,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                            color:
                                                Colors.black.withOpacity(0.5),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedProperty = newValue;
                                      });
                                      searchProducts(1);
                                    },
                                    icon: const Icon(Icons.arrow_drop_down),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Store
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Store",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 15),
                                height: 45,
                                child:
                                    DropdownButtonFormField<GetStoreModelData>(
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  isExpanded: true,
                                  value: storeSelected,
                                  hint: Text(
                                    'Select Store',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                  ),
                                  items:
                                      storeList != null && storeList.isNotEmpty
                                          ? storeList
                                              .map((GetStoreModelData store) {
                                              return DropdownMenuItem<
                                                      GetStoreModelData>(
                                                  value: store,
                                                  child: Text(
                                                    store.name ?? '',
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.27,
                                                      ColorManager.textColor
                                                          .withOpacity(.5),
                                                    ),
                                                  ));
                                            }).toList()
                                          : [],
                                  onChanged:
                                      (GetStoreModelData? storeModelData) {
                                    if (storeModelData != null) {
                                      setState(() {
                                        storeSelected = storeModelData;
                                        storeController.text =
                                            "${storeModelData.id ?? 1}";
                                      });
                                      searchProducts(1);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Supplier
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Supplier",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 15),
                                height: 45,
                                child: DropdownButtonFormField<
                                    GetSuppliersModelData>(
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  isExpanded: true,
                                  value: supplier,
                                  hint: Text(
                                    'Select Supplier',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                  ),
                                  items: supplierList != null &&
                                          supplierList.isNotEmpty
                                      ? supplierList.map(
                                          (GetSuppliersModelData supplier) {
                                          return DropdownMenuItem<
                                                  GetSuppliersModelData>(
                                              value: supplier,
                                              child: Text(
                                                supplier.user?.name ?? 'No Name',
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ));
                                        }).toList()
                                      : [],
                                  onChanged: (GetSuppliersModelData?
                                      suppliersModelData) {
                                    if (suppliersModelData != null) {
                                      setState(() {
                                        supplier = suppliersModelData;
                                        supplierIdController.text =
                                            "${suppliersModelData.id ?? 1}";
                                      });
                                      searchProducts(1);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Reset button aligned with fields
                        SizedBox(
                          height: 45,
                          child: CustomRoundButton(
                            title: "Reset",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: resetSearch,
                            height: 45,
                            width: 120,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ],
                    ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Consumer<LocalProductProvider>(
                          builder: (context, productProvider, child) {
                            List<GetProduct> productList =
                                productProvider.paginatedProducts;

                            if (initLoading) {
                              return const Center(
                                  child: CircularProgressIndicator.adaptive());
                            }

                            if (productList.isEmpty) {
                              return BuildBoxShadowContainer(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 20),
                                circleRadius: 7,
                                offsetValue: const Offset(1, 1),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 50.0),
                                  child: Center(
                                    child: Text(
                                      "No products found",
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s16,
                                        0.18,
                                        Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return BuildBoxShadowContainer(
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              width: double.infinity,
                              circleRadius: 7,
                              offsetValue: const Offset(2, 2),
                              blurRadius: 8.0,
                              color: Colors.white,
                              child: Column(
                                children: [
                                  // Fixed table header
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: ColorManager.tableBGColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          offset: Offset(0, 2),
                                          blurRadius: 2.0,
                                        ),
                                      ],
                                    ),
                                    child: Table(
                                      columnWidths: const {
                                        0: FractionColumnWidth(0.05), // No
                                        1: FractionColumnWidth(
                                            0.20), // Product Name
                                        2: FractionColumnWidth(
                                            0.15), // Category Name
                                        3: FractionColumnWidth(0.10), // Price
                                        4: FractionColumnWidth(0.10), // MRP
                                        5: FractionColumnWidth(0.10), // Unit
                                        6: FractionColumnWidth(0.15), // Barcode
                                        7: FractionColumnWidth(0.15), // Action
                                      },
                                      border: null,
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      children: [
                                        TableRow(
                                          children: [
                                            _buildTableHeader("No"),
                                            _buildTableHeader("Product Name"),
                                            _buildTableHeader("Category Name"),
                                            _buildTableHeader("Price"),
                                            _buildTableHeader("MRP"),
                                            _buildTableHeader("Unit"),
                                            _buildTableHeader("Barcode"),
                                            _buildTableHeader("Action"),
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
                                                  0.20), // Product Name
                                              2: FractionColumnWidth(
                                                  0.15), // Category Name
                                              3: FractionColumnWidth(
                                                  0.10), // Price
                                              4: FractionColumnWidth(
                                                  0.10), // MRP
                                              5: FractionColumnWidth(
                                                  0.10), // Unit
                                              6: FractionColumnWidth(
                                                  0.15), // Barcode
                                              7: FractionColumnWidth(
                                                  0.15), // Action
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
                                                            'Unknown'
                                                        : 'No Category';

                                                return TableRow(
                                                  decoration: BoxDecoration(
                                                    color: index % 2 == 0
                                                        ? Colors.white
                                                        : Colors.grey
                                                            .withOpacity(0.1),
                                                  ),
                                                  children: [
                                                    _buildTableCell(
                                                        "${index + 1}"),
                                                    _buildTableCell(
                                                        "${product.productName}"),
                                                    _buildTableCell(
                                                        categoryName),
                                                    _buildTableCell(
                                                        "${product.price?.price ?? 'N/A'}"),
                                                    _buildTableCell(
                                                        "${product.mrp ?? 'N/A'}"),
                                                    _buildTableCell(
                                                        "${product.unit ?? 'N/A'}"),
                                                    _buildTableCell(
                                                        "${product.barcode ?? 'N/A'}"),
                                                    Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child:
                                                            BuildBoxShadowContainer(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5),
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
                                                              minWidth: 36,
                                                              minHeight: 36,
                                                            ),
                                                            padding:
                                                                EdgeInsets.zero,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Pagination Always at Bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 20.0),
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

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
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
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s9,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
