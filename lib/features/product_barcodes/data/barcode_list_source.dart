import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/helpers/product_search_helper.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import '../domain/barcode_list_query.dart';

/// Existing provider contracts remain the source of filtering and cache updates.
abstract interface class BarcodeListSource {
  bool get isLoading;
  int get version;
  List<GetProduct> get products;
  Future<List<BarcodeCategory>> categories();
  void apply(BarcodeListQuery query);
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

class LocalBarcodeListSource implements BarcodeListSource {
  LocalBarcodeListSource(this.catalogue, this.categoryProvider);
  final LocalProductProvider catalogue;
  final CategoryProvider categoryProvider;
  @override
  bool get isLoading => catalogue.isLoading;
  BarcodeListQuery _query = const BarcodeListQuery();
  int _version = 0;
  int _providerVersion = -1;
  List<GetProduct> _snapshot = const [];
  @override
  int get version {
    final providerVersion = catalogue.filteredProductsVersion;
    final next = catalogue.allFilteredProducts;
    // Local edits and stock updates may replace rows without bumping the
    // provider's filter counter. Compare identities before reusing expansion.
    final changed = providerVersion != _providerVersion ||
        next.length != _snapshot.length ||
        Iterable<int>.generate(next.length)
            .any((index) => !identical(next[index], _snapshot[index]));
    if (changed) {
      _snapshot = next;
      _providerVersion = providerVersion;
      _version++;
    }
    return _version;
  }

  @override
  List<GetProduct> get products {
    version;
    var result = _snapshot;
    // Local edits can insert/replace a row in the shared filtered list. Keep
    // this page's active filters using the same search helpers as the provider.
    if (_query.categoryId != null) {
      result = result
          .where((product) => product.categoryId == _query.categoryId)
          .toList();
    }
    if (_query.name.isNotEmpty) {
      result = ProductSearchHelper.search(result, _query.name);
    }
    if (_query.barcode.isNotEmpty) {
      result = ProductSearchHelper.searchBarcodes(result, _query.barcode);
    }
    return result;
  }

  @override
  Future<List<BarcodeCategory>> categories() async {
    if (!categoryProvider.isCategoriesLoaded) {
      await categoryProvider.ensureCategoriesLoaded();
    }
    // The old picker resolved the first category with a matching name.
    final firstByName = <String, BarcodeCategory>{};
    for (final category in categoryProvider.category ?? const []) {
      final name = category.categoryName ?? '';
      if (name.isNotEmpty) {
        firstByName.putIfAbsent(
            name, () => BarcodeCategory(category.categoryId, name));
      }
    }
    return firstByName.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void apply(BarcodeListQuery query) {
    _query = query;
    catalogue.listAllProducts(
      filterName: query.name.isEmpty ? null : query.name,
      categoryId: query.categoryId ?? 0,
      filterBarcode: query.barcode.isEmpty ? null : query.barcode,
      page: 1,
    );
  }

  @override
  void addListener(void Function() listener) => catalogue.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      catalogue.removeListener(listener);
}
