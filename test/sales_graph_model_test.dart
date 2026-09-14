import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/dashboard_api.dart';

void main() {
  group('SalesGraph.fromJson', () {
    test('parses integer graph values', () {
      final graph = SalesGraph.fromJson({
        'period': 'today',
        'total_sales': 125,
        'sales_graph': [
          {'time': '10:00', 'amount': 75},
        ],
      });

      expect(graph.totalSales, 125.0);
      expect(graph.salesGraph.single.amount, 75.0);
    });

    test('parses numeric strings returned by the API', () {
      final graph = SalesGraph.fromJson({
        'period': 'today',
        'total_sales': '125',
        'sales_graph': [
          {'time': '10:00', 'amount': '75'},
        ],
      });

      expect(graph.totalSales, 125.0);
      expect(graph.salesGraph.single.amount, 75.0);
    });

    test('preserves decimal precision', () {
      final graph = SalesGraph.fromJson({
        'period': 'month',
        'total_sales': '125.50',
        'sales_graph': [
          {'date': '14-09-2026', 'amount': 75.25},
        ],
      });

      expect(graph.totalSales, 125.50);
      expect(graph.salesGraph.single.amount, 75.25);
    });

    test('uses zero for missing or invalid numeric values', () {
      final graph = SalesGraph.fromJson({
        'period': 'week',
        'total_sales': null,
        'sales_graph': [
          {'day': 'Monday', 'amount': 'invalid'},
        ],
      });

      expect(graph.totalSales, 0.0);
      expect(graph.salesGraph.single.amount, 0.0);
    });
  });
}
