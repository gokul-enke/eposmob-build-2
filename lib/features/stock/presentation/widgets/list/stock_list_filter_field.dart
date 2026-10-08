import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../../state/stock_list_controller.dart';

enum StockListField { name, category, barcode, rack, store, status }

class StockListFilterField extends StatelessWidget {
  final StockListField field;
  final StockListController inputs;
  final VoidCallback onSearch;
  final void Function(VoidCallback) change;
  const StockListFilterField(
      {super.key,
      required this.field,
      required this.inputs,
      required this.onSearch,
      required this.change});
  @override
  Widget build(BuildContext context) {
    switch (field) {
      case StockListField.name:
        return _buildStockNameField();
      case StockListField.category:
        return _buildCategoryDropdown();
      case StockListField.barcode:
        return _buildBarcodeField();
      case StockListField.rack:
        return _buildRackField();
      case StockListField.store:
        return _buildStoreDropdown();
      case StockListField.status:
        return _buildStockStatusDropdown();
    }
  }

  Widget _buildStockNameField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsetsDirectional.only(start: 15),
      height: 45,
      child: TextField(
        controller: inputs.stockNameController,
        onChanged: (value) {
          onSearch();
        },
        decoration: InputDecoration(
          hintText: 'stock.stock_name'.tr,
          hintStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            ColorManager.textColor.withOpacity(.5),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.27,
          ColorManager.textColor.withOpacity(.5),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'stock.please_select'.tr,
      value: inputs.categoryController.text == "All Categories"
          ? null
          : inputs.categoryController.text,
      items: inputs.categories
          .where((category) => category != "All Categories")
          .toList(),
      onChanged: (String? newValue) {
        change(() {
          inputs.categoryController.text = newValue ?? "All Categories";
        });
        onSearch();
      },
      displayText: (category) => category,
      searchController: inputs.categorySearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildBarcodeField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsetsDirectional.only(start: 15),
      height: 45,
      child: TextField(
        controller: inputs.barcodeController,
        onChanged: (value) {
          onSearch();
        },
        decoration: InputDecoration(
          hintText: 'stock.barcode'.tr,
          hintStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            ColorManager.textColor.withOpacity(.5),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.27,
          ColorManager.textColor.withOpacity(.5),
        ),
      ),
    );
  }

  Widget _buildRackField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsetsDirectional.only(start: 15),
      height: 45,
      child: TextField(
        controller: inputs.rackController,
        onChanged: (value) {
          onSearch();
        },
        decoration: InputDecoration(
          hintText: 'stock.rack_number'.tr,
          hintStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            ColorManager.textColor.withOpacity(.5),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.27,
          ColorManager.textColor.withOpacity(.5),
        ),
      ),
    );
  }

  Widget _buildStoreDropdown() {
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'stock.select_store'.tr,
      value: inputs.storeController.text == "All Stores"
          ? null
          : inputs.storeController.text,
      items: inputs.stores.where((store) => store != "All Stores").toList(),
      onChanged: (String? newValue) {
        change(() {
          inputs.storeController.text = newValue ?? "All Stores";
        });
        onSearch();
      },
      displayText: (store) => store,
      searchController: inputs.storeSearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildStockStatusDropdown() {
    final statusOptions = [
      'Out of Stock',
      'Low Stock',
      'At Reorder Level',
    ];
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'stock.stock_status'.tr,
      value: inputs.stockStatusController.text == "All Statuses"
          ? null
          : inputs.stockStatusController.text,
      items: statusOptions,
      onChanged: (String? newValue) {
        change(() {
          inputs.stockStatusController.text = newValue ?? "All Statuses";
        });
        onSearch();
      },
      displayText: UiCodeLabels.stockStatus,
      searchController: inputs.statusSearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }
}
