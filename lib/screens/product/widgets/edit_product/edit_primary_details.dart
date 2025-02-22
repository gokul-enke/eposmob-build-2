import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:provider/provider.dart';

import '../../../../components/build_container_box.dart';
import '../../../../components/build_round_button.dart';
import '../../../../components/build_title.dart';
import '../../../../controllers/sidebar_controller.dart';
import '../../../../models/category_list.dart';
import '../../../../providers/auth_model.dart';
import '../../../../providers/category_providers.dart';
import '../../../../providers/grid_provider.dart';
import '../../../../providers/purchase_provider.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';

class EditProductPageScreen extends StatefulWidget {
  final Function(int) navigateToScreen;
  const EditProductPageScreen({super.key, required this.navigateToScreen});

  @override
  State<EditProductPageScreen> createState() => _EditProductPageScreenState();
}

class _EditProductPageScreenState extends State<EditProductPageScreen> {
  @override
  Widget build(BuildContext context) {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);

    GetProduct? getProduct = gridSelectionProvider.getProductDetails;

    final productNameController =
        TextEditingController(text: getProduct?.productName ?? '');
    final productSlugController =
        TextEditingController(text: getProduct?.productSlug ?? '');
    final productPriceController =
        TextEditingController(text: getProduct!.price!.toString());
    final productBarcodeController =
        TextEditingController(text: getProduct.barcode ?? 'barcode');

    final TextEditingController idController = TextEditingController(text: "0");
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    GlobalKey<FormState> formKey = GlobalKey<FormState>();

    // Access the CategoryProvider
    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    String? parentCategory;
    // Access the category list
    List<Category>? categoryList = categoryProvider.category;

    // Define the list of units
    // List<String> units = [
    //   'Choose Product Unit',
    //   'Kilo Gram',
    //   'Piece',
    //   "Pack",
    //   "Dozen",
    //   "Litre"
    // ];

    // Track the selected unit
    String? selectedUnit;
    // Define the list of currency
    List<String> currency = [
      'Choose Currency',
      'QAR',
      'AED',
      "INR",
    ];

    // Track the selected unit
    String? selectedCurrency;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    Map<String, String>? unitList = purchaseProvider.getUnitList;

    // debugPrint(getProduct.productName);

// Assign default values
    selectedUnit = getProduct.unit; // Use 'Piece' as the default unit
    selectedCurrency = getProduct.currency; // Use 'INR' as the default currency

    print({"currency", getProduct.currency});

