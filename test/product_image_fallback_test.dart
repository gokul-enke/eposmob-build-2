import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_product_card.dart';
import 'package:pos_machine/features/products/presentation/widgets/list/product_list_card.dart';
import 'package:pos_machine/widgets/product_card_widget.dart';
import 'package:pos_machine/widgets/product_card_square_kiosk.dart';
import 'package:pos_machine/widgets/product_card_list_kiosk.dart';
import 'package:pos_machine/widgets/category_list_item_widget.dart';
import 'package:pos_machine/widgets/category_list_item.dart' as legacy_home;
import 'package:pos_machine/screens/homenew/category_list_item_new.dart'
    as home_new;
import 'package:pos_machine/providers/category_list_scope.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/widgets/product_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _productUrl = 'https://images.example.com/product.png';
const _categoryUrl = 'https://images.example.com/category.png';
const _placeholder = Icon(Icons.inventory_2_outlined);

class _ImageClient extends Fake implements HttpClient {
  final failures = <String>{};
  final requests = <String>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url.toString());
    return _ImageRequest(failures.contains(url.toString()));
  }
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.fails);
  final bool fails;

  @override
  Future<HttpClientResponse> close() async => _ImageResponse(fails);
}

class _ImageResponse extends Fake implements HttpClientResponse {
  _ImageResponse(this.fails);
  final bool fails;
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gMQFwcdLl4wmwAAAAtJREFUCNdjYAACAAAFAAHiJgWbAAAAAElFTkSuQmCC',
  );

  @override
  int get statusCode => fails ? HttpStatus.notFound : HttpStatus.ok;
  @override
  int get contentLength => _png.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_png).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  Future<E> drain<E>([E? futureValue]) async => futureValue as E;
}

class _CachedCategoryProvider extends CategoryProvider {
  final cached = Completer<List<Category>>();

  @override
  Future<List<Category>> loadCategoriesFromHive(
          {String boxName = 'categories'}) =>
      cached.future;
}

class _StaticSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

Widget _host(
  GetProduct product, {
  CategoryProvider? categories,
  Widget? listing,
  Size size = const Size(100, 100),
}) {
  Widget child = MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: listing ??
            ProductImage(product: product, placeholder: _placeholder),
      ),
    ),
  );
  if (categories != null) {
    child = ChangeNotifierProvider<CategoryProvider>.value(
      value: categories,
      child: child,
    );
  }
  return child;
}

