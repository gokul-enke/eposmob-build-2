import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../widgets/list/product_list_labels.dart';

Future<File> exportProductList(List<GetProduct> products,
        {required bool itemCodeEnabled,
        required bool canViewPurchasePrice,
        Directory? outputDirectory}) =>
    ListExcelExportService.export<GetProduct>(
        items: products,
        fileNamePrefix: 'products',
        sheetName: 'Products',
        outputDirectory: outputDirectory,
        columns: [
          ListExportColumn(label: 'product.col_no'.tr, value: (_, i) => i + 1),
          ListExportColumn(
              label: 'product.product_name'.tr,
              value: (p, _) => ProductListLabels.name(p)),
          if (itemCodeEnabled)
            ListExportColumn(
                label: 'product.item_code'.tr, value: (p, _) => p.itemCode),
          ListExportColumn(
              label: 'product.category_name'.tr,
              value: (p, _) => ProductListLabels.category(p)),
          ListExportColumn(
              label: 'product.price'.tr,
              value: (p, _) => ListExcelExportService.numericValue(
                  p.price?.price?.toString())),
          ListExportColumn(
              label: 'product.mrp'.tr,
              value: (p, _) =>
                  ListExcelExportService.numericValue(p.mrp?.toString())),
          if (canViewPurchasePrice)
            ListExportColumn(
                label: 'product.purchase_price'.tr,
                value: (p, _) => ListExcelExportService.numericValue(
                    ProductListLabels.purchasePrice(p)?.toString())),
          ListExportColumn(label: 'product.unit'.tr, value: (p, _) => p.unit),
          ListExportColumn(
              label: 'product.barcode'.tr, value: (p, _) => p.barcode),
        ]);
