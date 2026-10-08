import 'package:pos_machine/models/get_product.dart';
import 'barcode_row.dart';

List<BarcodeRow> expandProductsToBarcodeRows(List<GetProduct> products,
    {String barcode = ''}) {
  final rows = <BarcodeRow>[];
  for (final product in products) {
    final subRows = <BarcodeRow>[];

    final variants = product.variants;
    if (variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        if (!v.active) continue;
        final bc = v.barcode?.trim() ?? '';
        if (bc.isNotEmpty) {
          subRows.add(BarcodeRow(product: product, variant: v));
        }
      }
    }

    final units = product.saleUnits;
    if (units != null && units.isNotEmpty) {
      final baseBarcode = (product.barcode ?? '').trim();
      for (final u in units) {
        final bc = u.barcode?.trim() ?? '';
        if (bc.isNotEmpty && bc != baseBarcode) {
          subRows.add(BarcodeRow(product: product, saleUnit: u));
        }
      }
    }

    // Always show the base product row.
    rows.add(BarcodeRow(product: product));

    // Show any variant or sale-unit rows.
    rows.addAll(subRows);
  }

  final query = barcode.trim().toLowerCase();
  if (query.isNotEmpty) {
    return rows.where((row) {
      final rowBc = row.barcode?.trim().toLowerCase() ?? '';
      return rowBc.contains(query);
    }).toList();
  }

  return rows;
}
