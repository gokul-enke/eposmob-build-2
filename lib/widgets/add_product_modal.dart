import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';

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
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Form(
          // Step 2
          key: formKey, // Step 1
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create New Product",
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
              Text(
                widget.barcode != null
                    ? "No product was found with the barcode ${widget.barcode} , would you like to create a new product?"
                    : "Create a new product with custom barcode",
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Product Name TextField
                  buildColumnWidgetForTextFields(
                    autofocus: true,
                    isStarRed: true,
                    controller: _productNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    onchanged: (value) {
                      // Remove validation loop - only validate on submit
                    },
                    hintText: 'Product Name',
                    size: size,
                    width: size.width / 4.5,
                  ),

                  // Product Barcode TextField with Generate Button
                  Container(
                    width: size.width / 4.5,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: buildColumnWidgetForTextFields(
                            autofocus: true,
                            isStarRed: true,
                            controller: _productBarcodeController,
                            margin: const EdgeInsets.all(0),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
                              }
                              return null;
                            },
                            onchanged: (value) {
                              // Remove validation loop - only validate on submit
                            },
                            hintText: 'Barcode',
                            readOnly: widget.barcode != null,
                            size: size,
                            width: size.width / 4.5 -
                                56, // Adjust width for button
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                widget.barcode != null || isBarcodeGenerating
                                    ? null
                                    : generateBarcode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isBarcodeGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Product Unit Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: size.width / 4.4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildDropDownWithSearch<String>(
                          title: 'Product Unit',
                          hintText: 'Choose Product Unit',
                          value: selectedUnit,
                          margin: const EdgeInsets.only(left: 5),
                          items: unitList?.entries
                                  .map((entry) => entry.key)
                                  .toList() ??
                              [],
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedUnit = newValue;
                            });
                          },
                          displayText: (item) => unitList?[item] ?? '',
                          searchController: _unitSearchController,
                          isRequired: true,
                          height: size.height * .07,
                          showName: false,
                        ),
                        if (isValidatedOnce && selectedUnit == null)
                          Padding(
                            padding: const EdgeInsets.only(left: 5, top: 5),
                            child: Text(
                              'Product Unit is required',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Product Category Dropdown
                  SizedBox(
                    width: size.width / 4.4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildDropDownWithSearch<Category>(
                          title: 'Product Category',
                          hintText: 'Select Category',
                          value: selectedCategory,
                          margin: const EdgeInsets.only(right: 5),
                          items: categoryList ?? [],
                          onChanged: (Category? newCategory) {
                            setState(() {
                              selectedCategory = newCategory;
                            });
                          },
                          displayText: (category) =>
                              category.categoryName ?? '',
                          searchController: _categorySearchController,
                          isRequired: true,
                          height: size.height * .07,
                          showName: false,
                          width: size.width / 4.5,
                        ),
                        if (isValidatedOnce && selectedCategory == null)
                          Padding(
                            padding: const EdgeInsets.only(right: 5, top: 5),
                            child: Text(
                              'Product Category is required',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Product MRP TextField
                  buildColumnWidgetForTextFields(
                    width: size.width / 4.5,
                    autofocus: true,
                    isStarRed: true,
                    controller: _productMRPController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    onchanged: (value) {
                      // Remove validation loop - only validate on submit
                    },
                    hintText: 'Product MRP',
                    size: size,
                  ),
                  // Product Purchase Price TextField
                  buildColumnWidgetForTextFields(
                    autofocus: true,
                    isStarRed: true,
                    controller: _productPurchasePriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    onchanged: (value) {
                      // Remove validation loop - only validate on submit
                    },
                    hintText: 'Purchase Price',
                    size: size,
                    width: size.width / 4.5,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Product Selling Price TextField
                  buildColumnWidgetForTextFields(
                    autofocus: true,
                    isStarRed: true,
                    controller: _productSellingPriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    onchanged: (value) {
                      // Remove validation loop - only validate on submit
                    },
                    hintText: 'Product Selling Price',
                    size: size,
                    width: size.width / 4.5,
                  ),
                  // Product Quantity TextField
                  buildColumnWidgetForTextFields(
                    width: size.width / 4.5,
                    autofocus: true,
                    isStarRed: true,
                    controller: _productQuantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    onchanged: (value) {
                      // Remove validation loop - only validate on submit
                    },
                    hintText: 'Quantity',
                    size: size,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Close Button

                  CustomRoundButton(
                    title: "Close",
                    isLoading: isLoading,
                    fontSize: FontSize.s12,
                    height: MediaQuery.of(context).size.height * .05,
                    width: 120,
                    textColor: Colors.blue,
                    borderColor: Colors.blue,
                    boxColor: Colors.white,
                    fct: () async {
                      Navigator.pop(context, null);
                    },
                  ),
                  const SizedBox(width: 10),
                  // Add Product Button
                  CustomRoundButton(
                    title: "Add Product",
                    isLoading: isLoading,
                    fontSize: FontSize.s12,
                    height: MediaQuery.of(context).size.height * .05,
                    width: 120,
                    fct: () async {
                      setState(() {
                        isValidatedOnce = true;
                      });

                      // Validate form fields and dropdowns
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
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          GridSelectionProvider gridSelectionProvider =
                              Provider.of<GridSelectionProvider>(context,
                                  listen: false);

                          final result =
                              await gridSelectionProvider.createProductAPI(
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

                          // Handle success response
                          if (result is Map<String, dynamic> &&
                              result.containsKey('data')) {
                            try {
                              GetProduct product =
                                  GetProduct.fromJson(result['data']);
                              Provider.of<LocalProductProvider>(context,
                                      listen: false)
                                  .addProduct(product);
                            } catch (e) {
                              debugPrint("Error parsing product: $e");
                            }

                            // Add the product directly to the cart
                            if (widget.isAddToCart) {
                              Provider.of<LocalProductProvider>(context,
                                      listen: false)
                                  .addToCart(
                                productId: result["data"]['product_id'],
                                price: double.parse(
                                    _productSellingPriceController.text),
                                quantity: 1,
                              );
                            }

                            Provider.of<LocalProductProvider>(context,
                                    listen: false)
                                .refreshProducts();

                            // Return the created product and the entered quantity back to the caller so they can auto-fill
                            // Prefer returning the parsed GetProduct object. Include initialQuantity explicitly.
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
                            showScaffold(
                              context: context,
                              message: 'Product added successfully',
                            );
                          } else {
                            // Handle error response
                            String errorMessage = 'Failed to add product';

                            if (result is Map<String, dynamic>) {
                              if (result.containsKey('message')) {
                                errorMessage = result['message'].toString();
                              } else if (result.containsKey('errors')) {
                                // Handle validation errors
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
                                // Try to parse as JSON if it's a string
                                final jsonResponse = json.decode(result);
                                if (jsonResponse['message'] != null) {
                                  errorMessage = jsonResponse['message'];
                                }
                              } catch (e) {
                                errorMessage = result;
                              }
                            }

                            showScaffoldError(
                              context: context,
                              message: errorMessage,
                            );
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
                        // Show validation error
                        showScaffoldError(
                          context: context,
                          message: 'Please fill all required fields correctly',
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
