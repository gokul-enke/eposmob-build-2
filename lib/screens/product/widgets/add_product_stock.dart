import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:get/get.dart';
import 'package:multi_select_flutter/chip_display/multi_select_chip_display.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/tax.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../components/build_title.dart';
import '../../../controllers/sidebar_controller.dart';

import '../../../models/category_list.dart';
import '../../../models/get_product.dart';

import '../../../models/get_store.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/grid_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class AddProductStockScreen extends StatefulWidget {
  const AddProductStockScreen({super.key});

  @override
  State<AddProductStockScreen> createState() => _AddProductStockScreenState();
}

class _AddProductStockScreenState extends State<AddProductStockScreen> {
  final TextEditingController productPriceController = TextEditingController();
  final TextEditingController productAvailabeStockController =
      TextEditingController();
  final TextEditingController productCurrencyController =
      TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController purchaseController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController wholeSalePriceController =
      TextEditingController();
  final TextEditingController wholeSalePriceMinUnitController =
      TextEditingController();
  final TextEditingController expirydateUnitController =
      TextEditingController(text: DateTime.now().toString());
  final TextEditingController unitBatchController = TextEditingController();
  final TextEditingController taxRateController = TextEditingController();
  final TextEditingController taxAmountController = TextEditingController();
  final TextEditingController retailPriceWithOutTaxController =
      TextEditingController();
  final TextEditingController wholesalePriceWithOutTaxController =
      TextEditingController();

  final TextEditingController productSlugController = TextEditingController();
  final TextEditingController idController = TextEditingController(text: "0");
  final TextEditingController categoryIDController =
      TextEditingController(text: "0");

  String? parentCategory;
  String? productId;

  GetStoreModelData? storeSelected;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  SideBarController sideBarController = Get.put(SideBarController());
  List<String> property = [
    'Choose Unit',
    'KG',
    'PK',
    "DZ",
    "LT",
  ];
  String? selectedUnit;
  // Track the selected unit
  GetProduct? selectedValue;
  String? selected;
  Category? selectedValueCategory;
  final TextEditingController textEditingController = TextEditingController();

  Map<String, dynamic> apiBodyData = {};
  Map<String, List<String>> productPropData = {};
  Map<String, String> productPropStockApplicable = {};
  Map<String, int> productPropIds = {};
  Map<String, bool> stockApplicableMap = {};
  String? selectedProperty;

  void _getCategoryProperty(categoryId) {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    debugPrint("category id $categoryId");
    if (categoryId != null) {
      debugPrint("category id $categoryId");
      Provider.of<CategoryProvider>(context, listen: false)
          .fetchPropValues(categoryId: 1, accessToken: accessToken ?? "");
    } else {
      debugPrint("Category ID is null");
    }
  }

  Future<void> _updateTaxFields({
    required String taxOption,
  }) async {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    // Define values based on the selected tax option
    if (taxOption == 'includingTax') {
      final result = await getCategoryTax(
        accessToken: accessToken ?? "",
        taxInclude: 'Y',
        categoryId: parentCategory ?? "",
        productId: productId.toString(),
        retailPrice: retailPriceController.text,
      );

      debugPrint(result.toString());
      taxRateController.text =
          result.taxRate.toString(); // Example value for including tax
      taxAmountController.text = AmountHelper.formatAmount(result.taxAmount)
          .toString(); // Example value for including tax
      retailPriceWithOutTaxController.text =
          AmountHelper.formatAmount(result.retailPrice)
              .toString(); // Example value for including tax
      // retailPriceController.text = result.retailPrice.toString();
      double wholesalePrice = double.parse(wholeSalePriceController.text);
      wholesalePriceWithOutTaxController.text =
          AmountHelper.formatAmount((wholesalePrice - result.taxAmount))
              .toString();
      // wholeSalePriceController.text =
      //     AmountHelper.formatAmount((wholesalePrice - result.taxAmount))
      // .toString();
    } else if (taxOption == 'excludingTax') {
      final result = await getCategoryTax(
        accessToken: accessToken ?? "",
        taxInclude: 'N',
        categoryId: parentCategory ?? "",
        productId: productId.toString(),
        retailPrice: retailPriceController.text,
      );

      debugPrint(result.toString());
      taxRateController.text =
          result.taxRate.toString(); // Example value for including tax
      taxAmountController.text = AmountHelper.formatAmount(result.taxAmount)
          .toString(); // Example value for including tax
      retailPriceWithOutTaxController.text =
          AmountHelper.formatAmount(result.retailPrice)
              .toString(); // Example value for including tax
      retailPriceController.text = result.retailPrice.toString();
      double wholesalePrice = double.parse(wholeSalePriceController.text);
      wholesalePriceWithOutTaxController.text =
          AmountHelper.formatAmount((wholesalePrice + result.taxAmount))
              .toString();
      wholeSalePriceController.text =
          AmountHelper.formatAmount((wholesalePrice + result.taxAmount))
              .toString();
    }
  }

