import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/legacy_purchase_form_controller.dart';

part 'legacy_purchase_form_dropdown2.dart';
part 'legacy_purchase_form_dropdown1.dart';
part 'legacy_purchase_form_row2.dart';
part 'legacy_purchase_form_row1.dart';
part 'legacy_purchase_form_table1.dart';
part 'legacy_purchase_form_form.dart';
part 'legacy_purchase_form_section1.dart';
part 'legacy_purchase_form_section2.dart';
part 'legacy_purchase_form_section3.dart';
part 'legacy_purchase_form_section4.dart';

class LegacyPurchaseFormView extends StatelessWidget {
  const LegacyPurchaseFormView(
      {super.key,
      required this.controller,
      required this.formKey,
      required this.categoryList,
      required this.unitList,
      required this.selectCategory,
      required this.onBack});
  final LegacyPurchaseFormController controller;
  final GlobalKey<FormState> formKey;
  final List<Category>? categoryList;
  final Map<String, String>? unitList;
  final Future<List<GetProduct>?> Function(Category, int) selectCategory;
  final VoidCallback onBack;
  int get quantity => controller.quantity;
  set quantity(int value) => controller.quantity = value;
  int get batchNumber => controller.batchNumber;
  set batchNumber(int value) => controller.batchNumber = value;
  bool get initLoading => controller.initLoading;
  set initLoading(bool value) => controller.initLoading = value;
  bool get apiLoading => controller.apiLoading;
  set apiLoading(bool value) => controller.apiLoading = value;
  List<PurchaseItem>? get purchaseItemList => controller.purchaseItemList;
  set purchaseItemList(List<PurchaseItem>? value) =>
      controller.purchaseItemList = value;
  int? get purchaseId => controller.purchaseId;
  set purchaseId(int? value) => controller.purchaseId = value;
  String? get selectedProperty => controller.selectedProperty;
  set selectedProperty(String? value) => controller.selectedProperty = value;
  String? get selectedSupplier => controller.selectedSupplier;
  set selectedSupplier(String? value) => controller.selectedSupplier = value;
  GetProduct? get selectedValue => controller.selectedValue;
  set selectedValue(GetProduct? value) => controller.selectedValue = value;
  Category? get selectedValueCategory => controller.selectedValueCategory;
  set selectedValueCategory(Category? value) =>
      controller.selectedValueCategory = value;
  String? get selected => controller.selected;
  set selected(String? value) => controller.selected = value;
  GetSuppliersModelData? get supplier => controller.supplier;
  set supplier(GetSuppliersModelData? value) => controller.supplier = value;
  GetStoreModelData? get storeSelected => controller.storeSelected;
  set storeSelected(GetStoreModelData? value) =>
      controller.storeSelected = value;
  List<GetStoreModelData>? get storeList => controller.storeList;
  set storeList(List<GetStoreModelData>? value) => controller.storeList = value;
  List<GetSuppliersModelData>? get supplierList => controller.supplierList;
  set supplierList(List<GetSuppliersModelData>? value) =>
      controller.supplierList = value;
  List<GetProduct>? get productList => controller.productList;
  set productList(List<GetProduct>? value) => controller.productList = value;
  TextEditingController get supplierIdController =>
      controller.supplierIdController;
  TextEditingController get storeController => controller.storeController;
  TextEditingController get quantityController => controller.quantityController;
  TextEditingController get unitController => controller.unitController;
  TextEditingController get categoryIDController =>
      controller.categoryIDController;
  TextEditingController get productIDController =>
      controller.productIDController;
  TextEditingController get textEditingController =>
      controller.textEditingController;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
                      onBack();
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
                              child: _form(context),
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
