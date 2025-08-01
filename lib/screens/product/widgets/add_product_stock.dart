import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../../../components/build_back_button.dart';
import '../../../components/build_calendar_selection.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../components/build_text_fields.dart';
import '../../../components/build_title.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/get_product.dart';
import '../../../models/get_store.dart';
import '../../../models/category_list.dart' as category_models;
import '../../../providers/auth_model.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/grid_provider.dart';
import '../../../providers/stock_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

void showScaffold({required BuildContext context, required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class AddProductStockScreen extends StatefulWidget {
  const AddProductStockScreen({super.key});

  @override
  State<AddProductStockScreen> createState() => _AddProductStockScreenState();
}

class _AddProductStockScreenState extends State<AddProductStockScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SideBarController sideBarController = Get.put(SideBarController());

  // Form Controllers
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController purchaseRateController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController wholesalePriceController = TextEditingController();
  final TextEditingController wholesaleMinUnitController = TextEditingController();
  final TextEditingController rackController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController batchNumberController = TextEditingController();
  final TextEditingController purchaseNumberController = TextEditingController();

  // Selected Values
  GetProduct? selectedProduct;
  GetStoreModelData? selectedStore;
  category_models.Category? selectedCategory;
  String? selectedUnit;
  int selectedSupplierId = 1; // Default supplier ID
  DateTime selectedExpiryDate = DateTime.now().add(const Duration(days: 365));
  DateTime selectedDate = DateTime.now();
  DateTime selectedPurchaseDate = DateTime.now();
  bool taxInclude = false;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // You can add any initialization logic here
  }

  Future<void> _submitForm() async {
   
    if (!_formKey.currentState!.validate()) {
      showScaffold(context: context, message: 'Please fill all required fields');
      return;
    }
    debugPrint("🔄 Attempting to add stock with the following data:");
    debugPrint("📦 Product ID: ${selectedProduct?.productId}");
    debugPrint("🏷️ Category ID: ${selectedCategory?.categoryId}");
    debugPrint("🔢 Quantity: ${quantityController.text}");
    debugPrint("💰 Retail Price: ${retailPriceController.text}");
    debugPrint("📅 Expiry Date: ${DateFormat('yyyy-MM-dd').format(selectedExpiryDate)}");
    debugPrint("🏬 Store ID: ${selectedStore?.id}");
    debugPrint("📌 Unit: $selectedUnit");

    if (selectedCategory == null) {
      showScaffold(context: context, message: 'Please select a category');
      return;
    }
    
    if (selectedProduct == null) {
      showScaffold(context: context, message: 'Please select a product');
      return;
    }
    
    if (selectedStore == null) {
      showScaffold(context: context, message: 'Please select a store');
      return;
    }
    
    if (selectedUnit == null) {
      showScaffold(context: context, message: 'Please select a unit');
      return;
    }

                                setState(() {
      _isLoading = true;
    });

    try {
      final String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
      
      if (accessToken == null) {
        throw Exception('Access token not found');
      }


      debugPrint("===== API REQUEST PAYLOAD =====");
    debugPrint("Product ID: ${selectedProduct!.productId}");
    debugPrint("Category ID: ${selectedCategory!.categoryId}");
    debugPrint("Quantity: ${quantityController.text.isEmpty ? '1' : quantityController.text}");
    debugPrint("Retail Price: ${retailPriceController.text.isEmpty ? '0' : retailPriceController.text}");
    debugPrint("Expiry Date: ${DateFormat('yyyy-MM-dd').format(selectedExpiryDate)}");
   


      final result = await Provider.of<StockProvider>(context, listen: false)
          .addProductStockAPI(
        accessToken: accessToken,
        productId: selectedProduct!.productId.toString(),
        categoryId: selectedCategory!.categoryId.toString(),
        quantity: quantityController.text.isEmpty ? '1' : quantityController.text,
        retailPrice: retailPriceController.text.isEmpty ? '0.00' : double.parse(retailPriceController.text).toStringAsFixed(2),
        purchaseRate: purchaseRateController.text.isEmpty ? '0.00' : double.parse(purchaseRateController.text).toStringAsFixed(2),
        mrp: mrpController.text.isEmpty ? retailPriceController.text : mrpController.text,
        wholesalePrice: wholesalePriceController.text.isEmpty ? retailPriceController.text : wholesalePriceController.text,
        unit: selectedUnit!,
        supplierId: selectedSupplierId.toString(),
        storeId: selectedStore!.id.toString(),
        expiryDate: DateFormat('yyyy-MM-dd').format(selectedExpiryDate),
        userId: '1', // This should come from auth
        purchaseVoucherId: null,
        purchaseId: null,
        taxAmountRetail: null,
        taxAmountWholesale: null,
        wholesaleMinUnit: wholesaleMinUnitController.text.isEmpty ? '1' : wholesaleMinUnitController.text,
        rack: rackController.text.isEmpty ? '' : rackController.text,
        barcode: barcodeController.text.isEmpty ? '' : barcodeController.text,
        batchNumber: batchNumberController.text.isEmpty ? '' : batchNumberController.text,
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
        purchaseDate: DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
        purchaseNumber: purchaseNumberController.text.isEmpty ? null : purchaseNumberController.text,
        taxInclude: taxInclude,
        initialRetailPrice: retailPriceController.text.isEmpty ? '0' : retailPriceController.text,
        initialWholesalePrice: wholesalePriceController.text.isEmpty ? retailPriceController.text : wholesalePriceController.text,
        retailPriceTax: null,
        wholesalePriceTax: null,
        context: context, // ✅ Pass context for manual LocalProductProvider updates
      );


debugPrint("⬇️ RAW RESPONSE: ${result.toString()}");
debugPrint("Status: ${result['status']}");
debugPrint("Message: ${result['message']}");
debugPrint("Data: ${result['data'] ?? 'No data'}");

      if (result['status'] == 'success') {
        showScaffold(context: context, message: result['message'] ?? 'Stock added successfully');
        
        // ✅ LocalProductProvider is automatically updated via manual stock update (FAST!)
        // No need for slow 10-second API fetch - stock is instantly available in cart/local data
        if (mounted) {
          debugPrint("🚀 Stock added successfully - LocalProductProvider updated manually (no API delay!)");
        }
        
        _clearForm();
        sideBarController.index.value = 15; // Navigate back to stock list
        } else {
        showScaffold(context: context, message: result['message'] ?? 'Failed to add stock');
      }
    } catch (e) {
      showScaffold(context: context, message: 'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    quantityController.clear();
    retailPriceController.clear();
    purchaseRateController.clear();
    mrpController.clear();
    wholesalePriceController.clear();
    wholesaleMinUnitController.clear();
    rackController.clear();
    barcodeController.clear();
    batchNumberController.clear();
    purchaseNumberController.clear();
    
    setState(() {
      selectedProduct = null;
      selectedStore = null;
      selectedCategory = null;
      selectedUnit = null;
      selectedExpiryDate = DateTime.now().add(const Duration(days: 365));
      selectedDate = DateTime.now();
      selectedPurchaseDate = DateTime.now();
      taxInclude = false;
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
              const SizedBox(height: 20),
              Expanded(
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      blurRadius: 6,
                  padding: const EdgeInsets.all(20),
                      offsetValue: const Offset(1, 1),
                      child: SingleChildScrollView(
                        child: Form(
                      key: _formKey,
                            child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBasicDetailsSection(size),
                          const SizedBox(height: 20),
                          _buildPricingDetailsSection(size),
                          const SizedBox(height: 20),
                          _buildAdditionalDetailsSection(size),
                          const SizedBox(height: 20),
                          _buildDateSection(size),
                          const SizedBox(height: 30),
                          _buildActionButtons(size),
                        ],
                      ),
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

  Widget _buildBasicDetailsSection(Size size) {
    return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
          title: "Basic Details",
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
            FontSize.s16,
                                      0.27,
                                      Colors.black,
                                    ),
                                  ),
        const Divider(thickness: 0.5),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildCategoryDropdown(size)),
            const SizedBox(width: 20),
            Expanded(child: _buildProductDropdown(size)),
            const SizedBox(width: 20),
            Expanded(child: _buildStoreDropdown(size)),
          ],
        ),
        const SizedBox(height: 15),
        Row(
                                    children: [
            Expanded(child: _buildUnitDropdown(size)),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                                            isStarRed: true,
                                            isTextField: true,
                isRead: false,
                textInputType: TextInputType.number,
                controller: quantityController,
                title: "Quantity",
                hintText: "Enter quantity",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.text,
                controller: rackController,
                title: "Rack",
                hintText: "Enter rack location",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingDetailsSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: "Pricing Details",
                                            textStyle: buildCustomStyle(
                                              FontWeightManager.regular,
            FontSize.s16,
                                              0.27,
            Colors.black,
          ),
        ),
        const Divider(thickness: 0.5),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: true,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.number,
                controller: purchaseRateController,
                title: "Purchase Rate",
                hintText: "Enter purchase rate",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: true,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.number,
                controller: retailPriceController,
                title: "Retail Price",
                hintText: "Enter retail price",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.number,
                controller: mrpController,
                title: "MRP",
                hintText: "Enter MRP",
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.number,
                controller: wholesalePriceController,
                title: "Wholesale Price",
                hintText: "Enter wholesale price",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.number,
                controller: wholesaleMinUnitController,
                title: "Wholesale Min Unit",
                hintText: "Enter min unit",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: _buildTaxIncludeCheckbox()),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalDetailsSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: "Additional Details",
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s16,
            0.27,
            Colors.black,
          ),
        ),
        const Divider(thickness: 0.5),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.text,
                controller: barcodeController,
                title: "Barcode",
                hintText: "Enter barcode",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.text,
                controller: batchNumberController,
                title: "Batch Number",
                hintText: "Enter batch number",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: BuildTextFieldColumn3(
                isLeft: false,
                size: size,
                isStarRed: false,
                isTextField: true,
                isRead: false,
                textInputType: TextInputType.text,
                controller: purchaseNumberController,
                title: "Purchase Number",
                hintText: "Enter purchase number",
                                            ),
                                          ),
                                        ],
                                      ),
      ],
    );
  }

  Widget _buildDateSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          BuildTextTile(
          title: "Date Information",
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s16,
            0.27,
            Colors.black,
          ),
        ),
        const Divider(thickness: 0.5),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuildTextTile(
                    isStarRed: false,
                                            isTextField: true,
                    title: "Date",
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
                                            height: size.height * .07,
                    margin: const EdgeInsets.only(left: 20),
                    child: CalendarPickerTableCell(
                      initialDate: selectedDate,
                      onDateSelected: (DateTime date) {
                                                  setState(() {
                          selectedDate = date;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuildTextTile(
                    isStarRed: false,
                    isTextField: true,
                    title: "Purchase Date",
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
                    height: size.height * .07,
                    margin: const EdgeInsets.only(left: 20),
                    child: CalendarPickerTableCell(
                      initialDate: selectedPurchaseDate,
                      onDateSelected: (DateTime date) {
                        setState(() {
                          selectedPurchaseDate = date;
                        });
                      },
                                            ),
                                          ),
                                        ],
                                      ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                  BuildTextTile(
                                          isStarRed: true,
                                          isTextField: true,
                    title: "Expiry Date",
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
                    height: size.height * .07,
                    margin: const EdgeInsets.only(left: 20),
                    child: CalendarPickerTableCell(
                      initialDate: selectedExpiryDate,
                      onDateSelected: (DateTime date) {
                        setState(() {
                          selectedExpiryDate = date;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(Size size) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        List<category_models.Category>? categoryList = categoryProvider.category;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          BuildTextTile(
              title: "Select Category",
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
              child: DropdownButton2<category_models.Category>(
                isExpanded: true,
                value: selectedCategory,
                hint: Text(
                  'Select Category',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                items: categoryList?.where((category) => category.categoryName != "ALL").map((category) {
                  return DropdownMenuItem<category_models.Category>(
                    value: category,
                    child: Text(
                      category.categoryName ?? '',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (category_models.Category? value) {
                  setState(() {
                    selectedCategory = value;
                    selectedProduct = null; // Reset product when category changes
                  });
                  
                  if (value != null) {
                    // Load products for selected category
                    Provider.of<GridSelectionProvider>(context, listen: false)
                        .listAllProducts(filterCategory: value.categoryId.toString());
                  }
                },
                underline: Container(),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                buttonStyleData: ButtonStyleData(
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                ),
                iconStyleData: const IconStyleData(
                  icon: Icon(Icons.arrow_drop_down),
                  iconSize: 20,
                ),
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
        
        // Remove duplicates by product ID and ensure selected product is valid
        List<GetProduct> uniqueProducts = [];
        Set<int> seenIds = {};
        
        if (productList != null) {
          for (var product in productList) {
            if (product.productId != null && !seenIds.contains(product.productId)) {
              seenIds.add(product.productId!);
              uniqueProducts.add(product);
            }
          }
        }
        
        // Check if selected product is still in the list
        if (selectedProduct != null && 
            !uniqueProducts.any((p) => p.productId == selectedProduct!.productId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                selectedProduct = null;
              });
            }
          });
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              title: "Select Product",
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
              margin: EdgeInsets.zero, // Remove margin to prevent overflow
              padding: const EdgeInsets.symmetric(horizontal: 10), // Reduced padding
              height: size.height * .07,
              child: DropdownButton2<GetProduct>(
                isExpanded: true, // Allow dropdown to expand fully
                value: selectedProduct,
                hint: Text(
                  'Select Product',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                items: uniqueProducts.map((product) {
                  return DropdownMenuItem<GetProduct>(
                    value: product,
                    child: Text(
                      product.productName ?? '',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      overflow: TextOverflow.ellipsis, // Handle long product names
                    ),
                  );
                }).toList(),
                onChanged: (GetProduct? value) {
                  setState(() {
                    selectedProduct = value;
                  });
                },
                underline: Container(), // Remove underline
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200, // Limit dropdown height
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                buttonStyleData: ButtonStyleData(
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                ),
                iconStyleData: const IconStyleData(
                  icon: Icon(Icons.arrow_drop_down),
                  iconSize: 20,
                ),
              ),
            ),
          ],
        );
      },
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
              title: "Select Store",
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
                hint: Text(
                  'Select Store',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                items: storeList?.map((store) {
                  return DropdownMenuItem<GetStoreModelData>(
                    value: store,
                    child: Text(
                      store.name ?? '',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                buttonStyleData: ButtonStyleData(
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                ),
                iconStyleData: const IconStyleData(
                  icon: Icon(Icons.arrow_drop_down),
                  iconSize: 20,
                ),
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
              child: DropdownButton2<String>(
                isExpanded: true,
                value: selectedUnit,
                hint: Text(
                  'Select Unit',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                items: unitList?.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                buttonStyleData: ButtonStyleData(
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                ),
                iconStyleData: const IconStyleData(
                  icon: Icon(Icons.arrow_drop_down),
                  iconSize: 20,
                ),
                ),
                                                ),
                                              ],
                                            );
      },
    );
  }

  Widget _buildTaxIncludeCheckbox() {
                                            return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                BuildTextTile(
          title: "Tax Include",
          isStarRed: false,
                                                  isTextField: true,
                                                  textStyle: buildCustomStyle(
                                                    FontWeightManager.regular,
                                                    FontSize.s14,
                                                    0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        CheckboxListTile(
          title: const Text('Include Tax'),
          value: taxInclude,
          onChanged: (bool? value) {
                                                      setState(() {
              taxInclude = value ?? false;
                                                      });
                                                    },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
                                                ),
                                              ],
                                            );
                                          }

  Widget _buildActionButtons(Size size) {
    return Row(
      children: [
        CustomRoundButton(
          title: _isLoading ? "Adding..." : "Add Stock",
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