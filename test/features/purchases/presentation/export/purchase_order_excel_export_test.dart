import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/purchases/domain/models/purchase_order_model.dart';
import 'package:pos_machine/features/purchases/presentation/export/purchase_order_excel_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  setUp(() {
    Get.testMode = true;
    temp = Directory.systemTemp.createTempSync('purchase-order-export');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => temp.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    temp.deleteSync(recursive: true);
    Get.reset();
  });

  test('received items column matches the list label for empty values',
      () async {
    final file = await exportPurchaseOrders([
      PurchaseOrderData(id: 1, itemsReceived: ''),
      PurchaseOrderData(id: 2),
      PurchaseOrderData(id: 3, itemsReceived: '1 / 2'),
    ], 'SAR');
    final sheet =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.single;
    expect([
      for (var r = 1; r <= 3; r++) '${sheet.row(r)[6]!.value}'
    ], [
      'purchase_order.items_received_default'.tr,
      'purchase_order.items_received_default'.tr,
      '1 / 2',
    ]);
  });
}
