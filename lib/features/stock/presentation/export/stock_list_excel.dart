import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

Future<File> exportStockListExcel(List<ListStockModelData> rows,
        {required bool canViewPurchasePrice,
        required bool variantEnabled,
        Directory? outputDirectory}) =>
    ListExcelExportService.export<ListStockModelData>(
      items: rows,
      fileNamePrefix: 'product-stock-list',
      sheetName: 'Product Stock List',
      outputDirectory: outputDirectory,
      columns: [
        ListExportColumn(label: 'stock.list_id'.tr, value: (s, _) => s.stockId),
        ListExportColumn(
            label: 'stock.product_name'.tr, value: (s, _) => s.productName),
        if (variantEnabled)
          ListExportColumn(
              label: 'stock.product_variant'.tr,
              value: (s, _) => s.productVariantId == null
                  ? null
                  : (s.variantName?.trim().isNotEmpty == true
                      ? s.variantName
                      : 'stock.list_variant'
                          .trParams({'id': '${s.productVariantId}'}))),
        ListExportColumn(
            label: 'stock.category'.tr, value: (s, _) => s.categoryName),
        ListExportColumn(
            label: 'stock.label_store'.tr, value: (s, _) => s.storeName),
        ListExportColumn(label: 'stock.barcode'.tr, value: (s, _) => s.barCode),
        ListExportColumn(
            label: 'stock.retail_price'.tr,
            value: (s, _) =>
                ListExcelExportService.numericValue(s.retailPrice)),
        ListExportColumn(
            label: 'stock.mrp'.tr,
            value: (s, _) => ListExcelExportService.numericValue(s.mrp)),
        if (canViewPurchasePrice)
          ListExportColumn(
              label: 'stock.purchase_price'.tr,
              value: (s, _) =>
                  ListExcelExportService.numericValue(s.purchaseRate)),
        ListExportColumn(label: 'stock.quantity'.tr, value: (s, _) => s.qty),
        ListExportColumn(label: 'stock.unit'.tr, value: (s, _) => s.unit),
        ListExportColumn(label: 'stock.rack'.tr, value: (s, _) => s.rack),
        ListExportColumn(
            label: 'stock.order_date'.tr,
            value: (s, _) => DateHelper.formatISODate(s.orderDate ?? '')),
        ListExportColumn(
            label: 'stock.stock_status'.tr, value: (s, _) => s.stockStatus),
      ],
    );
