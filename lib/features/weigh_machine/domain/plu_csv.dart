import 'package:pos_machine/models/get_product.dart';

/// The field order follows the weighted-product export offered by CloudPOS.
/// Barcode stays a string so leading zeroes survive the CSV round trip.
class PluCsv {
  static const fileName = 'PLU.csv';
  static const headers = <String>[
    'Product Name',
    'Category',
    'Barcode',
    'Price',
    'MRP',
    'Unit',
    'Purchase Price',
    'Arabic Name',
  ];

  static List<GetProduct> weighted(Iterable<GetProduct> products) => products
      .where((product) => product.weightInfo?.isWeighted == true)
      .toList(growable: false);

  static String build(Iterable<GetProduct> products) {
    final rows = <List<String>>[
      headers,
      for (final product in products)
        [
          product.productName ?? '',
          product.category?.name ?? '',
          product.barcode ?? '',
          _money(product.price?.price),
          _money(product.mrp),
          product.unit ?? '',
          _money(product.purchasePrice),
          _arabicName(product.names),
        ],
    ];
    return '${rows.map((row) => row.map(_escape).join(',')).join('\r\n')}\r\n';
  }

  static String _money(Object? value) {
    final number = num.tryParse(value?.toString() ?? '');
    return number == null ? '' : number.toStringAsFixed(2);
  }

  static String _arabicName(Object? names) {
    if (names is Map) return names['ar']?.toString() ?? '';
    return '';
  }

  static String _escape(String value) {
    if (!value.contains(RegExp('[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
