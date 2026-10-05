import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase_voucher.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../navigation/purchase_navigation.dart';
import '../../state/legacy_purchase_list_controller.dart';
import 'legacy_purchase_list_actions.dart';

part 'purchase_voucher_table_1.dart';
part 'purchase_voucher_table_2.dart';

class LegacyPurchaseVoucherListView extends StatelessWidget {
  const LegacyPurchaseVoucherListView(
      {super.key,
      required this.controller,
      required this.actions,
      required this.onAddVoucher});
  final LegacyPurchaseListController controller;
  final LegacyPurchaseListActions actions;
  final VoidCallback onAddVoucher;
  bool get initLoading => controller.initLoading;
  set initLoading(bool value) => controller.initLoading = value;
  List<VoucherModelData>? get voucherModelListData =>
      controller.voucherModelListData;
  set voucherModelListData(List<VoucherModelData>? value) =>
      controller.voucherModelListData = value ?? [];
  TextEditingController get searchTextController =>
      controller.searchTextController;
  TextEditingController get storeController => controller.storeController;
  TextEditingController get amountController => controller.amountController;
  DateTime? get selectedDate => controller.selectedDate;
  set selectedDate(DateTime? value) => controller.selectedDate = value;
  GetStoreModelData? get storeSelected => controller.storeSelected;
  set storeSelected(GetStoreModelData? value) =>
      controller.storeSelected = value;
  void resetSearch() {
    controller.load(1, true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final storeList = actions.getStoreList;
    return SafeArea(
      child: Container(
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
            color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: ListView(
            children: [
              Text(
                'purchase_voucher.page_title'.tr,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
              const SizedBox(
                height: 15,
              ),
              SizedBox(
                height: 90,
                child: Row(
                  // scrollDirection: Axis.horizontal,
                  // physics: const BouncingScrollPhysics(),
                  children: [
                    // Store
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'purchase_voucher.filter_store'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 45,
                            width: 150,
                            child: BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 0),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width / 4.5,
                              child: DropdownButtonFormField<GetStoreModelData>(
                                decoration: const InputDecoration(
                                  border:
                                      InputBorder.none, // Remove the underline
                                ),
                                value: storeSelected,
                                hint: Text(
                                  'purchase_voucher.hint_select_store'.tr,
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                ),
                                items:
                                    storeList!.map((GetStoreModelData store) {
                                  return DropdownMenuItem<GetStoreModelData>(
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
                                onChanged: (GetStoreModelData? storeModelData) {
                                  if (storeModelData != null) {
                                    // Update the selected category in the provider
                                    controller.change(() {
                                      storeSelected = storeModelData;
                                      storeController.text =
                                          "${storeModelData.id ?? 1}";
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'purchase_voucher.filter_date'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            height: 45,
                            width: 150,
                            child: Center(
                              child: CalendarPickerTableCell(
                                onDateSelected: (DateTime date) {
                                  selectedDate = date;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'purchase_voucher.filter_amount'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          buildColumnWidgetForTextFields(
                            height: 45,
                            width: 120,
                            onchanged: (value) {},
                            controller: amountController,
                            size: size,
                            hintText: 'purchase_voucher.filter_amount'.tr,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: 'purchase_voucher.btn_search'.tr,
                        fct: () {
                          controller.load(1);
                        },
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: 'general.reset'.tr,
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () {
                          resetSearch();
                        },
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                  ],
                ),
              ),
              BuildBoxShadowContainer(
                  // height: size.height, //120,
                  margin: const EdgeInsets.only(top: 20),
                  circleRadius: 7,
                  offsetValue: const Offset(1, 1),
                  child: initLoading
                      ? _buildVoucherTable1()
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: size.width * 1,
                            child: _buildVoucherTable2(),
                          ),
                        )),
              PaginationControl(
                currentPage: controller.currentPage,
                totalPages: controller.totalPages,
                onPageChanged: (int page) {
                  controller.load(page);
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
