import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';

class AddProductWithBarcodeModal extends StatefulWidget {
  final String? barcode;
  final bool isAddToCart;

  const AddProductWithBarcodeModal(
      {Key? key, this.barcode, this.isAddToCart = false})
      : super(key: key);

  @override
  State<AddProductWithBarcodeModal> createState() =>
      _AddProductWithBarcodeModalState();
}

class _AddProductWithBarcodeModalState
    extends State<AddProductWithBarcodeModal> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Step 1
  final TextEditingController _productBarcodeController =
      TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productMRPController = TextEditingController();
  final TextEditingController _productQuantityController =
      TextEditingController();
  final TextEditingController _productSellingPriceController =
      TextEditingController();
  final TextEditingController _productPurchasePriceController =
      TextEditingController();
  final TextEditingController _unitSearchController = TextEditingController();
  final TextEditingController _categorySearchController =
      TextEditingController();
  bool isLoading = false;
  bool isBarcodeGenerating = false;
  String? selectedUnit;
  Category? selectedCategory;
  bool isValidatedOnce = false;

  @override
  void initState() {
    if (widget.barcode != null) {
      _productBarcodeController.text = widget.barcode!;
    }

    // Set default quantity value to 0 when opening the modal
    _productQuantityController.text = '0';
    super.initState();
  }

  @override
  void dispose() {
    _productBarcodeController.dispose();
    _productNameController.dispose();
    _productMRPController.dispose();
    _productQuantityController.dispose();
    _productSellingPriceController.dispose();
    _productPurchasePriceController.dispose();
    _unitSearchController.dispose();
    _categorySearchController.dispose();
    isLoading = false;
    selectedUnit = null;
    selectedCategory = null;
    isValidatedOnce = false;
    super.dispose();
  }

  Future<void> generateBarcode() async {
    if (isBarcodeGenerating) return;

    setState(() {
      isBarcodeGenerating = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Authentication token not found. Please log in again.',
        );
        return;
      }

      GridSelectionProvider gridSelectionProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);

      final Map<String, dynamic>? result = await gridSelectionProvider
          .generateBarcodeAPI(accessToken: accessToken);

      if (result != null &&
          result['status'] == 'success' &&
          result['data'] != null) {
        final String generatedBarcode = result['data']['barcode'];

        setState(() {
          _productBarcodeController.text = generatedBarcode;
        });

        showScaffold(
          context: context,
          message: 'Barcode generated successfully',
        );
      } else {
        showScaffoldError(
          context: context,
          message: result?['message'] ?? 'Failed to generate barcode',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Error generating barcode: ${e.toString()}',
      );
    } finally {
      setState(() {
        isBarcodeGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    Map<String, String>? unitList = purchaseProvider.getUnitList;

    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    List<Category>? categoryList = categoryProvider.category;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: size.width * 0.45,
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Create New Product",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
                Text(
                  widget.barcode != null
                      ? "No product found with barcode ${widget.barcode}"
                      : "Create a new product with custom barcode",
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                // Row 1: Product Name, Barcode
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Product Name",
                        _productNameController,
                        TextInputType.text,
                        size,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBarcodeField(size),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Unit, Category
                Row(
                  children: [
                    Expanded(
                      child: _buildUnitDropdown(size, unitList),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCategoryDropdown(size, categoryList),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: MRP, Purchase Price
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Product MRP",
                        _productMRPController,
                        TextInputType.number,
                        size,
                        isRequired: false,
                        inputFormatter: FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        "Purchase Price",
                        _productPurchasePriceController,
                        TextInputType.number,
                        size,
                        isRequired: true,
                        inputFormatter: FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 4: Selling Price, Quantity
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Selling Price",
                        _productSellingPriceController,
                        TextInputType.number,
                        size,
                        isRequired: true,
                        inputFormatter: FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        "Quantity",
                        _productQuantityController,
                        TextInputType.number,
                        size,
                        isRequired: true,
                        inputFormatter: FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Close Button
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: ColorManager.kPrimaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: ColorManager.kPrimaryColor,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Add Product Button
                    SizedBox(
                      width: 120,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                "Add Product",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: FontSize.s12,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for text fields
  Widget _buildTextField(
    String title,
    TextEditingController controller,
    TextInputType keyboardType,
    Size size, {
    bool isRequired = false,
    TextInputFormatter? inputFormatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.only(left: 12),
          height: size.height * 0.048,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  }
                : null,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.27,
              ColorManager.textColor.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  // Barcode field with generate button
  Widget _buildBarcodeField(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Barcode',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CustomBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.only(left: 12),
                height: size.height * 0.048,
                width: double.infinity,
                child: TextFormField(
                  controller: _productBarcodeController,
                  readOnly: widget.barcode != null,
                  cursorColor: ColorManager.kPrimaryColor,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: size.height * 0.048,
              width: size.height * 0.048,
              child: ElevatedButton(
                onPressed: widget.barcode != null || isBarcodeGenerating
                    ? null
                    : generateBarcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: isBarcodeGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Unit dropdown
  Widget _buildUnitDropdown(Size size, Map<String, String>? unitList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Product Unit',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<String>(
          title: "",
          hintText: "Choose Product Unit",
          value: selectedUnit,
          height: size.height * 0.048,
          margin: EdgeInsets.zero,
          items: unitList?.entries.map((entry) => entry.key).toList() ?? [],
          onChanged: (String? newValue) {
            setState(() {
              selectedUnit = newValue;
            });
          },
          displayText: (item) => unitList?[item] ?? '',
          searchController: _unitSearchController,
        ),
        if (isValidatedOnce && selectedUnit == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Required',
              style: TextStyle(color: Colors.red[700], fontSize: 11),
            ),
          ),
      ],
    );
  }

  // Category dropdown
  Widget _buildCategoryDropdown(Size size, List<Category>? categoryList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Product Category',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<Category>(
          title: "",
          hintText: "Select Category",
          value: selectedCategory,
          height: size.height * 0.048,
          margin: EdgeInsets.zero,
          items: categoryList ?? [],
          onChanged: (Category? newCategory) {
            setState(() {
              selectedCategory = newCategory;
            });
          },
          displayText: (category) => category.categoryName ?? '',
          searchController: _categorySearchController,
        ),
        if (isValidatedOnce && selectedCategory == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Required',
              style: TextStyle(color: Colors.red[700], fontSize: 11),
            ),
          ),
      ],
    );
  }

  // Submit form
  Future<void> _submitForm() async {
    setState(() {
      isValidatedOnce = true;
    });

    bool isFormValid = formKey.currentState!.validate();
    bool isUnitValid = selectedUnit != null;
    bool isCategoryValid = selectedCategory != null;

    if (isFormValid && isUnitValid && isCategoryValid) {
      formKey.currentState!.save();
      setState(() {
        isLoading = true;
      });

      try {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        GridSelectionProvider gridSelectionProvider =
            Provider.of<GridSelectionProvider>(context, listen: false);

        final result = await gridSelectionProvider.createProductAPI(
          categoryId: selectedCategory!.categoryId.toString(),
          productName: _productNameController.text,
          sellingPrice: _productSellingPriceController.text,
          mrp: _productMRPController.text,
          unit: selectedUnit!,
          quantity: _productQuantityController.text,
          barcode: _productBarcodeController.text,
          accessToken: accessToken ?? "",
          purchasePrice: _productPurchasePriceController.text,
        );

        if (result is Map<String, dynamic> && result.containsKey('data')) {
          try {
            GetProduct product = GetProduct.fromJson(result['data']);
            Provider.of<LocalProductProvider>(context, listen: false)
                .addProduct(product);
          } catch (e) {
            debugPrint("Error parsing product: $e");
          }

          if (widget.isAddToCart) {
            Provider.of<LocalProductProvider>(context, listen: false).addToCart(
              productId: result["data"]['product_id'],
              price: double.parse(_productSellingPriceController.text),
              quantity: 1,
            );
          }

          Provider.of<LocalProductProvider>(context, listen: false)
              .refreshProducts();

          try {
            final returnedProduct = GetProduct.fromJson(result['data']);
            Navigator.pop(context, {
              'product': returnedProduct,
              'initialQuantity': _productQuantityController.text,
            });
          } catch (_) {
            Navigator.pop(context, {
              'product': result['data'],
              'initialQuantity': _productQuantityController.text,
            });
          }
          showScaffold(context: context, message: 'Product added successfully');
        } else {
          String errorMessage = 'Failed to add product';
          if (result is Map<String, dynamic>) {
            if (result.containsKey('message')) {
              errorMessage = result['message'].toString();
            } else if (result.containsKey('errors')) {
              Map<String, dynamic> errors = result['errors'];
              List<String> errorMessages = [];
              errors.forEach((field, messages) {
                if (messages is List) {
                  for (var message in messages) {
                    errorMessages.add("$field: $message");
                  }
                } else {
                  errorMessages.add("$field: $messages");
                }
              });
              errorMessage = errorMessages.join('\n');
            }
          } else if (result is String) {
            try {
              final jsonResponse = json.decode(result);
              if (jsonResponse['message'] != null) {
                errorMessage = jsonResponse['message'];
              }
            } catch (e) {
              errorMessage = result;
            }
          }
          showScaffoldError(context: context, message: errorMessage);
        }
      } catch (e) {
        showScaffoldError(
          context: context,
          message: 'Error adding product: ${e.toString()}',
        );
        debugPrint("Error in product creation: $e");
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      showScaffoldError(
        context: context,
        message: 'Please fill all required fields correctly',
      );
    }
  }
}
