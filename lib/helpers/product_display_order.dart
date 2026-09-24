import 'package:pos_machine/models/get_product.dart';

/// Order in which the catalog is listed on every product screen.
///
/// 1. `sort_order` ascending, as set in the back office. Products without a
///    sort order come after every product that has one.
/// 2. Product name, ignoring case, for equal (or missing) sort orders.
/// 3. Product id, so the order never depends on how the list was loaded
///    (API page order, Hive key order, delta prepends, realtime pushes).
int compareProductDisplayOrder(GetProduct a, GetProduct b) {
  final aOrder = a.sortOrder;
  final bOrder = b.sortOrder;
  if (aOrder != bOrder) {
    if (aOrder == null) return 1;
    if (bOrder == null) return -1;
    return aOrder.compareTo(bOrder);
  }

  final byName = (a.productName ?? '')
      .trim()
      .toLowerCase()
      .compareTo((b.productName ?? '').trim().toLowerCase());
  if (byName != 0) return byName;

  return (a.productId ?? 0).compareTo(b.productId ?? 0);
}

/// Sorts [products] in place into display order and returns it.
List<GetProduct> sortProductsForDisplay(List<GetProduct> products) {
  products.sort(compareProductDisplayOrder);
  return products;
}
