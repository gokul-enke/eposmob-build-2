import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'ar', 'ml']) {
    test('$locale contains every Product Sales Report translation', () {
      final file = File('lib/resources/i18n/$locale.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final translations =
          Map<String, dynamic>.from(json['product_sales_report'] as Map);

      for (final key in [
        'page_title',
        'subtitle',
        'find',
        'filter_hint',
        'select_date',
        'count',
        'export_fetching',
        'col_price',
        'filter_category',
        'filter_product',
        'filter_from',
        'filter_to',
        'filter_customer',
        'all',
        'select_customer',
        'invalid_date_range',
        'show_filters',
        'hide_filters',
        'export',
        'exporting',
        'export_error',
        'share_text',
        'total_revenue',
        'total_quantity',
        'no_data',
      ]) {
        expect(
          translations[key],
          isA<String>().having((value) => value.trim(), 'value', isNotEmpty),
          reason: 'Missing product_sales_report.$key in $locale.json',
        );
      }
    });
  }
}
