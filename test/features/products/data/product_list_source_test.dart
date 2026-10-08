import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/products/data/product_list_source.dart';
import 'package:pos_machine/features/products/domain/product_list_query.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import '../support/product_list_hive.dart';
import '../../../test_support/hive_test_teardown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final directory = await openProductListHive();
    addTearDown(() => closeHiveAndDeleteTestDir(directory));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final catalog = [
    GetProduct(
        productId: 1,
        productName: 'Apple',
        barcode: '00012',
        categoryId: 2,
        price: ProductPrice(price: '10.000'),
        itemCode: 'SKU-A',
        hsnCode: 'HSN1',
        sellable: false),
    GetProduct(
        productId: 2,
        productName: 'Pineapple',
        barcode: '000123',
        categoryId: 2,
        price: ProductPrice(price: '12.000'),
        itemCode: 'sku-b',
        hsnCode: 'HSN2'),
    GetProduct(
        productId: 3,
        productName: 'Pear',
        barcode: '9912',
        categoryId: 3,
        price: ProductPrice(price: '9.000'),
        stock: [Stock(hsnCode: 'stock-hsn')]),
  ];
  final queries = [
    const ProductListQuery(),
    const ProductListQuery(name: 'apple'),
    const ProductListQuery(barcode: '0012'),
    const ProductListQuery(categoryId: 2),
    const ProductListQuery(price: '10'),
    const ProductListQuery(hsn: 'stock'),
    const ProductListQuery(hsn: 'hsn2'),
    const ProductListQuery(itemCode: 'SKU-b'),
    const ProductListQuery(
        categoryId: 2,
        name: 'apple',
        price: '10',
        barcode: '12',
        hsn: 'hsn1',
        itemCode: 'sku'),
    const ProductListQuery(name: 'missing'),
  ];
  for (final query in queries.indexed) {
    test('query ${query.$1} matches the legacy local filter contract',
        () async {
      final legacy = LocalProductProvider();
      addTearDown(legacy.dispose);
      await legacy.hydrated;
      legacy.products.addAll(catalog);
      final q = query.$2;
      legacy.listAllProducts(
          categoryId: q.categoryId,
          filterName: q.name,
          filterBarcode: q.barcode,
          filterPrice: q.price,
          filterHsnCode: q.hsn,
          filterItemCode: q.itemCode,
          filterProperties: q.property);
      final before = legacy.filteredProducts;
      final source = ProductListSource(
          readCatalog: () => legacy.products,
          deleteProduct: (_) async => false);
      expect(source.select(q).map((p) => p.productId),
          before.map((p) => p.productId));
      source.select(const ProductListQuery(name: 'Pear'));
      expect(identical(legacy.filteredProducts, before), isTrue);
      expect(legacy.currentPage, 1);
    });
  }
  test('returned snapshot is independent and cannot mutate the catalog', () {
    final original = List<GetProduct>.of(catalog);
    final source = ProductListSource(
        readCatalog: () => original, deleteProduct: (_) async => true);
    final snapshot = source.select(const ProductListQuery());
    original.clear();
    expect(snapshot, hasLength(3));
    expect(() => snapshot.clear(), throwsUnsupportedError);
  });

  final propertyCatalog = [
    GetProduct(
        productId: 1,
        productName: 'Manufacturer product',
        productProps: [
          ProductProp(propsCode: 'MANUFACTURER', masterValue: 'Aurora'),
          ProductProp(propsCode: 'PRODUCT_COLOR'),
        ]),
    GetProduct(productId: 2, productProps: [
      ProductProp(propsCode: 'SHIRT_SIZE'),
      ProductProp(propsCode: 'MANUFACTURER', masterValue: '  '),
    ]),
    GetProduct(productId: 3, variants: [
      ProductVariant(id: 30, attributes: {' product_color ': ' gold '}),
    ]),
    GetProduct(productId: 4, variants: [
      ProductVariant(
          id: 40, attributes: {'SHIRT_SIZE': 'M', 'MANUFACTURER': 'OPPO'}),
    ]),
    GetProduct(
        productId: 5,
        productName: 'Blue shirt',
        categoryId: 2,
        productProps: [
          ProductProp(propsCode: 'product_color', masterValue: 'blue')
        ],
        variants: [
          ProductVariant(id: 50, attributes: {'PRODUCT_COLOR': 'blue'}),
          ProductVariant(id: 51, attributes: {'PRODUCT_COLOR': 'red'}),
        ]),
    GetProduct(productId: 6, variants: [
      ProductVariant(id: 60, attributes: {'SHOE_SIZE': 0}),
    ]),
    GetProduct(productId: 7, variants: [
      ProductVariant(id: 70, attributes: {
        'PRODUCT_COLOR': [],
        'SHIRT_SIZE': ['', '  ', null],
        'MANUFACTURER': [' ', 'Aurora'],
      }),
    ]),
    GetProduct(productId: 8),
    GetProduct(productId: 9, variants: [
      ProductVariant(
          id: 90, attributes: {'PRODUCT_COLOR': {}, 'MANUFACTURER': null}),
    ]),
  ];
  List<int?> propertyIds(ProductListQuery query) => ProductListSource(
          readCatalog: () => propertyCatalog, deleteProduct: (_) async => false)
      .select(query)
      .map((p) => p.productId)
      .toList();

  test('property filtering finds assigned product and variant values', () {
    expect(propertyIds(const ProductListQuery(property: 'MANUFACTURER')),
        [1, 4, 7]);
    expect(
        propertyIds(const ProductListQuery(property: 'PRODUCT_COLOR')), [3, 5]);
    expect(propertyIds(const ProductListQuery(property: 'SHIRT_SIZE')), [4]);
    expect(propertyIds(const ProductListQuery(property: 'SHOE_SIZE')), [6]);
  });
  test('empty definitions and empty variant values never count as assignments',
      () {
    for (final property in [
      'MANUFACTURER',
      'PRODUCT_COLOR',
      'SHIRT_SIZE',
      'SHOE_SIZE'
    ]) {
      expect(propertyIds(ProductListQuery(property: property)),
          isNot(anyOf(contains(2), contains(8), contains(9))));
    }
  });
  test('Color alias and code whitespace or case match actual catalog codes',
      () {
    expect(propertyIds(const ProductListQuery(property: 'COLOR')), [3, 5]);
    expect(propertyIds(const ProductListQuery(property: ' product_color ')),
        [3, 5]);
  });
  test('property combines with other filters without duplicate variant rows',
      () {
    expect(
        propertyIds(const ProductListQuery(
            property: 'PRODUCT_COLOR', categoryId: 2, name: 'shirt')),
        [5]);
    expect(
        propertyIds(
            const ProductListQuery(property: 'MANUFACTURER', categoryId: 2)),
        isEmpty);
    expect(propertyIds(const ProductListQuery(property: 'UNKNOWN')), isEmpty);
    expect(propertyIds(const ProductListQuery(property: '  ')), hasLength(9));
  });
}
