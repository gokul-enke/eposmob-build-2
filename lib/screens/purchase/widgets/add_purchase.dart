import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

import 'package:pos_machine/providers/purchase_provider.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../components/build_title.dart';
import '../../../controllers/sidebar_controller.dart';

import '../../../models/category_list.dart';
import '../../../models/get_product.dart';

import '../../../models/get_store.dart'; 
import '../../../models/get_suppliers.dart';
import '../../../models/list_purchase.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';

import '../../../providers/auth_model.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/grid_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  int quantity = 0;
  bool initLoading = false;
  bool apiLoading = false;
  List<PurchaseItem>? purchaseItemList = [];
  final TextEditingController supplierIdController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();

  final TextEditingController categoryIDController =
      TextEditingController(text: "0");
  final TextEditingController productIDController =
      TextEditingController(text: "0");
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  SideBarController sideBarController = Get.put(SideBarController());
  int? purchaseId;

  // List<String> property = [
  //   'Choose Unit',
  //   'KG',
  //   'PK',
  //   "DZ",
  //   "LT",
  // ];

  // Track the selected unit
  String? selectedProperty;
  // List<String> store = [
  //   'Select Store',
  //   'Day Mart',
  // ];

  // Track the selected unit
  // String? selectedStore;
  // List<String> supplier = [
  //   'Select Supplier ',
  //   'Supplier',
  // ];

  // Track the selected unit
  String? selectedSupplier;
  int batchNumber = 0;
  GetProduct? selectedValue;
  Category? selectedValueCategory;
  String? selected;
  final TextEditingController textEditingController = TextEditingController();
  List<GetStoreModelData>? storeList;
  List<GetSuppliersModelData>? supplierList = [];
  @override
  void initState() {
    super.initState();
    loadData();
  }

  loadData() async {
    setState(() {
      initLoading = true;
    });
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    // await purchaseProvider
    //     .listAllSuppliers(accessToken ?? '', null)
    //     .then((value) async {
    //   await purchaseProvider
    //       .listAllStores(accessToken ?? '', null)
    //       .then((value) {
    setState(() {
      storeList = purchaseProvider.getStoreList ?? [];
      supplierList = purchaseProvider.getSupplierList ?? [];
    });
    //  });
    await purchaseProvider
        .listAllPurchaseItems(accessToken ?? "")
        .then((value) {});
    purchaseItemList = purchaseProvider.purchaseItems;
    for (var v in purchaseItemList ?? []) {
      // debugPrint("Porchase Id ${v.purchaseId}");
      purchaseId = v.purchaseId;
    }
    //  });

    setState(() {
      initLoading = false;
    });
  }

  getPurchaseItems() async {
    setState(() {
      apiLoading = true;
    });
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);

    await purchaseProvider
        .listAllPurchaseItems(accessToken ?? "")
        .then((value) {
      if (value["status"] == "success") {
        ListPurchaseItemModel listPurchaseItemModel =
            ListPurchaseItemModel.fromJson(value);
        listPurchaseItemModel.data != null ||
                listPurchaseItemModel.data!.isNotEmpty
            ? listPurchaseItemModel.data!.map((e) => purchaseId = e.purchaseId)
            : () {};
        for (var v in listPurchaseItemModel.data!) {
          // debugPrint("Porchase Id ${v.purchaseId}");
          purchaseId = v.purchaseId;
        }
        // debugPrint("Porchase Id $purchaseId");
      }
    });
    purchaseItemList = purchaseProvider.purchaseItems;

    setState(() {
      apiLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    if (!canViewPurchasePrice(context)) {
      return SafeArea(
        child: Center(
          child: Text('add_purchase.permission_required'.tr),
        ),
      );
    }

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint('zcccdcdc$accessToken');
    // Access the CategoryProvider
    CategoryProvider categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // Access the ProductProvider
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    GetSuppliersModelData? supplier;
    GetStoreModelData? storeSelected;
    List<Category>? categoryList = categoryProvider.category;
    List<GetProduct>? productList =
        gridSelectionProvider.getCategoryProductList;
    Map<String, String>? unitList = purchaseProvider.getUnitList;
    return SafeArea(
      child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: () {
                      sideBarController.index.value = 19;
                    },
                    text: 'add_purchase.all_purchases'.tr,
                    // Optionally, you can customize the color and size
                    // color: ColorManager.customColor,
                    // size: 20.0,
                  ),
                  Text(
                    'add_purchase.create_new_purchase'.tr,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SizedBox(
                    height: size.height * 0.8,
                    width: double.infinity,
                    child: initLoading
                        ? const Center(
                            child: CircularProgressIndicator.adaptive())
                        : BuildBoxShadowContainer(
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
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: size.height * .17,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              BuildTextTile(
                                                isStarRed: true,
                                                isTextField: true,
                                                title: 'add_purchase.select_category'.tr,
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
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 0),
                                                padding: const EdgeInsets.only(
                                                    left: 15),
                                                height: size.height * .07,
                                                width: size.width / 3,
                                                child:
                                                    DropdownButtonHideUnderline(
                                                  child:
                                                      DropdownButton2<Category>(
                                                    isExpanded: true,
                                                    hint: Text(
                                                      'add_purchase.select_hint'.tr,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .regular,
                                                        FontSize.s14,
                                                        0.27,
                                                        Colors.black
                                                            .withOpacity(0.6),
                                                      ),
                                                    ),
                                                    items: categoryList!
                                                        .map((item) =>
                                                            DropdownMenuItem(
                                                                value: item,
                                                                child: Text(
                                                                  item.categoryName ??
                                                                      "",
                                                                  style:
                                                                      buildCustomStyle(
                                                                    FontWeightManager
                                                                        .regular,
                                                                    FontSize
                                                                        .s14,
                                                                    0.27,
                                                                    Colors.black
                                                                        .withOpacity(
                                                                            0.6),
                                                                  ),
                                                                )))
                                                        .toList(),
                                                    value:
                                                        selectedValueCategory,
                                                    onChanged: (Category?
                                                        selectedCategory) async {
                                                      if (selectedCategory !=
                                                          null) {
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

                                                        setState(() {
                                                          productList =
                                                              gridSelectionProvider
                                                                  .selectedProductsUpOnCategory;
                                                        });

                                                        await categoryProvider
                                                            .setParentCategory(
                                                                "${selectedCategory.categoryId ?? 0}");

                                                        setState(() {
                                                          selectedValueCategory =
                                                              selectedCategory;
                                                          categoryIDController
                                                                  .text =
                                                              "${selectedCategory.categoryId ?? 1}";
                                                        });
                                                      }
                                                    },
                                                    buttonStyleData:
                                                        ButtonStyleData(
                                                      height: size.height * .07,
                                                      width: size.width /
                                                          3, //3.05,
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 14,
                                                              right: 14),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(7),
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
                                                      searchInnerWidgetHeight:
                                                          50,
                                                      searchInnerWidget:
                                                          Container(
                                                        height: 50,
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          top: 8,
                                                          bottom: 4,
                                                          right: 8,
                                                          left: 8,
                                                        ),
                                                        child: TextFormField(
                                                          expands: true,
                                                          maxLines: null,
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
                                                          controller:
                                                              textEditingController,
                                                          cursorColor:
                                                              ColorManager
                                                                  .kPrimaryColor,
                                                          decoration: decoration
                                                              .copyWith(
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
                                                                  .withOpacity(
                                                                      0.6),
                                                            ),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          7),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      searchMatchFn:
                                                          (item, searchValue) {
                                                        return item
                                                            .value!.categoryName
                                                            .toString()
                                                            .toLowerCase()
                                                            .contains(searchValue
                                                                .toLowerCase());
                                                      },
                                                    ),
                                                    //This to clear the search value when you close the menu
                                                    onMenuStateChange:
                                                        (isOpen) {
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
                                        ),
                                        SizedBox(
                                          height: size.height * .17,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              BuildTextTile(
                                                isStarRed: true,
                                                isTextField: true,
                                                title: 'add_purchase.product_label'.tr,
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
                                                    left: 20),
                                                padding: const EdgeInsets.only(
                                                    left: 15),
                                                height: size.height * .07,
                                                width: size.width / 3,
                                                child:
                                                    DropdownButtonHideUnderline(
                                                  child: DropdownButton2<
                                                      GetProduct>(
                                                    isExpanded: true,
                                                    hint: Text(
                                                      'add_purchase.select_hint'.tr,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .regular,
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
                                                                    FontSize
                                                                        .s14,
                                                                    0.27,
                                                                    Colors.black
                                                                        .withOpacity(
                                                                            0.6),
                                                                  ),
                                                                )))
                                                        .toList(),
                                                    value: selectedValue,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        selectedValue = value;
                                                        if (value != null) {
                                                          productIDController
                                                                  .text =
                                                              "${value.productId ?? 1}";
                                                        }
                                                      });
                                                    },
                                                    buttonStyleData:
                                                        ButtonStyleData(
                                                      height: size.height * .07,
                                                      width: size.width /
                                                          3, //3.05,
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 14,
                                                              right: 14),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(7),
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
                                                      searchInnerWidgetHeight:
                                                          50,
                                                      searchInnerWidget:
                                                          Container(
                                                        height: 50,
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          top: 8,
                                                          bottom: 4,
                                                          right: 8,
                                                          left: 8,
                                                        ),
                                                        child: TextFormField(
                                                          expands: true,
                                                          maxLines: null,
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
                                                          controller:
                                                              textEditingController,
                                                          cursorColor:
                                                              ColorManager
                                                                  .kPrimaryColor,
                                                          decoration: decoration
                                                              .copyWith(
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
                                                                  .withOpacity(
                                                                      0.6),
                                                            ),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          7),
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
                                                    onMenuStateChange:
                                                        (isOpen) {
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
                                        ),
                                      ],
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
                                              title: 'add_purchase.quantity_label'.tr,
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
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 0),
                                              padding: const EdgeInsets.only(
                                                  left: 15),
                                              height: size.height * .07,
                                              width: size.width / 3,
                                              child: TextFormField(
                                                key: ValueKey<int>(quantity),
                                                initialValue:
                                                    quantity.toString(),
                                                // readOnly: true,
                                                keyboardType:
                                                    TextInputType.number,
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'add_purchase.field_required'.tr;
                                                  }
                                                  return null;
                                                },
                                                cursorColor:
                                                    ColorManager.kPrimaryColor,
                                                decoration: InputDecoration(
                                                  suffixIcon: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () {
                                                          debugPrint(
                                                              "quantity $quantity");
                                                          setState(() {
                                                            quantity++;
                                                          });
                                                        },
                                                        child: const Icon(
                                                          Icons
                                                              .keyboard_arrow_up,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          debugPrint(
                                                              "quantity $quantity");

                                                          if (quantity > 0) {
                                                            setState(() {
                                                              quantity--;
                                                            });
                                                          }
                                                        },
                                                        child: const Icon(
                                                          Icons
                                                              .keyboard_arrow_down,
                                                          size: 20,
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                  border: InputBorder.none,
                                                  //   hintText: 'Quantity',
                                                  hintStyle: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.27,
                                                    ColorManager.textColor
                                                        .withOpacity(.5),
                                                  ),
                                                ),
                                                // controller: TextEditingController(
                                                //     text: '$quantity'),
                                                onChanged: (value) {
                                                  setState(() {
                                                    quantity =
                                                        int.tryParse(value) ??
                                                            quantity;
                                                  });
                                                },
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // BuildDropDownStatic(
                                        //   selectedItem: selectedProperty,
                                        //   size: size,
                                        //   isLeft: true,
                                        //   isStarRed: true,
                                        //   isStar: true,
                                        //   items: property,
                                        //   hintText: 'Choose Unit',
                                        //   title: 'Unit',
                                        //   onChanged: (String? newValue) {
                                        //     selectedProperty = newValue!;
                                        //   },
                                        // ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BuildTextTile(
                                              isStarRed: true,
                                              isTextField: true,
                                              title: 'add_purchase.unit_label'.tr,
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
                                                  left: 20),
                                              padding: const EdgeInsets.only(
                                                  left: 15),
                                              height: size.height * .07,
                                              width: size.width / 3,
                                              child: DropdownButtonFormField<
                                                  String>(
                                                decoration:
                                                    const InputDecoration(
                                                  border: InputBorder
                                                      .none, // Remove the underline
                                                ),
                                                value: selectedProperty,
                                                hint: Text(
                                                  'add_purchase.choose_unit'.tr,
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.27,
                                                    ColorManager.textColor
                                                        .withOpacity(.5),
                                                  ),
                                                ),
                                                items: unitList!.entries
                                                    .map((entry) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: entry
                                                        .key, // Set the value for the dropdown item
                                                    child: Text(
                                                      entry.value,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s12,
                                                        0.27,
                                                        ColorManager.textColor
                                                            .withOpacity(.5),
                                                      ),
                                                    ), // Display the value as the dropdown item
                                                  );
                                                }).toList(),
                                                onChanged: (String? value) {
                                                  selectedProperty = value;
                                                  debugPrint(
                                                      "selected Unit $selectedProperty");
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BuildTextTile(
                                              isStarRed: false,
                                              isTextField: true,
                                              title: 'add_purchase.batch_number'.tr,
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
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 0),
                                              padding: const EdgeInsets.only(
                                                  left: 15),
                                              height: size.height * .07,
                                              width: size.width / 3,
                                              child: TextFormField(
                                                key: ValueKey<int>(batchNumber),
                                                initialValue:
                                                    batchNumber.toString(),
                                                //readOnly: true,
                                                keyboardType:
                                                    TextInputType.number,
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'add_purchase.field_required'.tr;
                                                  }
                                                  return null;
                                                },
                                                cursorColor:
                                                    ColorManager.kPrimaryColor,
                                                decoration: InputDecoration(
                                                  suffixIcon: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () {
                                                          debugPrint(
                                                              "quantity $batchNumber");
                                                          setState(() {
                                                            batchNumber++;
                                                          });
                                                        },
                                                        child: const Icon(
                                                          Icons
                                                              .keyboard_arrow_up,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          debugPrint(
                                                              "quantity $batchNumber");

                                                          setState(() {
                                                            batchNumber--;
                                                          });
                                                        },
                                                        child: const Icon(
                                                          Icons
                                                              .keyboard_arrow_down,
                                                          size: 20,
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                  border: InputBorder.none,
                                                  //   hintText: 'Quantity',
                                                  hintStyle: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.27,
                                                    ColorManager.textColor
                                                        .withOpacity(.5),
                                                  ),
                                                ),
                                                // controller: TextEditingController(
                                                //     text: '$quantity'),
                                                onChanged: (value) {
                                                  setState(() {
                                                    batchNumber =
                                                        int.tryParse(value) ??
                                                            batchNumber;
                                                  });
                                                },
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // BuildDropDownStatic(
                                        //   selectedItem: selectedSupplier,
                                        //   size: size,
                                        //   isLeft: true,
                                        //   isStarRed: true,
                                        //   isStar: true,
                                        //   items: supplier,
                                        //   hintText: 'Select Supplier',
                                        //   title: 'Supplier',
                                        //   onChanged: (String? newValue) {
                                        //     selectedSupplier = newValue!;
                                        //   },
                                        // ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BuildTextTile(
                                              isStarRed: true,
                                              isTextField: true,
                                              title: 'add_purchase.select_supplier'.tr,
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
                                                  left: 20),
                                              padding: const EdgeInsets.only(
                                                  left: 15),
                                              height: size.height * .07,
                                              width: size.width / 3,
                                              child: DropdownButtonFormField<
                                                  GetSuppliersModelData>(
                                                decoration:
                                                    const InputDecoration(
                                                  border: InputBorder
                                                      .none, // Remove the underline
                                                ),
                                                value: supplier,
                                                hint: Text(
                                                  'add_purchase.select_supplier'.tr,
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.27,
                                                    ColorManager.textColor
                                                        .withOpacity(.5),
                                                  ),
                                                ),
                                                items: supplierList!.map(
                                                    (GetSuppliersModelData
                                                        supplier) {
                                                  return DropdownMenuItem<
                                                          GetSuppliersModelData>(
                                                      value: supplier,
                                                      child: Text(
                                                        supplier.name ?? '',
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
                                                onChanged:
                                                    (GetSuppliersModelData?
                                                        suppliersModelData) {
                                                  if (suppliersModelData !=
                                                      null) {
                                                    // Update the selected category in the provider
                                                    setState(() {
                                                      supplier =
                                                          suppliersModelData;
                                                      supplierIdController
                                                              .text =
                                                          "${suppliersModelData.id ?? 1}";
                                                    });
                                                  } 
                                                },
                                              ),
                                            ),
                                          ],
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
                                          title: 'add_purchase.select_store'.tr,
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
                                          child: DropdownButtonFormField<
                                              GetStoreModelData>(
                                            decoration: const InputDecoration(
                                              border: InputBorder
                                                  .none, // Remove the underline
                                            ),
                                            value: storeSelected,
                                            hint: Text(
                                              'add_purchase.select_store'.tr,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.27,
                                                ColorManager.textColor
                                                    .withOpacity(.5),
                                              ),
                                            ),
                                            items: storeList!
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
                                    const SizedBox(height: 45),
                                    Row(
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 10.0),
                                          child: CustomRoundButton(
                                            title: 'add_purchase.btn_add'.tr,
                                            fct: () async {
                                              if (formKey.currentState!
                                                  .validate()) {
                                                formKey.currentState!.save();
                                                // debugPrint("submit");
                                                debugPrint(
                                                    "categoryIdController.text ${categoryIDController.text}");
                                                debugPrint(
                                                    "productIDController.text ${productIDController.text}");
                                                debugPrint(
                                                    "quantity $quantity");
                                                debugPrint(
                                                    "supplier $supplier  ${supplierIdController.text}");
                                                debugPrint(
                                                    "storeSelected  $storeSelected   ${storeController.text}");
                                                debugPrint(
                                                    "selectedProperty  $selectedProperty  ");
                                                // debugPrint(
                                                //     "categoryNameArabicController.text ${categoryNameArabicController.text}");

                                                if (selectedValue == null ||
                                                    selectedValueCategory ==
                                                        null ||
                                                    selectedProperty == null ||
                                                    supplierIdController
                                                        .text.isEmpty ||
                                                    storeController
                                                        .text.isEmpty) {
                                                  debugPrint(
                                                      "isEmptycategorySlugController");

                                                  showScaffold(
                                                    context: context,
                                                    message:
                                                        'add_purchase.fill_required'.tr,
                                                  );
                                                } else {
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
                                                  PurchaseProvider()
                                                      .addPurchaseItem(
                                                          quantity: "$quantity",
                                                          categoryId:
                                                              categoryIDController
                                                                  .text,
                                                          unit:
                                                              selectedProperty ??
                                                                  "",
                                                          batchNumber:
                                                              "$batchNumber",
                                                          productId:
                                                              productIDController
                                                                  .text,
                                                          storeId:
                                                              storeController
                                                                  .text,
                                                          supplierId:
                                                              supplierIdController
                                                                  .text,
                                                          accessToken:
                                                              accessToken ?? "")
                                                      .then((value) {
                                                    if (value["status"] ==
                                                        "success") {
                                                      showScaffold(
                                                          context: context,
                                                          message:
                                                              value["message"]);

                                                      getPurchaseItems();

                                                      Navigator.pop(context);
                                                      // sideBarController
                                                      //     .index.value = 19;
                                                    } else {
                                                      debugPrint(
                                                          "errors.password !=null");
                                                      Navigator.pop(context);

                                                      showScaffold(
                                                          context: context,
                                                          message:
                                                              value["message"]);
                                                      sideBarController
                                                          .index.value = 19;
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
                                        const SizedBox(width: 10),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 10.0),
                                          child: CustomRoundButton(
                                            title: 'add_purchase.btn_back'.tr,
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              sideBarController.index.value =
                                                  19;
                                            },
                                            height: 50,
                                            width: size.width * 0.19,
                                            fontSize: FontSize.s12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 25),
                                    const Divider(
                                      thickness: 0.5,
                                    ),
                                    BuildTextTile(
                                      title: 'add_purchase.purchase_items'.tr,
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
                                    BuildBoxShadowContainer(
                                        // height: size.height, //120,
                                        width: size.width,
                                        margin: const EdgeInsets.only(top: 20),
                                        circleRadius: 7,
                                        offsetValue: const Offset(1, 1),
                                        child: Table(
                                          columnWidths: const {
                                            0: FractionColumnWidth(0.01),
                                            1: FractionColumnWidth(0.08),
                                            2: FractionColumnWidth(0.02),
                                            3: FractionColumnWidth(0.06),
                                            4: FractionColumnWidth(0.06),
                                            5: FractionColumnWidth(0.06),
                                            6: FractionColumnWidth(0.06),
                                            7: FractionColumnWidth(0.05),
                                          },
                                          border: const TableBorder.symmetric(
                                              outside: BorderSide(
                                                  color: ColorManager
                                                      .tableBOrderColor,
                                                  width: 0.3),
                                              inside: BorderSide(
                                                  color: ColorManager
                                                      .tableBOrderColor,
                                                  width: 0.8)),
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                                decoration: const BoxDecoration(
                                                    color: ColorManager
                                                        .tableBGColor),
                                                children: [
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_no'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_product_name'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_quantity'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_supplier_name'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_store_name'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_price'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_total_price'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                            child: Text(
                                                          'add_purchase.col_action'.tr,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s12,
                                                            0.18,
                                                            ColorManager
                                                                .kPrimaryColor,
                                                          ),
                                                        )),
                                                      )),
                                                ]),

                                            // Map your order data to table rows here
                                            ...purchaseItemList!
                                                .toList()
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              int index = entry.key;
                                              var products = entry.value;

                                              return TableRow(
                                                children: [
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            (index + 1)
                                                                .toString(),
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            "${products.name}",
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            "${products.quantity}",
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            "${products.quantity}",
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            "${products.quantity}",
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            "${products.unitPrice}",
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Text(
                                                            "${products.unitPrice! * products.quantity!}",
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s9,
                                                              0.13,
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      )),
                                                  TableCell(
                                                      verticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(15.0),
                                                        child: Center(
                                                          child: Row(
                                                            children: [
                                                              BuildBoxShadowContainer(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              5,
                                                                          right:
                                                                              5),
                                                                  circleRadius:
                                                                      5,
                                                                  color: Colors
                                                                      .red
                                                                      .withOpacity(
                                                                          0.9),
                                                                  child:
                                                                      IconButton(
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .delete,
                                                                      size: 18,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    onPressed:
                                                                        () async {
                                                                      showDialog(
                                                                          context:
                                                                              context,
                                                                          barrierDismissible:
                                                                              false,
                                                                          builder:
                                                                              (context) {
                                                                            return const Center(
                                                                              child: CircularProgressIndicator.adaptive(),
                                                                            );
                                                                          });

                                                                      String?
                                                                          accessToken =
                                                                          Provider.of<AuthModel>(context, listen: false)
                                                                              .token;
                                                                      debugPrint(
                                                                          "accessToken From AuthModel $accessToken");
                                                                      PurchaseProvider()
                                                                          .removePurchaseItem(
                                                                              itemId: "${products.id}",
                                                                              accessToken: accessToken ?? "")
                                                                          .then((value) {
                                                                        if (value["status"] ==
                                                                            "success") {
                                                                          showScaffold(
                                                                              context: context,
                                                                              message: value["message"]);
                                                                          getPurchaseItems();

                                                                          Navigator.pop(
                                                                              context);
                                                                        } else {
                                                                          debugPrint(
                                                                              "errors.password !=null");
                                                                          Navigator.pop(
                                                                              context);

                                                                          showScaffold(
                                                                              context: context,
                                                                              message: value["message"]);
                                                                        }
                                                                      });
                                                                    },
                                                                  )),
                                                            ],
                                                          ),
                                                        ),
                                                      )),
                                                ],
                                              );
                                            }).toList(),
                                          ],
                                        )),
                                    const SizedBox(height: 25),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 10.0),
                                      child: CustomRoundButton(
                                        title: 'add_purchase.btn_finish'.tr,
                                        fct: () async {
                                          debugPrint(
                                              " purchase id finish button$purchaseId");

                                          if (purchaseId == null) {
                                            showScaffold(
                                                context: context,
                                                message: 'add_purchase.failed'.tr);
                                            sideBarController.index.value = 19;
                                          } else {
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
                                                Provider.of<AuthModel>(context,
                                                        listen: false)
                                                    .token;
                                            debugPrint(
                                                "accessToken From AuthModel $accessToken");
                                            PurchaseProvider()
                                                .addPurchase(
                                                    purchaseId: "$purchaseId",
                                                    accessToken:
                                                        accessToken ?? "")
                                                .then((value) {
                                              if (value["status"] ==
                                                  "success") {
                                                //  purchaseItemList = [];
                                                //  getPurchaseItems();
                                                showScaffold(
                                                    context: context,
                                                    message: value["message"]);

                                                Navigator.pop(context);
                                                sideBarController.index.value =
                                                    19;
                                              } else {
                                                debugPrint(
                                                    "errors.password !=null");
                                                Navigator.pop(context);

                                                showScaffold(
                                                    context: context,
                                                    message: value["message"]);
                                                sideBarController.index.value =
                                                    19;
                                              }
                                            });
                                          }
                                        },
                                        height: 50,
                                        width: size.width * 0.19,
                                        fontSize: FontSize.s12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  )
                ],
              ),
            ),
          )),
    );
  }
}
// BuildDropDownStatic(
//                               selectedItem: selectedStore,
//                               size: size,
//                               isStarRed: true,
//                               isStar: true,
//                               items: store,
//                               hintText: 'Select Store',
//                               title: 'Store',
//                               onChanged: (String? newValue) {
//                                 selectedStore = newValue!;
//                               },
//                             ),
