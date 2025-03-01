import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class AddProductWithBarcodeModal extends StatefulWidget {
  final String barcode;

  const AddProductWithBarcodeModal({Key? key, required this.barcode})
      : super(key: key);

  @override
  State<AddProductWithBarcodeModal> createState() =>
      _AddProductWithBarcodeModalState();
}

class _AddProductWithBarcodeModalState
    extends State<AddProductWithBarcodeModal> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Step 1
  TextEditingController? _productBarcodeController;
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productMRPController = TextEditingController();
  final TextEditingController _productSellingPriceController =
      TextEditingController();
  bool isLoading = false;
  String? selectedUnit;
  Category? selectedCategory;
  bool isValidatedOnce = false;

  @override
  void initState() {
    _productBarcodeController = TextEditingController(text: widget.barcode);
    super.initState();
  }

  @override
  void dispose() {
    _productBarcodeController?.dispose();
    _productNameController.dispose();
    _productMRPController.dispose();
    _productSellingPriceController.dispose();
    isLoading = false;
    selectedUnit = null;
    selectedCategory = null;
    isValidatedOnce = false;
    super.dispose();
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
                "No product was found with the barcode ${widget.barcode} , would you like to create a new product?",
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
                      if (isValidatedOnce) {
                        formKey.currentState!.validate();
                      }
                    },
                    hintText: 'Product Name',
                    size: size,
                    width: size.width / 4.5,
                  ),

                  // Product Barcode TextField
                  buildColumnWidgetForTextFields(
                    autofocus: true,
                    isStarRed: true,
                    controller: _productBarcodeController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    hintText: 'Barcode',
                    readOnly: true,
                    size: size,
                    width: size.width / 4.5,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Product Unit Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    width: size.width / 4.5,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: InputBorder.none, // Remove the underline
                      ),
                      value: selectedUnit,
                      hint: Text(
                        'Choose Product Unit',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      iconSize: 24,
                      elevation: 16,
                      onChanged: (String? newValue) {
                        if (isValidatedOnce) {
                          formKey.currentState!.validate();
                        }
                        setState(() {
                          selectedUnit =
                              newValue; // Update selectedUnit in state
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        return null;
                      },
                      items: unitList!.entries.map((entry) {
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
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Product Category Dropdown
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    padding: const EdgeInsets.only(left: 15, right: 15),
                    height: size.height * .07,
                    width: size.width / 4.5,
                    child: DropdownButtonFormField<Category>(
                      decoration: const InputDecoration(
                        border: InputBorder.none, // Remove the underline
                      ),
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
                      items: categoryList!
                          .map((Category category) {
                            return DropdownMenuItem<Category>(
                                value: category,
                                child: Text(
                                  category.categoryName ?? '',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                ));
                          })
                          .toSet()
                          .toList(),
                      onChanged: (Category? Category) {
                        if (Category != null) {
                          setState(() {
                            selectedCategory = Category;
                          });
                        }
                      },
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
                      if (isValidatedOnce) {
                        formKey.currentState!.validate();
                      }
                    },
                    hintText: 'Product MRP',
                    size: size,
                  ),
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
                      if (isValidatedOnce) {
                        formKey.currentState!.validate();
                      }
                    },
                    hintText: 'Product Selling Price',
                    size: size,
                    width: size.width / 4.5,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Add Product Button
                  CustomRoundButton(
                    title: "Add Product",
                    isLoading: isLoading,
                    fontSize: FontSize.s12,
                    height: MediaQuery.of(context).size.height * .05,
                    width: 120,
                    fct: () async {
                      isValidatedOnce = true;
                      if (formKey.currentState!.validate()) {
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
                          gridSelectionProvider
                              .createProductAPI(
                            categoryId: selectedCategory!.categoryId.toString(),
                            productName: _productNameController.text,
                            sellingPrice: _productSellingPriceController.text,
                            mrp: _productMRPController.text,
                            unit: selectedUnit!,
                            barcode: _productBarcodeController!.text,
                            accessToken: accessToken ?? "",
                          )
                              .then((value) {
                            debugPrint("value $value");

                            Navigator.pop(context, {
                              'price': _productSellingPriceController.text,
                              'id': value["data"]['product_id'],
                            });
                            showScaffold(
                              context: context,
                              message: 'Product added successfully',
                            );
                          });
                        } catch (e) {
                          showScaffold(
                            context: context,
                            message: 'Error adding product',
                          );
                          debugPrint("Error setting loading state: $e");
                        } finally {
                          setState(() {
                            isLoading = false;
                          });
                        }
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