    if (getProduct.categoryId != null) {
      parentCategory = getProduct.categoryId.toString();
      categoryProvider.setParentCategory(parentCategory);
      int? categoryIndex = categoryList?.indexWhere(
          (category) => category.categoryId == getProduct.categoryId);
      if (categoryIndex != null && categoryIndex >= 0) {
        categoryProvider.selectCategory(
          categoryIndex,
          categoryList![categoryIndex].categoryName ?? '',
          categoryList[categoryIndex].productsCount ?? 0,
        );
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: size.height * 0.8,
            width: double.infinity,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              // margin: const EdgeInsets.only(bottom: 10),
              blurRadius: 6,
              padding: const EdgeInsets.only(
                  left: 10.0, right: 20, top: 30, bottom: 10),
              offsetValue: const Offset(1, 1),

              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              Column(
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 0),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: DropdownButtonFormField<Category>(
                                      decoration: const InputDecoration(
                                        border: InputBorder
                                            .none, // Remove the underline
                                      ),
                                      value: categoryProvider
                                                  .selectedCategoryIndex >=
                                              0
                                          ? categoryList![categoryProvider
                                              .selectedCategoryIndex]
                                          : null,
                                      hint: Text(
                                        'Select Category',
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      items: categoryList!
                                          .map((Category category) {
                                            return DropdownMenuItem<Category>(
                                                value: category,
                                                child: category.categoryName ==
                                                        "ALL"
                                                    ? Text(
                                                        ' Please Select',
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s12,
                                                          0.27,
                                                          ColorManager.textColor
                                                              .withOpacity(.5),
                                                        ),
                                                      )
                                                    : Text(
                                                        category.categoryName ??
                                                            '',
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s12,
                                                          0.27,
                                                          ColorManager.textColor
                                                              .withOpacity(.5),
                                                        ),
                                                      ));
                                          })
                                          .toSet()
                                          .toList(),
                                      onChanged: (Category? selectedCategory) {
                                        if (selectedCategory != null) {
                                          // Update the selected category in the provider
                                          categoryProvider.selectCategory(
                                            categoryList
                                                .indexOf(selectedCategory),
                                            selectedCategory.categoryName ?? '',
                                            selectedCategory.productsCount ?? 0,
                                          );
                                          parentCategory =
                                              "${selectedCategory.categoryId ?? 0}";
                                          // debugPrint(parentCategory);
                                          categoryProvider.setParentCategory(
                                              "${selectedCategory.categoryId ?? 0}");
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: "Name",
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
                                    margin: const EdgeInsets.only(left: 20),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: TextFormField(
                                      onChanged: ((value) {
                                        productSlugController.text =
                                            productNameController.text
                                                .replaceAll(" ", "_")
                                                .toLowerCase();
                                      }),
                                      keyboardType: TextInputType.text,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Product Name',
                                        hintStyle: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      controller: productNameController,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: "Product Slug",
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 0),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: TextFormField(
                                      readOnly: true,
                                      keyboardType: TextInputType.text,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Product Slug',
                                        hintStyle: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      controller: productSlugController,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: "Price",
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
                                    margin: const EdgeInsets.only(left: 20),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: TextFormField(
                                      //  initialValue: initialValue,
                                      keyboardType: TextInputType.text,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Price',
                                        hintStyle: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      controller: productPriceController,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: "Barcode",
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 0),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: TextFormField(
                                      //  initialValue: initialValue,
                                      keyboardType: TextInputType.text,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Barcode',
                                        hintStyle: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      controller: productBarcodeController,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
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
                                    margin: const EdgeInsets.only(left: 20),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        border: InputBorder
                                            .none, // Remove the underline
                                      ),
                                      value: selectedUnit,
                                      hint: Text(
                                        'Choose Product Unit',
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      icon: const Icon(Icons.arrow_drop_down),
                                      iconSize: 24,
                                      elevation: 16,
                                      onChanged: (String? newValue) {
                                        selectedUnit = newValue!;
                                      },
                                      items: unitList!.entries.map((entry) {
                                        return DropdownMenuItem<String>(
                                          value: entry
                                              .key, // Set the value for the dropdown item
                                          child: Text(
                                            entry.value,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5),
                                            ),
                                          ), // Display the value as the dropdown item
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: "Currency",
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 05, vertical: 0),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3,
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        border: InputBorder
                                            .none, // Remove the underline
                                      ),
                                      value: selectedCurrency,
                                      hint: Text(
                                        'Choose Currency',
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                      icon: const Icon(Icons.arrow_drop_down),
                                      iconSize: 24,
                                      elevation: 16,
                                      onChanged: (String? newValue) {
                                        selectedCurrency = newValue!;
                                      },
                                      items: currency
                                          .map((String unit) {
                                            return DropdownMenuItem<String>(
                                              value: unit,
                                              child: Text(
                                                unit,
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                            );
                                          })
                                          .toSet()
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: CustomRoundButton(
                                title: "Next",
                                fct: () async {
                                  // debugPrint(parentCategory);
                                  idController.text =
                                      categoryProvider.getParentCategory;
                                  // debugPrint("idController.tex");
                                  // debugPrint(idController.text);
                                  debugPrint(
                                      "selectedCurrency $selectedCurrency");
                                  // debugPrint("selectedUnit $selectedUnit");
                                  if (formKey.currentState!.validate()) {
                                    formKey.currentState!.save();
                                    // debugPrint("submit");
                                    debugPrint(
                                        "categoryIdController.text ${idController.text}");

                                    if (productPriceController.text.isEmpty ||
                                        productBarcodeController.text.isEmpty ||
                                        productSlugController.text.isEmpty ||
                                        productNameController.text.isEmpty ||
                                        selectedCurrency == null ||
                                        selectedUnit == null) {
                                      showScaffold(
                                        context: context,
                                        message:
                                            'Please Fill the Required Fields',
                                      );
                                      sideBarController.index.value = 14;
                                    } else {
                                      showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) {
                                            return const Center(
                                              child: CircularProgressIndicator
                                                  .adaptive(),
                                            );
                                          });
                                      String? accessToken =
                                          Provider.of<AuthModel>(context,
                                                  listen: false)
                                              .token;
                                      debugPrint(
                                          "accessToken From AuthModel $accessToken");
                                      gridSelectionProvider
                                          .editProductAPI(
                                        productName: productNameController.text,
                                        price: productPriceController.text,
                                        barcode: productBarcodeController.text,
                                        accessToken: accessToken ?? "",
                                        categoryId: idController.text,
                                        unit: selectedUnit ?? "Piece",
                                        slug: productSlugController.text,
                                        currency: selectedCurrency ?? "INR",
                                        productId: "${getProduct.productId}",
                                      )
                                          .then((value) {
                                        if (value["status"] == "success") {
                                          gridSelectionProvider
                                              .listAllProductsAPI(
                                                  categoryId: 0);
                                          showScaffold(
                                            context: context,
                                            message: '${value["message"]}',
                                          );

                                          gridSelectionProvider
                                              .setProductIDForAdding(
                                                  value["product_id"]);
                                          Navigator.pop(context);
                                          productBarcodeController.clear();
                                          productNameController.clear();
                                          productSlugController.clear();
                                          productPriceController.clear();
                                          widget.navigateToScreen(1);
                                        } else {
                                          // debugPrint("errors.password !=null");
                                          Navigator.pop(context);
                                          showScaffold(
                                            context: context,
                                            message: '${value["message"]}',
                                          );
                                          sideBarController.index.value = 14;
                                        }
                                      });
                                    }
                                  }
                                },
                                height: 50,
                                width: size.width * 0.19,
                                fontSize: FontSize.s12,
                              ),
                            ),
                            // Padding(
                            //   padding: const EdgeInsets.only(left: 10.0),
                            //   child: CustomRoundButton(
                            //     title: "Next",
                            //     boxColor: Colors.white,
                            //     textColor: ColorManager.kPrimaryColor,
                            //     fct: () async {
                            //       widget.navigateToScreen(1);
                            //       //  sideBarController.index.value = 14;
                            //     },
                            //     height: 50,
                            //     width: size.width * 0.19,
                            //     fontSize: FontSize.s12,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
