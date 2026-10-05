import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../navigation/purchase_navigation.dart';
import '../../state/legacy_purchase_list_controller.dart';
import 'legacy_purchase_list_actions.dart';

part 'purchase_view_1.dart';
part 'purchase_view_2.dart';

class LegacyPurchaseListView extends StatelessWidget {
  const LegacyPurchaseListView(
      {super.key,
      required this.controller,
      required this.actions,
      required this.onAddVoucher});
  final LegacyPurchaseListController controller;
  final LegacyPurchaseListActions actions;
  final VoidCallback onAddVoucher;
  bool get initLoading => controller.initLoading;
  set initLoading(bool value) => controller.initLoading = value;
  List<PurchaseItem> get purchaseDetailsList => controller.purchaseDetailsList;
  set purchaseDetailsList(List<PurchaseItem> value) =>
      controller.purchaseDetailsList = value;
  TextEditingController get purchaserNameController =>
      controller.purchaserNameController;
  TextEditingController get productNameController =>
      controller.productNameController;
  TextEditingController get supplierIdController =>
      controller.supplierIdController;
  TextEditingController get storeController => controller.storeController;
  DateTime? get selectedDate => controller.selectedDate;
  set selectedDate(DateTime? value) => controller.selectedDate = value;
  GetStoreModelData? get storeSelected => controller.storeSelected;
  set storeSelected(GetStoreModelData? value) =>
      controller.storeSelected = value;
  GetSuppliersModelData? get supplier => controller.supplier;
  set supplier(GetSuppliersModelData? value) => controller.supplier = value;
  void resetSearch() {
    controller.load(1, true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final purchaseProvider = actions;
    final storeList = actions.getStoreList;
    final supplierList = actions.getSupplierList;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
              // Header
              _buildHeader(),

              const SizedBox(height: 15),

              // Search Filters
              _buildSearchFilters(size, storeList, supplierList),

              // Search Buttons
              // _buildSearchButtons(size),

              // Purchase List
              _buildPurchaseList(size, purchaseProvider),

              // Pagination
              _buildPagination(context),
            ],
          ),
        ),
      ),
    );
  }
}
