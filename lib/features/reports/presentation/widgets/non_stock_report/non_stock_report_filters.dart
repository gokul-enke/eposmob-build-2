import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'non_stock_report_picker.dart';

FilterPanel nonStockReportFilters(
        {required TextEditingController barcode,
        required String? store,
        required String? category,
        required String? product,
        required int resetRevision,
        required VoidCallback onSubmit,
        required VoidCallback onReset,
        required ValueChanged<String?> onStore,
        required ValueChanged<String?> onCategory,
        required ValueChanged<String?> onProduct,
        required Map<String, String> stores,
        required Map<String, String> categories,
        required Map<String, String> products}) =>
    FilterPanel(
        key: const ValueKey('non-stock-report-filters'),
        title: 'non_stock_report.find'.tr,
        hint: 'non_stock_report.filter_hint'.tr,
        onSearch:
            () {}, // The controller observes barcode edits, including clears.
        onSubmit: onSubmit,
        onReset: onReset,
        resetLabel: 'list.reset'.tr,
        fields: [
          CustomFilterField(
              child: NonStockReportPicker(
                  key: ValueKey('non-stock-store-$resetRevision'),
                  label: 'non_stock_report.store'.tr,
                  allLabel: 'non_stock_report.all_stores'.tr,
                  icon: Icons.store_outlined,
                  options: stores,
                  value: store,
                  onChanged: onStore)),
          CustomFilterField(
              child: NonStockReportPicker(
                  key: ValueKey('non-stock-category-$resetRevision'),
                  label: 'non_stock_report.category'.tr,
                  allLabel: 'non_stock_report.all_categories'.tr,
                  icon: Icons.category_outlined,
                  options: categories,
                  value: category,
                  onChanged: onCategory)),
          CustomFilterField(
              child: NonStockReportPicker(
                  key: ValueKey('non-stock-product-$resetRevision'),
                  label: 'non_stock_report.product'.tr,
                  allLabel: 'non_stock_report.all_products'.tr,
                  icon: Icons.inventory_2_outlined,
                  options: products,
                  value: product,
                  onChanged: onProduct)),
          TextFilterField(
              controller: barcode,
              label: 'non_stock_report.barcode'.tr,
              hint: 'non_stock_report.filter_by_barcode'.tr,
              icon: Icons.qr_code),
        ]);
