import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_stock_report_model.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GetStockReportResponse parsing tests', () {
    test('Correctly parses stock report JSON with summary and pagination', () {
      final jsonStr = '''
      {
        "status": "success",
        "message": "Stock report loaded successfully",
        "data": {
          "current_page": 1,
          "data": [
            {
              "id": 10,
              "name": "Widget A",
              "barcode": "12345678",
              "category_name": "Gadgets",
              "total_quantity": 150,
              "store_count": 3,
              "stock_value": 750.50,
              "retail_value": 1500.00,
              "expiry_date": "2027-12-31",
              "unit": "BOX"
            }
          ],
          "first_page_url": "http://example.com/api/v1/stock-report?page=1",
          "from": 1,
          "last_page": 5,
          "last_page_url": "http://example.com/api/v1/stock-report?page=5",
          "next_page_url": "http://example.com/api/v1/stock-report?page=2",
          "path": "http://example.com/api/v1/stock-report",
          "per_page": 20,
          "prev_page_url": null,
          "to": 1,
          "total": 100
        },
        "summary": {
          "total_units": 1000,
          "total_stock_value": 5000.00,
          "total_retail_value": 10000.00,
          "snapshot_date": "2026-07-29"
        }
      }
      ''';

      final Map<String, dynamic> parsedJson = json.decode(jsonStr);
      final response = GetStockReportResponse.fromJson(parsedJson);

      expect(response.status, 'success');
      expect(response.message, 'Stock report loaded successfully');
      expect(response.pagination?.currentPage, 1);
      expect(response.pagination?.lastPage, 5);

      // Verify list items
      expect(response.data, hasLength(1));
      final item = response.data.first;
      expect(item.id, 10);
      expect(item.name, 'Widget A');
      expect(item.barcode, '12345678');
      expect(item.categoryName, 'Gadgets');
      expect(item.totalQuantity, 150);
      expect(item.storeCount, 3);
      expect(item.stockValue, 750.50);
      expect(item.retailValue, 1500.00);
      expect(item.expiryDate, '2027-12-31');
      expect(item.unit, 'BOX');

      // Verify summary
      expect(response.summary?.totalUnits, 1000);
      expect(response.summary?.totalStockValue, 5000.00);
      expect(response.summary?.totalRetailValue, 10000.00);
      expect(response.summary?.snapshotDate, '2026-07-29');
    });

    test('Gracefully handles empty lists and missing properties', () {
      final jsonStr = '''
      {
        "status": "success",
        "message": "Empty data test",
        "data": []
      }
      ''';

      final Map<String, dynamic> parsedJson = json.decode(jsonStr);
      final response = GetStockReportResponse.fromJson(parsedJson);

      expect(response.data, isEmpty);
      expect(response.summary, isNull);
      expect(response.pagination, isNull);
    });
  });

  group('SideBarController index 98 registration check', () {
    test('Index 98 points to StockReportScreen class type', () {
      final controller = Get.put(SideBarController());
      final screenWidget = controller.screens[98];
      
      // Verify that the registered screen matches type name
      expect(screenWidget.runtimeType.toString(), 'StockReportScreen');
    });
  });
}
