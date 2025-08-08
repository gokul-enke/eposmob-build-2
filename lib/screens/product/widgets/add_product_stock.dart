import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

void showScaffold({required BuildContext context, required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class StockItem {
  String barcode;
  String category;
  String product;
  String quantity;
  String salePrice;
  String mrp;
  String wholesale;
  String purchaseRate;
  String unit;
  String rack;
  DateTime expDate;

  // Additional details for modal
  String batchNumber;
  String supplier;
  int supplierId;
  GetProduct? productData;
  Category? categoryData;
  GetSuppliersModelData? supplierData;

  StockItem({
    this.barcode = '',
    this.category = '',
    this.product = '',
    this.quantity = '1',
    this.salePrice = '0',
    this.mrp = '0',
    this.wholesale = '0',
    this.purchaseRate = '0',
    this.unit = '',
    this.rack = '',
    DateTime? expDate,
    this.batchNumber = '',
    this.supplier = '',
    this.supplierId = 1,
    this.productData,
    this.categoryData,
    this.supplierData,
  }) : expDate = expDate ?? DateTime.now().add(const Duration(days: 365));
}

class AddProductStockScreen extends StatefulWidget {
  const AddProductStockScreen({super.key});

  @override
  State<AddProductStockScreen> createState() => _AddProductStockScreenState();
}

class _AddProductStockScreenState extends State<AddProductStockScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SideBarController sideBarController = Get.put(SideBarController());

  // Header form controllers
  final TextEditingController supplierSearchController =
      TextEditingController();

  // Search controllers for each row
  final Map<int, TextEditingController> categorySearchControllers = {};
  final Map<int, TextEditingController> productSearchControllers = {};

  // Selected header values
  GetStoreModelData? selectedStore;
  DateTime selectedDate = DateTime.now();
  DateTime selectedPurchaseDate = DateTime.now();
  GetSuppliersModelData? selectedSupplier;

  // Stock items list
  List<StockItem> stockItems = [StockItem()]; // Start with one empty row

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    // Dispose all search controllers
    categorySearchControllers.values
        .forEach((controller) => controller.dispose());
    productSearchControllers.values
        .forEach((controller) => controller.dispose());
    supplierSearchController.dispose();
    super.dispose();
  }

  // Get or create search controller for a specific row
  TextEditingController _getCategorySearchController(int index) {
    if (!categorySearchControllers.containsKey(index)) {
      categorySearchControllers[index] = TextEditingController();
    }
    return categorySearchControllers[index]!;
  }

  TextEditingController _getProductSearchController(int index) {
    if (!productSearchControllers.containsKey(index)) {
      productSearchControllers[index] = TextEditingController();
    }
    return productSearchControllers[index]!;
  }

  Future<void> _initializeData() async {
    // Initialize any required data
    await _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken != null) {
        await Provider.of<PurchaseProvider>(context, listen: false)
            .listAllSuppliers(accessToken, null);
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  void _addNewStockRow() {
    setState(() {
      stockItems.add(StockItem());
    });
  }

  void _removeStockRow(int index) {
    if (stockItems.length > 1) {
      // Dispose controllers for the removed row
      categorySearchControllers[index]?.dispose();
      productSearchControllers[index]?.dispose();
      categorySearchControllers.remove(index);
      productSearchControllers.remove(index);

      setState(() {
        stockItems.removeAt(index);
      });
    }
  }

  void _showStockDetailModal(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StockDetailModal(
          stockItem: stockItems[index],
          onSave: (updatedItem) {
            setState(() {
              stockItems[index] = updatedItem;
            });
          },
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      showScaffold(
          context: context, message: 'Please fill all required fields');
      return;
    }

    if (selectedStore == null) {
      showScaffold(context: context, message: 'Please select a store');
      return;
    }

    // Validate stock items
    for (int i = 0; i < stockItems.length; i++) {
      final item = stockItems[i];
      if (item.product.isEmpty || item.category.isEmpty) {
        showScaffold(
            context: context, message: 'Please complete stock item ${i + 1}');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) {
        throw Exception('Access token not found');
      }

      // Submit each stock item
      for (final item in stockItems) {
        if (item.productData != null && item.categoryData != null) {
          await Provider.of<StockProvider>(context, listen: false)
              .addProductStockAPI(
            accessToken: accessToken,
            productId: item.productData!.productId.toString(),
            categoryId: item.categoryData!.categoryId.toString(),
            quantity: item.quantity,
            retailPrice: item.salePrice,
            purchaseRate: item.purchaseRate,
            mrp: item.mrp,
            wholesalePrice: item.wholesale,
            unit: item.unit,
            supplierId:
                selectedSupplier?.id?.toString() ?? item.supplierId.toString(),
            storeId: selectedStore!.id.toString(),
            expiryDate: DateFormat('yyyy-MM-dd').format(item.expDate),
            userId: '1',
            purchaseVoucherId: null,
            purchaseId: null,
            taxAmountRetail: null,
            taxAmountWholesale: null,
            wholesaleMinUnit: '1',
            rack: item.rack,
            barcode: item.barcode,
            batchNumber: item.batchNumber,
            date: DateFormat('yyyy-MM-dd').format(selectedDate),
            purchaseDate: DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
            purchaseNumber: null,
            taxInclude: false,
            initialRetailPrice: item.salePrice,
            initialWholesalePrice: item.wholesale,
            retailPriceTax: null,
            wholesalePriceTax: null,
            context: context,
          );
        }
      }

      showScaffold(
          context: context, message: 'All stock items added successfully');
      _clearForm();
      sideBarController.index.value = 15;
    } catch (e) {
      showScaffold(context: context, message: 'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    supplierSearchController.clear();
    // Clear all search controllers
    categorySearchControllers.values
        .forEach((controller) => controller.clear());
    productSearchControllers.values.forEach((controller) => controller.clear());
    setState(() {
      selectedStore = null;
      selectedSupplier = null;
      selectedDate = DateTime.now();
      selectedPurchaseDate = DateTime.now();
      stockItems = [StockItem()];
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: Container(
        height: size.height,
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBackButton(
                onPressed: () {
                  sideBarController.index.value = 15;
                },
                text: 'All Stocks',
              ),
              Text(
                'Add Product Stock',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(size),
                      const SizedBox(height: 20),
                      _buildStockTableHeader(),
                      const SizedBox(height: 10),
                      Expanded(child: _buildStockTable()),
                      const SizedBox(height: 20),
                      _buildActionButtons(size),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Size size) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _buildDateField("Date", selectedDate,
                (date) => setState(() => selectedDate = date))),
        const SizedBox(width: 20),
        Expanded(child: _buildStoreDropdown(size)),
        const SizedBox(width: 20),
        Expanded(child: _buildSupplierField()),
      ],
    );
  }

  Widget _buildDateField(
      String title, DateTime selectedDate, Function(DateTime) onDateSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        BuildTextTile(
          isStarRed: true,
          isTextField: true,
          title: title,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          height: MediaQuery.of(context).size.height * .07,
          child: CalendarPickerTableCell(
            initialDate: selectedDate,
            onDateSelected: onDateSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreDropdown(Size size) {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              title: "Store",
              isStarRed: true,
              isTextField: true,
              textStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: size.height * .07,
              child: DropdownButton2<GetStoreModelData>(
                isExpanded: true,
                value: selectedStore,
                hint: Text('Select Store',
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5))),
                items: storeList?.map((store) {
                  return DropdownMenuItem<GetStoreModelData>(
                    value: store,
                    child: Text(store.name ?? '',
                        style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.27,
                            ColorManager.textColor.withOpacity(.5)),
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (GetStoreModelData? value) {
                  setState(() {
                    selectedStore = value;
                  });
                },
                underline: Container(),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.grey.withOpacity(0.3))),
                ),
                buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.zero, decoration: BoxDecoration()),
                iconStyleData: const IconStyleData(
                    icon: Icon(Icons.arrow_drop_down), iconSize: 20),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupplierField() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        List<GetSuppliersModelData>? supplierList =
            purchaseProvider.supplierList;

        return BuildDropDownWithSearch<GetSuppliersModelData>(
          title: "Supplier",
          hintText: "Select Supplier",
          value: selectedSupplier,
          items: supplierList ?? [],
          onChanged: (value) {
            setState(() {
              selectedSupplier = value;
            });
          },
          displayText: (supplier) => supplier.user?.name ?? 'Unknown Supplier',
          searchController: supplierSearchController,
          isRequired: false,
          searchHintText: "Search for supplier...",
        );
      },
    );
  }

  Widget _buildStockTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _buildHeaderCell("Barcode", flex: 2),
          _buildHeaderCell("Category", flex: 2),
          _buildHeaderCell("Product", flex: 3),
          _buildHeaderCell("Qty", flex: 1),
          SizedBox(
            width: stockItems.length > 1 ? 100 : 50,
            child: _buildHeaderCell("Actions", flex: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    if (flex == 0) {
      return Text(
        title,
        style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.27,
            ColorManager.kPrimaryColor),
        textAlign: TextAlign.center,
      );
    }
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.27,
            ColorManager.kPrimaryColor),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStockTable() {
    return ListView.builder(
      itemCount: stockItems.length,
      itemBuilder: (context, index) {
        return _buildStockRow(index);
      },
    );
  }

  Widget _buildStockRow(int index) {
    final item = stockItems[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barcode Text Field
          Expanded(
            flex: 2,
            child: BuildBoxShadowContainer(
              circleRadius: 5,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextFormField(
                initialValue: item.barcode,
                decoration: const InputDecoration(
                  hintText: 'Barcode',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.27,
                  ColorManager.textColor,
                ),
                onChanged: (value) {
                  setState(() {
                    stockItems[index].barcode = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Category Dropdown with Search
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: _buildCategoryDropdown(index),
            ),
          ),
          const SizedBox(width: 8),
          // Product Dropdown with Search
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: _buildProductDropdown(index),
            ),
          ),
          const SizedBox(width: 8),
          // Quantity Text Field
          Expanded(
            flex: 1,
            child: BuildBoxShadowContainer(
              circleRadius: 5,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextFormField(
                initialValue: item.quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Qty',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.27,
                  ColorManager.textColor,
                ),
                onChanged: (value) {
                  setState(() {
                    stockItems[index].quantity = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Actions - Fixed width instead of flex
          SizedBox(
            width: stockItems.length > 1 ? 100 : 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorManager.boxShadowColor,
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: ColorManager.kPrimaryColor),
                    onPressed: () => _showStockDetailModal(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
                if (stockItems.length > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: ColorManager.boxShadowColor,
                          blurRadius: 3,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _removeStockRow(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(int index) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        List<Category>? categoryList = categoryProvider.category;

        return BuildDropDownWithSearch<Category>(
          title: null,
          hintText: "Select category",
          value: stockItems[index].categoryData,
          items: categoryList
                  ?.where((category) => category.categoryName != "ALL")
                  .toList() ??
              [],
          onChanged: (category) {
            setState(() {
              stockItems[index].categoryData = category;
              stockItems[index].category = category?.categoryName ?? '';
              // Clear product when category changes
              stockItems[index].productData = null;
              stockItems[index].product = '';
            });
            if (category != null) {
              Provider.of<GridSelectionProvider>(context, listen: false)
                  .listAllProducts(
                      filterCategory: category.categoryId.toString());
            }
          },
          displayText: (category) => category.categoryName ?? '',
          searchController: _getCategorySearchController(index),
          isRequired: false,
          height: 40,
          searchHintText: "Search category...",
        );
      },
    );
  }

  Widget _buildProductDropdown(int index) {
    return Consumer<GridSelectionProvider>(
      builder: (context, gridProvider, child) {
        List<GetProduct>? productList = gridProvider.getCategoryProductList;
        List<GetProduct> uniqueProducts = [];
        Set<int> seenIds = {};

        if (productList != null) {
          for (var product in productList) {
            if (product.productId != null &&
                !seenIds.contains(product.productId)) {
              seenIds.add(product.productId!);
              uniqueProducts.add(product);
            }
          }
        }

        return BuildDropDownWithSearch<GetProduct>(
          title: null,
          hintText: "Select product",
          value: stockItems[index].productData,
          items: uniqueProducts,
          onChanged: (product) {
            if (product != null) {
              setState(() {
                stockItems[index].productData = product;
                stockItems[index].product = product.productName ?? '';
                stockItems[index].barcode = product.barcode ?? '';
                stockItems[index].salePrice =
                    product.price?.price?.toString() ?? '0';
                stockItems[index].mrp = product.mrp?.toString() ??
                    product.price?.price?.toString() ??
                    '0';
                stockItems[index].purchaseRate =
                    product.stock?.firstOrNull?.purchasePrice ?? '0';
                stockItems[index].unit = product.unit ?? '';
              });
            }
          },
          displayText: (product) => product.productName ?? '',
          searchController: _getProductSearchController(index),
          isRequired: false,
          height: 40,
          searchHintText: "Search product...",
        );
      },
    );
  }

  Widget _buildActionButtons(Size size) {
    return Row(
      children: [
        CustomRoundButton(
          title: "Add Row",
          fct: _addNewStockRow,
          height: 50,
          width: size.width * 0.12,
          fontSize: FontSize.s14,
          boxColor: Colors.white,
          borderColor: ColorManager.kPrimaryColor,
          textColor: ColorManager.kPrimaryColor,
        ),
        const SizedBox(width: 15),
        CustomRoundButton(
          title: _isLoading ? "Saving..." : "Finish",
          fct: _isLoading ? () {} : _submitForm,
          height: 50,
          width: size.width * 0.15,
          fontSize: FontSize.s14,
          boxColor: _isLoading ? Colors.grey : ColorManager.kPrimaryColor,
        ),
        const SizedBox(width: 15),
        CustomRoundButton(
          title: "Cancel",
          fct: () {
            sideBarController.index.value = 15;
          },
          height: 50,
          width: size.width * 0.15,
          fontSize: FontSize.s14,
          boxColor: Colors.white,
          borderColor: ColorManager.kPrimaryColor,
          textColor: ColorManager.kPrimaryColor,
        ),
      ],
    );
  }
}

class StockDetailModal extends StatefulWidget {
  final StockItem stockItem;
  final Function(StockItem) onSave;

  const StockDetailModal({
    super.key,
    required this.stockItem,
    required this.onSave,
  });

  @override
  State<StockDetailModal> createState() => _StockDetailModalState();
}

class _StockDetailModalState extends State<StockDetailModal> {
  late TextEditingController barcodeController;
  late TextEditingController quantityController;
  late TextEditingController salePriceController;
  late TextEditingController mrpController;
  late TextEditingController wholesaleController;
  late TextEditingController purchaseRateController;
  late TextEditingController rackController;
  late TextEditingController batchNumberController;
  late TextEditingController supplierSearchController;

  GetProduct? selectedProduct;
  Category? selectedCategory;
  String? selectedUnit;
  DateTime selectedExpDate = DateTime.now().add(const Duration(days: 365));
  GetSuppliersModelData? selectedSupplier;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current values
    barcodeController = TextEditingController(text: widget.stockItem.barcode);
    quantityController = TextEditingController(text: widget.stockItem.quantity);
    salePriceController =
        TextEditingController(text: widget.stockItem.salePrice);
    mrpController = TextEditingController(text: widget.stockItem.mrp);
    wholesaleController =
        TextEditingController(text: widget.stockItem.wholesale);
    purchaseRateController =
        TextEditingController(text: widget.stockItem.purchaseRate);
    rackController = TextEditingController(text: widget.stockItem.rack);
    batchNumberController =
        TextEditingController(text: widget.stockItem.batchNumber);
    supplierSearchController =
        TextEditingController(text: widget.stockItem.supplier);

    selectedProduct = widget.stockItem.productData;
    selectedCategory = widget.stockItem.categoryData;
    selectedUnit = widget.stockItem.unit.isEmpty ? null : widget.stockItem.unit;
    selectedExpDate = widget.stockItem.expDate;
    selectedSupplier = widget.stockItem.supplierData;
  }

  @override
  void dispose() {
    barcodeController.dispose();
    quantityController.dispose();
    salePriceController.dispose();
    mrpController.dispose();
    wholesaleController.dispose();
    purchaseRateController.dispose();
    rackController.dispose();
    batchNumberController.dispose();
    supplierSearchController.dispose();
    super.dispose();
  }

  void _saveStockItem() {
    if (selectedCategory == null || selectedProduct == null) {
      showScaffold(
          context: context, message: 'Please select category and product');
      return;
    }

    final updatedItem = StockItem(
      barcode: barcodeController.text,
      category: selectedCategory!.categoryName ?? '',
      product: selectedProduct!.productName ?? '',
      quantity: quantityController.text.isEmpty ? '1' : quantityController.text,
      salePrice:
          salePriceController.text.isEmpty ? '0' : salePriceController.text,
      mrp: mrpController.text.isEmpty ? '0' : mrpController.text,
      wholesale:
          wholesaleController.text.isEmpty ? '0' : wholesaleController.text,
      purchaseRate: purchaseRateController.text.isEmpty
          ? '0'
          : purchaseRateController.text,
      unit: selectedUnit ?? '',
      rack: rackController.text,
      expDate: selectedExpDate,
      batchNumber: batchNumberController.text,
      supplier: selectedSupplier?.user?.name ?? widget.stockItem.supplier,
      supplierId: selectedSupplier?.id ?? widget.stockItem.supplierId,
      productData: selectedProduct,
      categoryData: selectedCategory,
      supplierData: selectedSupplier,
    );

    widget.onSave(updatedItem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: BuildBoxShadowContainer(
        circleRadius: 7,
        color: Colors.white,
        width: size.width * 0.8,
        height: size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock Item Details',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s18, 0.30, ColorManager.textColor),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModalSection("Product Selection", [
                      Row(
                        children: [
                          Expanded(child: _buildCategoryDropdown(size)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildProductDropdown(size)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildModalSection("Basic Information", [
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField("Barcode",
                                  barcodeController, TextInputType.text)),
                          const SizedBox(width: 15),
                          Expanded(
                              child: _buildTextField("Quantity",
                                  quantityController, TextInputType.number,
                                  isRequired: true)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildUnitDropdown(size)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(
                                  "Rack", rackController, TextInputType.text)),
                          const SizedBox(width: 15),
                          Expanded(
                              child: _buildTextField("Batch Number",
                                  batchNumberController, TextInputType.text)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildExpDatePicker()),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: _buildSupplierDropdown(size)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildModalSection("Pricing Information", [
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField("Purchase Rate",
                                  purchaseRateController, TextInputType.number,
                                  isRequired: true)),
                          const SizedBox(width: 15),
                          Expanded(
                              child: _buildTextField("Sale Price",
                                  salePriceController, TextInputType.number,
                                  isRequired: true)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(
                                  "MRP", mrpController, TextInputType.number)),
                          const SizedBox(width: 15),
                          Expanded(
                              child: _buildTextField("Wholesale Price",
                                  wholesaleController, TextInputType.number)),
                        ],
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButton(
                  title: "Cancel",
                  fct: () => Navigator.of(context).pop(),
                  height: 40,
                  width: 100,
                  fontSize: FontSize.s12,
                  boxColor: Colors.white,
                  borderColor: ColorManager.kPrimaryColor,
                  textColor: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 10),
                CustomRoundButton(
                  title: "Save",
                  fct: _saveStockItem,
                  height: 40,
                  width: 100,
                  fontSize: FontSize.s12,
                  boxColor: ColorManager.kPrimaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s14, 0.27,
              ColorManager.textColor),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildTextField(
      String title, TextEditingController controller, TextInputType inputType,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: title,
          isStarRed: isRequired,
          isTextField: true,
          textStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
              0.27, Colors.black.withOpacity(0.6)),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextFormField(
            controller: controller,
            keyboardType: inputType,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
                0.27, ColorManager.textColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Enter $title",
              hintStyle: buildCustomStyle(FontWeightManager.regular,
                  FontSize.s12, 0.27, ColorManager.textColor.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(Size size) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        List<Category>? categoryList = categoryProvider.category;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              title: "Category",
              isStarRed: true,
              isTextField: true,
              textStyle: buildCustomStyle(FontWeightManager.regular,
                  FontSize.s12, 0.27, Colors.black.withOpacity(0.6)),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButton2<Category>(
                isExpanded: true,
                value: selectedCategory,
                hint: Text('Select Category',
                    style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5))),
                items: categoryList
                    ?.where((category) => category.categoryName != "ALL")
                    .map((category) {
                  return DropdownMenuItem<Category>(
                    value: category,
                    child: Text(category.categoryName ?? '',
                        style: buildCustomStyle(FontWeightManager.regular,
                            FontSize.s12, 0.27, ColorManager.textColor),
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (Category? value) {
                  setState(() {
                    selectedCategory = value;
                    selectedProduct = null;
                  });
                  if (value != null) {
                    Provider.of<GridSelectionProvider>(context, listen: false)
                        .listAllProducts(
                            filterCategory: value.categoryId.toString());
                  }
                },
                underline: Container(),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.grey.withOpacity(0.3))),
                ),
                buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.zero, decoration: BoxDecoration()),
                iconStyleData: const IconStyleData(
                    icon: Icon(Icons.arrow_drop_down), iconSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductDropdown(Size size) {
    return Consumer<GridSelectionProvider>(
      builder: (context, gridProvider, child) {
        List<GetProduct>? productList = gridProvider.getCategoryProductList;
        List<GetProduct> uniqueProducts = [];
        Set<int> seenIds = {};

        if (productList != null) {
          for (var product in productList) {
            if (product.productId != null &&
                !seenIds.contains(product.productId)) {
              seenIds.add(product.productId!);
              uniqueProducts.add(product);
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              title: "Product",
              isStarRed: true,
              isTextField: true,
              textStyle: buildCustomStyle(FontWeightManager.regular,
                  FontSize.s12, 0.27, Colors.black.withOpacity(0.6)),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButton2<GetProduct>(
                isExpanded: true,
                value: selectedProduct,
                hint: Text('Select Product',
                    style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5))),
                items: uniqueProducts.map((product) {
                  return DropdownMenuItem<GetProduct>(
                    value: product,
                    child: Text(product.productName ?? '',
                        style: buildCustomStyle(FontWeightManager.regular,
                            FontSize.s12, 0.27, ColorManager.textColor),
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (GetProduct? value) {
                  if (value != null) {
                    barcodeController.text = value.barcode ?? '';
                    salePriceController.text =
                        value.price?.price?.toString() ?? '0';
                    mrpController.text = value.mrp?.toString() ??
                        value.price?.price?.toString() ??
                        '0';
                    purchaseRateController.text =
                        value.stock?.firstOrNull?.purchasePrice ?? '0';
                    if (value.unit != null) selectedUnit = value.unit;
                  }
                  setState(() {
                    selectedProduct = value;
                  });
                },
                underline: Container(),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.grey.withOpacity(0.3))),
                ),
                buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.zero, decoration: BoxDecoration()),
                iconStyleData: const IconStyleData(
                    icon: Icon(Icons.arrow_drop_down), iconSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnitDropdown(Size size) {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        Map<String, String>? unitList = purchaseProvider.getUnitList;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              title: "Unit",
              isStarRed: true,
              isTextField: true,
              textStyle: buildCustomStyle(FontWeightManager.regular,
                  FontSize.s12, 0.27, Colors.black.withOpacity(0.6)),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButton2<String>(
                isExpanded: true,
                value: selectedUnit,
                hint: Text('Select Unit',
                    style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5))),
                items: unitList?.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value,
                        style: buildCustomStyle(FontWeightManager.regular,
                            FontSize.s12, 0.27, ColorManager.textColor),
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    selectedUnit = value;
                  });
                },
                underline: Container(),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.grey.withOpacity(0.3))),
                ),
                buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.zero, decoration: BoxDecoration()),
                iconStyleData: const IconStyleData(
                    icon: Icon(Icons.arrow_drop_down), iconSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupplierDropdown(Size size) {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        List<GetSuppliersModelData>? supplierList =
            purchaseProvider.supplierList;

        return BuildDropDownWithSearch<GetSuppliersModelData>(
          title: "Supplier",
          hintText: "Select Supplier",
          value: selectedSupplier,
          items: supplierList ?? [],
          onChanged: (value) {
            setState(() {
              selectedSupplier = value;
            });
          },
          displayText: (supplier) => supplier.user?.name ?? 'Unknown Supplier',
          searchController: supplierSearchController,
          isRequired: false,
          height: 45,
          searchHintText: "Search for supplier...",
        );
      },
    );
  }

  Widget _buildExpDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: "Expiry Date",
          isStarRed: true,
          isTextField: true,
          textStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
              0.27, Colors.black.withOpacity(0.6)),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          height: 45,
          child: CalendarPickerTableCell(
            initialDate: selectedExpDate,
            onDateSelected: (DateTime date) {
              setState(() {
                selectedExpDate = date;
              });
            },
          ),
        ),
      ],
    );
  }
}