Future<void> _finishImageLoads(WidgetTester tester) async {
  // Image decoding runs outside the test clock, including codec startup.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    final decoded = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .any((image) => image.image != null);
    if (decoded ||
        find.byIcon(Icons.inventory_2_outlined).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Image did not finish loading or show a placeholder');
}

void main() {
  late _ImageClient images;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    images = _ImageClient();
  });

  void imageTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugNetworkImageHttpClientProvider = () => images;
      try {
        await body(tester);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    });
  }

  CategoryProvider categories() => CategoryProvider()
    ..categoryList = [Category(categoryId: 7, categoryImage: _categoryUrl)];

  final listings = <String, Widget Function(GetProduct)>{
    'desktop product card': (p) => ProductCardWidget(product: p, onTap: () {}),
    'mobile product card': (p) => ProductCard(
          product: p,
          onAddWithOptions: () {},
        ),
    'kiosk product card': (p) => KioskProductCard(
          product: p,
          quantity: 0,
          currency: 'INR',
          customizable: false,
          onAdd: () {},
        ),
    'product management card': (p) => ProductListCard(
          product: p,
          number: 1,
          itemCodeEnabled: false,
          canViewPurchasePrice: false,
          onView: () {},
        ),
    'legacy kiosk grid card': (p) => ProductCardSquare(
          product: p,
          price: '10',
          title: 'Food',
          weight: 'PCS',
          isSelected: false,
          customerId: 1,
          productId: 1,
          currency: 'INR',
          attachment: p.attachment,
          fileType: '',
          file: '',
          removeFromCart: (_, __) {},
          addToCart: (_, __) {},
          count: 0,
        ),
    'legacy kiosk list card': (p) => ProductCardList(
          product: p,
          title: 'Food',
          currency: 'INR',
          price: '10',
          count: 0,
          productId: 1,
          removeFromCart: () {},
          addToCart: () {},
        ),
    'legacy home card': (p) => CategoryListItemWidget(
          product: p,
          price: '10',
          title: 'Food',
          weight: 'PCS',
          isSelected: false,
          customerId: 1,
          productId: 1,
          currency: 'INR',
          attachment: p.attachment,
          fileType: '',
          file: '',
        ),
    'legacy selected home card': (p) => SelectedCategoryListItemWidget(
          product: p,
          imageUrlPath: '',
          price: '10',
          title: 'Food',
          weight: 'PCS',
          isSelected: true,
          customerId: 1,
          productId: 1,
          currency: 'INR',
          attachment: p.attachment,
          file: '',
        ),
    'legacy home carousel image': (p) => legacy_home.buildImages(p, 0),
    'new home carousel image': (p) => home_new.buildImages(p, 0),
  };

  for (final listing in listings.entries) {
    imageTest('${listing.key} renders the category image without attachments',
        (tester) async {
      final provider = categories();
      final settings = _StaticSettings();
      addTearDown(provider.dispose);
      addTearDown(settings.dispose);
      final product = GetProduct(
        productId: 1,
        productName: 'Food',
        categoryId: 7,
        price: ProductPrice(price: '10'),
      );
      await tester.pumpWidget(ChangeNotifierProvider<AppSettingsProvider>.value(
        value: settings,
        child: _host(
          product,
          categories: provider,
          listing: listing.value(product),
          size: const Size(600, 450),
        ),
      ));
      await _finishImageLoads(tester);
      expect(images.requests, [_categoryUrl]);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(product.attachment, isNull);
    });
  }

  imageTest('shows placeholder without images or a category provider',
      (tester) async {
    await tester.pumpWidget(_host(GetProduct(categoryId: 7)));
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(images.requests, isEmpty);
  });

  imageTest('uses primary product image before the category image',
      (tester) async {
    final provider = categories();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_host(
      GetProduct(categoryId: 7, attachment: [
        Attachment(filePath: 'https://images.example.com/other.png'),
        Attachment(isPrimary: 1, filePath: _productUrl),
      ]),
      categories: provider,
    ));
    await _finishImageLoads(tester);
    expect(images.requests, [_productUrl]);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  imageTest('skips empty attachments and uses the next usable image',
      (tester) async {
    final provider = categories();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_host(
      GetProduct(categoryId: 7, attachment: [
        Attachment(isPrimary: 1, filePath: '  '),
        Attachment(filePath: 'product.png', file: _productUrl),
      ]),
      categories: provider,
    ));
    await _finishImageLoads(tester);
    expect(images.requests, [_productUrl]);
  });

  imageTest('missing product image updates after offline category hydration',
      (tester) async {
    final provider = _CachedCategoryProvider();
    addTearDown(provider.dispose);
    final product = GetProduct(categoryId: 7, attachment: []);
    await tester.pumpWidget(_host(product, categories: provider));
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

    // With no API key, the network refresh fails after hydrating the cache.
    final load = expectLater(
      provider.ensureCategories(CategoryListScope.sellable),
      throwsA(isA<HttpException>()),
    );
    provider.cached.complete([
      Category(
          categoryId: 7, categoryName: 'Food', categoryImage: _categoryUrl),
    ]);
    await tester.runAsync(() => load);
    await tester.pump();
    await _finishImageLoads(tester);
    expect(images.requests, [_categoryUrl]);
    expect(product.attachment, isEmpty);

    provider.applyBillingCategoryFilter(filterName: 'another category');
    await tester.pump();
    expect(provider.categoryList, isEmpty);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
      _categoryUrl,
    );
  });

  imageTest('failed product image loads the category image', (tester) async {
    final provider = categories();
    addTearDown(provider.dispose);
    images.failures.add(_productUrl);
    await tester.pumpWidget(_host(
      GetProduct(
          categoryId: 7, attachment: [Attachment(filePath: _productUrl)]),
      categories: provider,
    ));
    await _finishImageLoads(tester);
    expect(images.requests, [_productUrl, _categoryUrl]);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  imageTest('failed category image shows the placeholder', (tester) async {
    final provider = categories();
    addTearDown(provider.dispose);
    images.failures.add(_categoryUrl);
    await tester
        .pumpWidget(_host(GetProduct(categoryId: 7), categories: provider));
    await _finishImageLoads(tester);
    expect(images.requests, [_categoryUrl]);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  imageTest('does not use another product category image', (tester) async {
    final provider = categories();
    addTearDown(provider.dispose);
    await tester
        .pumpWidget(_host(GetProduct(categoryId: 8), categories: provider));
    expect(images.requests, isEmpty);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