  Future<void> fetchStockInfo(BuildContext context, String productId) async {
    final String apiUrl =
        'https://epos.enke.in/api/product/stock-info?product_id=$productId';
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    try {
      final response = await http.get(Uri.parse(apiUrl), headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the JSON
        final Map<String, dynamic> data = json.decode(response.body);

        // Print the fetched data
        print('Stock Info:');
        print(json.encode(data)); // This will print the entire JSON response

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Stock info fetched successfully')),
        // );
      } else {
        // If the server did not return a 200 OK response, throw an exception
        throw Exception('Failed to load stock info');
      }
    } catch (e) {
      print('Error fetching stock info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching stock info')),
      );
    }
  }

  String? _selectedTaxOption;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    Map<String, String>? unitList = purchaseProvider.getUnitList;
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;
    // Access the CategoryProvider
    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    // Access the CategoryProvider
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(
      context,
    );

    // Access the category list

    List<GetProduct>? productList =
        gridSelectionProvider.getCategoryProductList;

    // Access the category list
    List<Category>? categoryList = categoryProvider.category;

    return SafeArea(
      child: Container(
          height: size.height,
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
          child: Padding(
            padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: () {
                      sideBarController.index.value = 15;
                    },
                    text: 'All Stocks',
                    // Optionally, you can customize the color and size
                    // color: ColorManager.customColor,
                    // size: 20.0,
                  ),
                  Text(
                    'Product Stock',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
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
                                  BuildTextTile(
                                    title: "Product Primary Details",
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black,
                                    ),
                                  ),
                                  const Divider(
                                    thickness: 0.5,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            margin: const EdgeInsets.only(
                                              left: 15,
                                            ),
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            height: size.height * .07,
                                            width: size.width / 3,
                                            child: DropdownButtonFormField<
                                                Category>(
                                              decoration: const InputDecoration(
                                                border: InputBorder
                                                    .none, // Remove the underline
                                              ),
                                              value: categoryProvider
                                                          .selectedCategoryIndex >=
                                                      0
                                                  ? categoryList![
                                                      categoryProvider
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
                                                    return DropdownMenuItem<
                                                            Category>(
                                                        value: category,
                                                        child: category
                                                                    .categoryName ==
                                                                "ALL"
                                                            ? Text(
                                                                ' Please Select',
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s12,
                                                                  0.27,
                                                                  ColorManager
                                                                      .textColor
                                                                      .withOpacity(
                                                                          .5),
                                                                ),
                                                              )
                                                            : Text(
                                                                category.categoryName ??
                                                                    '',
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s12,
                                                                  0.27,
                                                                  ColorManager
                                                                      .textColor
                                                                      .withOpacity(
                                                                          .5),
                                                                ),
                                                              ));
                                                  })
                                                  .toSet()
                                                  .toList(),
                                              onChanged: (Category?
                                                  selectedCategory) async {
                                                if (selectedCategory != null) {
                                                  // Update the selected category in the provider
                                                  categoryProvider
                                                      .selectCategory(
                                                    categoryList.indexOf(
                                                        selectedCategory),
                                                    selectedCategory
                                                            .categoryName ??
                                                        '',
                                                    selectedCategory
                                                            .productsCount ??
                                                        0,
                                                  );

                                                  gridSelectionProvider
                                                      .updateCategory(
                                                          selectedCategory
                                                                  .categoryId ??
                                                              0);
                                                  await gridSelectionProvider
                                                      .listAllProducts(
                                                          filterCategory:
                                                              selectedCategory
                                                                  .categoryId
                                                                  .toString());
                                                  setState(() {
                                                    parentCategory =
                                                        "${selectedCategory.categoryId ?? 0}";
                                                    debugPrint(parentCategory);

                                                    productList =
                                                        gridSelectionProvider
                                                            .getCategoryProductList;
                                                  });

                                                  // debugPrint(
                                                  //     "hhhh ${gridSelectionProvider.selectedProductsUpOnCategory}");

                                                  await categoryProvider
                                                      .setParentCategory(
                                                          "${selectedCategory.categoryId ?? 0}");

                                                  await categoryProvider
                                                      .setCategoryIdforProp(
                                                          categoryId:
                                                              selectedCategory
                                                                  .categoryId!);
                                                  _getCategoryProperty(
                                                      selectedCategory
                                                          .categoryId);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          BuildTextTile(
                                            isStarRed: true,
                                            isTextField: true,
                                            title: "Select Product ",
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
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            height: size.height * .07,
                                            width: size.width / 3,
                                            child: DropdownButtonHideUnderline(
                                              child:
                                                  DropdownButton2<GetProduct>(
                                                isExpanded: true,
                                                hint: Text(
                                                  '--Select--',
                                                  style: buildCustomStyle(
                                                    FontWeightManager.regular,
                                                    FontSize.s14,
                                                    0.27,
                                                    Colors.black
                                                        .withOpacity(0.6),
                                                  ),
                                                ),
                                                items: productList!
                                                    .map((item) =>
                                                        DropdownMenuItem(
                                                            value: item,
                                                            child: Text(
                                                              item.productName ??
                                                                  "",
                                                              style:
                                                                  buildCustomStyle(
                                                                FontWeightManager
                                                                    .regular,
                                                                FontSize.s14,
                                                                0.27,
                                                                Colors.black
                                                                    .withOpacity(
                                                                        0.6),
                                                              ),
                                                            )))
                                                    .toList(),
                                                value: selectedValue,
                                                onChanged: (value) {
                                                  debugPrint(
                                                      "${value?.productProps.toString()}");
                                                  setState(() {
                                                    selectedValue = value;
                                                    productId = value!.productId
                                                        .toString();
                                                  });
                                                  idController.text = value ==
                                                          null
                                                      ? ""
                                                      : "${value.productId ?? 0}";
                                                  debugPrint(idController.text);
                                                  ProductPrice? price =
                                                      value?.price;
                                                  productAvailabeStockController.text =
                                                      value == null
                                                          ? ""
                                                          : value.numberOfProductsAvailble!
                                                                  .isEmpty
                                                              ? "0"
                                                              : value.numberOfProductsAvailble ??
                                                                  "0";

                                                  productCurrencyController
                                                      .text = value ==
                                                          null
                                                      ? ""
                                                      : value.currency ?? "";
                                                  productSlugController.text =
                                                      value == null
                                                          ? ""
                                                          : value.productSlug ??
                                                              "";
                                                  productPriceController
                                                      .text = value ==
                                                          null
                                                      ? ""
                                                      : "${price == null ? 0 : price.price ?? 0}";

                                                  fetchStockInfo(
                                                      context,
                                                      value!.productId
                                                          .toString());
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: size.height * .07,
                                                  width: size.width / 3, //3.05,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                    // border: Border.all(
                                                    //   color: Colors.grey.withOpacity(0.4),
                                                    // ),
                                                    color: Colors.white,
                                                  ),
                                                  //  elevation: 1,
                                                ),
                                                dropdownStyleData:
                                                    const DropdownStyleData(
                                                  maxHeight: 300,
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                ),
                                                dropdownSearchData:
                                                    DropdownSearchData(
                                                  searchController:
                                                      textEditingController,
                                                  searchInnerWidgetHeight: 50,
                                                  searchInnerWidget: Container(
                                                    height: 50,
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 8,
                                                      bottom: 4,
                                                      right: 8,
                                                      left: 8,
                                                    ),
                                                    child: TextFormField(
                                                      expands: true,
                                                      maxLines: null,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .regular,
                                                        FontSize.s14,
                                                        0.27,
                                                        Colors.black
                                                            .withOpacity(0.6),
                                                      ),
                                                      controller:
                                                          textEditingController,
                                                      cursorColor: ColorManager
                                                          .kPrimaryColor,
                                                      decoration:
                                                          decoration.copyWith(
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                        hintText: '',
                                                        hintStyle:
                                                            buildCustomStyle(
                                                          FontWeightManager
                                                              .regular,
                                                          FontSize.s14,
                                                          0.27,
                                                          Colors.black
                                                              .withOpacity(0.6),
                                                        ),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(7),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  searchMatchFn:
                                                      (item, searchValue) {
                                                    return item
                                                        .value!.productName
                                                        .toString()
                                                        .toLowerCase()
                                                        .contains(searchValue
                                                            .toLowerCase());
                                                  },
                                                ),
                                                //This to clear the search value when you close the menu
                                                onMenuStateChange: (isOpen) {
                                                  if (!isOpen) {
                                                    textEditingController
                                                        .clear();
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      BuildTextFieldColumn(
                                          isLeft: true,
                                          size: size,
                                          isStarRed: true,
                                          isTextField: true,
                                          controller: productSlugController,
                                          title: "Slug"),
                                      BuildTextFieldColumn(
                                          isLeft: false,
                                          size: size,
                                          isStarRed: true,
                                          isTextField: true,
                                          controller: productPriceController,
                                          title: "Product Price"),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      BuildTextFieldColumn(
                                          isLeft: true,
                                          isStarRed: true,
                                          isTextField: true,
                                          size: size,
                                          hintText: 'Enter...',
                                          controller: productCurrencyController,
                                          title: "Currency"),
                                      BuildTextFieldColumn(
                                          isLeft: false,
                                          size: size,
                                          isStarRed: true,
                                          isTextField: true,
                                          controller:
                                              productAvailabeStockController,
                                          title: "Product Available Stock"),
                                    ],
                                  ),
                                  BuildTextTile(
                                    title: "Product Stock Details",
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black,
                                    ),
                                  ),
                                  const Divider(
                                    thickness: 0.5,
                                  ),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          BuildTextTile(
                                            isStarRed: true,
                                            isTextField: true,
                                            title: "Select Store",
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
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            height: size.height * .07,
                                            width: size.width / 4.5,
                                            child: DropdownButtonFormField<
                                                GetStoreModelData>(
                                              decoration: const InputDecoration(
                                                border: InputBorder
                                                    .none, // Remove the underline
                                              ),
                                              value: storeSelected,
                                              hint: Text(
                                                'Select Store',
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                              items: storeList!.map(
                                                  (GetStoreModelData store) {
                                                return DropdownMenuItem<
                                                        GetStoreModelData>(
                                                    value: store,
                                                    child: Text(
                                                      store.name ?? '',
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s12,
                                                        0.27,
                                                        ColorManager.textColor
                                                            .withOpacity(.5),
                                                      ),
                                                    ));
                                              }).toList(),
                                              onChanged: (GetStoreModelData?
                                                  storeModelData) {
                                                if (storeModelData != null) {
                                                  // Update the selected category in the provider
                                                  setState(() {
                                                    storeSelected =
                                                        storeModelData;
                                                    storeController.text =
                                                        "${storeModelData.id ?? 1}";
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      BuildTextFieldColumn3(
                                          isLeft: true,
                                          isStarRed: true,
                                          isTextField: true,
                                          isRead: false,
                                          textInputType: TextInputType.number,
                                          size: size,
                                          hintText: 'Quantity',
                                          controller: quantityController,
                                          title: "Quantity"),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            margin:
                                                const EdgeInsets.only(left: 20),
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            height: size.height * .07,
                                            width: size.width / 4.5,
                                            child:
                                                DropdownButtonFormField<String>(
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
                                              icon: const Icon(
                                                  Icons.arrow_drop_down),
                                              iconSize: 24,
                                              elevation: 16,
                                              onChanged: (String? newValue) {
                                                selectedUnit = newValue!;
                                              },
                                              items: unitList!.entries
                                                  .map((entry) {
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
                                      BuildTextFieldColumn3(
                                          isLeft: false,
                                          isStarRed: true,
                                          isTextField: true,
                                          size: size,
                                          isRead: false,
                                          textInputType: TextInputType.number,
                                          hintText: 'Purchase Rate',
                                          controller: purchaseController,
                                          title: "Purchase Rate"),

                                      BuildTextFieldColumn3(
                                          isLeft: true,
                                          size: size,
                                          isStarRed: true,
                                          hintText: "Retail Price",
                                          isTextField: true,
                                          isRead: false,
                                          textInputType: TextInputType.number,
                                          controller: retailPriceController,
                                          title: "Retail Price"),

                                      // BuildTextFieldColumn3(isDouble:true
                                      //     isDoubleHintText:
                                      //         "Wholesale Min Unit",
                                      //     isDoubleontroller:
                                      //         wholeSalePriceMinUnitController,
                                      //     isLeft: true,
                                      //     isStarRed: true,
                                      //     isTextField: true,
                                      //     size: size,
                                      //     hintText: 'Wholesale Price',
                                      //     controller: wholeSalePriceController,
                                      //     title: "Wholesale Price"),
                                      BuildTextFieldColumn3(
                                          isLeft: true,
                                          size: size,
                                          isStarRed: true,
                                          hintText: "Wholesale Price",
                                          isTextField: true,
                                          isRead: false,
                                          textInputType: TextInputType.number,
                                          controller: wholeSalePriceController,
                                          title: "Wholesale Price"),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // BuildTextFieldColumn3(
                                      //     isLeft: false,
                                      //     size: size,
                                      //     isStarRed: true,
                                      //     hintText: "Unit",
                                      //     isTextField: true,
                                      //     controller: unitController,
                                      //     title: "Unit"),
                                      BuildTextFieldColumn3(
                                          isLeft: false,
                                          isStarRed: true,
                                          isTextField: true,
                                          size: size,
                                          isRead: false,
                                          textInputType: TextInputType.number,
                                          hintText: 'Wholesale Min Unit',
                                          controller:
                                              wholeSalePriceMinUnitController,
                                          title: "Wholesale Min Unit"),
                                      BuildTextFieldColumn3(
                                          isDatePicker: true,
                                          isLeft: true,
                                          isStarRed: true,
                                          isTextField: true,
                                          size: size,
                                          isRead: true,
                                          hintText: 'Expiry Date',
                                          controller: expirydateUnitController,
                                          title: "Expiry Date"),
                                      BuildTextFieldColumn3(
                                          isLeft: true,
                                          isStarRed: false,
                                          isTextField: true,
                                          size: size,
                                          isRead: false,
                                          textInputType: TextInputType.number,
                                          hintText: 'Batch Number',
                                          controller: unitBatchController,
                                          title: "Batch Number"),
                                    ],
                                  ),
                                  BuildTextTile(
                                    title: "Tax Details",
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black,
                                    ),
                                  ),
                                  const Divider(
                                    thickness: 0.5,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      SizedBox(
                                        // height: size.height * .07,
                                        width: 200,
                                        child: Column(
                                          // mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RadioListTile<String>(
                                              value: 'includingTax',
                                              groupValue: _selectedTaxOption,
                                              contentPadding: EdgeInsets
                                                  .zero, // Remove default padding
                                              title:
                                                  const Text('Including Tax'),
                                              onChanged: (String? value) {
                                                setState(() {
                                                  _selectedTaxOption = value;
                                                });
                                                _updateTaxFields(
                                                  taxOption: value!,
                                                );
                                              },
                                            ),
                                            RadioListTile<String>(
                                              value: 'excludingTax',
                                              groupValue: _selectedTaxOption,
                                              contentPadding: EdgeInsets
                                                  .zero, // Remove default padding
                                              title:
                                                  const Text('Excluding Tax'),
                                              onChanged: (String? value) {
                                                setState(() {
                                                  _selectedTaxOption = value;
                                                });
                                                _updateTaxFields(
                                                  taxOption: value!,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      BuildTextFieldColumn3(
                                          isLeft: true,
                                          isStarRed: false,
                                          isTextField: true,
                                          size: size,
                                          isRead: true,
                                          textInputType: TextInputType.number,
                                          hintText: 'Tax Rate',
                                          controller: taxRateController,
                                          title: "Tax Rate"),
                                      BuildTextFieldColumn3(
                                          isLeft: false,
                                          isStarRed: false,
                                          isTextField: true,
                                          size: size,
                                          isRead: true,
                                          textInputType: TextInputType.number,
                                          hintText: 'Tax Amount',
                                          controller: taxAmountController,
                                          title: "Tax Amount"),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      BuildTextFieldColumn(
                                        isLeft: false,
                                        size: size,
                                        isStarRed: false,
                                        isTextField: true,
                                        controller:
                                            retailPriceWithOutTaxController,
                                        title: "Retail Price without Tax",
                                        hintText: "Retail Price without Tax",
                                      ),
                                      BuildTextFieldColumn(
                                        isLeft: false,
                                        size: size,
                                        isStarRed: false,
                                        isTextField: true,
                                        controller:
                                            wholesalePriceWithOutTaxController,
                                        title: "Wholesale Price without Tax",
                                        hintText: "Wholesale Price without Tax",
                                      ),
                                    ],
                                  ),
                                  BuildTextTile(
                                    title: "Product Properties",
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black,
                                    ),
                                  ),
                                  const Divider(
                                    thickness: 0.5,
                                  ),
                                  if (selectedValue != null)
                                    SizedBox(
                                      height: size.height * 0.18,
                                      child: ListView.builder(
                                        itemCount:
                                            selectedValue!.productProps!.length,
                                        itemBuilder: (context, index) {
                                          final property = selectedValue!
                                              .productProps![index];
                                          final masterValue =
                                              property.masterValue!;
                                          final propType = property.type!;
                                          final propsCode = property.propsCode!;
                                          final propsLabel = property.label!;
                                          final propsStock =
                                              property.stockApplicable;
                                          if (propsStock == "Y") {
                                            if (propType == "TXT") {
                                              productPropData[propsCode] = [
                                                masterValue
                                              ];
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  BuildTextTile(
                                                    title: propsLabel,
                                                    isStarRed: true,
                                                    isTextField: true,
                                                    textStyle: buildCustomStyle(
                                                      FontWeightManager.regular,
                                                      FontSize.s14,
                                                      0.27,
                                                      Colors.black
                                                          .withOpacity(0.6),
                                                    ),
                                                  ),
                                                  BuildBoxShadowContainer(
                                                    circleRadius: 7,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 2),
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 15),
                                                    height: size.height * .07,
                                                    width: size.width / 3,
                                                    child: TextFormField(
                                                      initialValue: masterValue,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          apiBodyData[
                                                                  propsCode] =
                                                              value;
                                                          productPropData[
                                                              propsCode] = [
                                                            value
                                                          ];
                                                        });
                                                      },
                                                      keyboardType:
                                                          TextInputType.text,
                                                      cursorColor: ColorManager
                                                          .kPrimaryColor,
                                                      decoration:
                                                          InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        hintText:
                                                            'Enter $propsLabel',
                                                        hintStyle:
                                                            buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s12,
                                                          0.27,
                                                          ColorManager.textColor
                                                              .withOpacity(.5),
                                                        ),
                                                      ),
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s12,
                                                        0.27,
                                                        ColorManager.textColor
                                                            .withOpacity(.5),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            } else {
                                              final items = List<String>.from(
                                                  masterValue.split(','));
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  BuildTextTile(
                                                    title: propsLabel,
                                                    isStarRed: true,
                                                    isTextField: true,
                                                    textStyle: buildCustomStyle(
                                                      FontWeightManager.regular,
                                                      FontSize.s14,
                                                      0.27,
                                                      Colors.black
                                                          .withOpacity(0.6),
                                                    ),
                                                  ),
                                                  BuildBoxShadowContainer(
                                                    circleRadius: 7,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 0),
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 15),
                                                    width: size.width / 3,
                                                    child:
                                                        MultiSelectDialogField(
                                                      items: items
                                                          .map((item) =>
                                                              MultiSelectItem<
                                                                      String>(
                                                                  item, item))
                                                          .toList(),
                                                      title: Text(
                                                          "Choose $propsLabel"),
                                                      selectedColor:
                                                          ColorManager
                                                              .kPrimaryColor,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            const BorderRadius
                                                                .all(
                                                                Radius.circular(
                                                                    10)),
                                                        border: Border.all(
                                                          color: Colors
                                                              .transparent, // Transparent border
                                                        ),
                                                      ),
                                                      buttonIcon: const Icon(
                                                        Icons.arrow_drop_down,
                                                        color: Colors.grey,
                                                      ),
                                                      buttonText: Text(
                                                        "Choose $propsLabel",
                                                        // "",
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[700],
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      onConfirm: (results) {
                                                        setState(() {
                                                          selectedProperty =
                                                              results
                                                                  .join(', ');
                                                          apiBodyData[
                                                                  propsCode] =
                                                              results;
                                                          productPropData[
                                                                  propsCode] =
                                                              List<String>.from(
                                                                  results);
                                                        });
                                                      },
                                                      chipDisplay:
                                                          MultiSelectChipDisplay(
                                                        onTap: (value) {
                                                          setState(() {
                                                            apiBodyData[
                                                                    '$propsCode']
                                                                .remove(value);
                                                            productPropData[
                                                                    propsCode]
                                                                ?.remove(value);
                                                            if (apiBodyData[
                                                                    '$propsCode']
                                                                .isEmpty) {
                                                              apiBodyData.remove(
                                                                  '$propsCode');
                                                              productPropData
                                                                  .remove(
                                                                      propsCode);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 25),
                                  Row(
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 10.0),
                                        child: CustomRoundButton(
                                          title: "Submit",
                                          fct: () async {
                                            debugPrint(
                                                expirydateUnitController.text);
                                            idController.text = categoryProvider
                                                .getParentCategory;
                                            debugPrint(
                                                "categoryIdController.text ${idController.text}");
                                            if (formKey.currentState!
                                                .validate()) {
                                              formKey.currentState!.save();
                                              debugPrint("submit");
                                              debugPrint(
                                                  "categoryIdController.text ${idController.text}");
                                              // debugPrint(
                                              //     "categoryNameArabicController.text ${categoryNameArabicController.text}");

                                              if (idController.text.isEmpty ||
                                                  productAvailabeStockController
                                                      .text.isEmpty ||
                                                  productPriceController
                                                      .text.isEmpty ||
                                                  productCurrencyController
                                                      .text.isEmpty ||
                                                  productSlugController
                                                      .text.isEmpty ||
                                                  selectedUnit == null ||
                                                  storeSelected == null ||
                                                  productSlugController
                                                      .text.isEmpty ||
                                                  storeController
                                                      .text.isEmpty ||
                                                  purchaseController
                                                      .text.isEmpty ||
                                                  quantityController
                                                      .text.isEmpty ||
                                                  expirydateUnitController
                                                      .text.isEmpty ||
                                                  retailPriceController
                                                      .text.isEmpty ||
                                                  wholeSalePriceController
                                                      .text.isEmpty ||
                                                  wholeSalePriceMinUnitController
                                                      .text.isEmpty) {
                                                debugPrint(
                                                    "isEmptycategorySlugController");

                                                showScaffold(
                                                  context: context,
                                                  message:
                                                      'Please Fill the Required Fields',
                                                );
                                              } else {
                                                debugPrint(
                                                    "categoryIdController ${categoryIDController.text}");
                                                showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (context) {
                                                      return const Center(
                                                        child:
                                                            CircularProgressIndicator
                                                                .adaptive(),
                                                      );
                                                    });

                                                String? accessToken =
                                                    Provider.of<AuthModel>(
                                                            context,
                                                            listen: false)
                                                        .token;
                                                debugPrint(
                                                    "accessToken From AuthModel $accessToken");

                                                gridSelectionProvider
                                                    .addProductStockAPI(
                                                  unit: selectedUnit ?? '',
                                                  storeId: storeController.text,
                                                  quantity:
                                                      quantityController.text,
                                                  retailPrice:
                                                      retailPriceController
                                                          .text,
                                                  expiryDate:
                                                      expirydateUnitController
                                                          .text,
                                                  batchNumber:
                                                      unitBatchController.text,
                                                  purchaseRate:
                                                      purchaseController.text,
                                                  wholesaleMinUnit:
                                                      wholeSalePriceMinUnitController
                                                          .text,
                                                  wholesalePrice:
                                                      wholeSalePriceController
                                                          .text,
                                                  accessToken:
                                                      accessToken ?? "",
                                                  productId:
                                                      "${selectedValue!.productId ?? ""}",
                                                  productProperties:
                                                      formatProductProperties(),
                                                )
                                                    .then((value) {
                                                  if (value["status"] ==
                                                      "success") {
                                                    showScaffold(
                                                      context: context,
                                                      message:
                                                          '${value["message"]}',
                                                    );
                                                    Navigator.pop(context);
                                                    sideBarController
                                                        .index.value = 15;
                                                  } else {
                                                    debugPrint(
                                                        "errors.password !=null");
                                                    Navigator.pop(context);
                                                    showScaffold(
                                                      context: context,
                                                      message:
                                                          '${value["message"]}',
                                                    );
                                                    sideBarController
                                                        .index.value = 15;
                                                  }
                                                });
                                                //  Get.put(CategoryProvider());
                                              }
                                            }
                                          },
                                          height: 50,
                                          width: size.width * 0.19,
                                          fontSize: FontSize.s12,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 10.0),
                                        child: CustomRoundButton(
                                          title: "Back",
                                          boxColor: Colors.white,
                                          textColor: ColorManager.kPrimaryColor,
                                          fct: () async {
                                            sideBarController.index.value = 15;
                                          },
                                          height: 50,
                                          width: size.width * 0.19,
                                          fontSize: FontSize.s12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 200),
                                ])),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )),
    );
  }

  List<Map<String, dynamic>> formatProductProperties() {
    List<Map<String, dynamic>> formattedProperties = [];

    productPropData.forEach((propCode, values) {
      ProductProp? prop = selectedValue?.productProps?.firstWhere(
        (p) => p.propsCode == propCode,
        // orElse: () => null,
      );

      if (prop != null && prop.stockApplicable == "Y") {
        formattedProperties.add({
          "prop_id": prop.propsId?.toString() ?? "",
          "prop_code": propCode,
          "prop_value": values.join(','),
        });
      }
    });

    return formattedProperties;
  }
}
