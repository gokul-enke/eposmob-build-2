import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/weigh_machine/data/plu_export_service.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the product catalog the service listens to.
class _FakeCatalog extends ChangeNotifier implements LocalProductProvider {
  _FakeCatalog(this.products);

  @override
  List<GetProduct> products;

  @override
  bool isLoading = false;

  @override
  bool get isHydrated => true;

  void changed() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GetProduct _sku(int id, String name) =>
    GetProduct(productId: id, productName: name, sku: 'SKU$id');

void main() {
  late Directory documents;
  final service = PluExportService.instance;
  final originalDocuments = service.documentsDirectory;

  setUp(() async {
    service.resetForTest();
    documents = await Directory.systemTemp.createTemp('plu_documents_');
    service.documentsDirectory = () async => documents;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    service.resetForTest();
    service.documentsDirectory = originalDocuments;
    await documents.delete(recursive: true);
  });

  String defaultPath() =>
      [documents.path, 'epos', 'PLU'].join(Platform.pathSeparator);

  test('defaults to Documents/epos/PLU and creates it', () async {
    expect(Directory(defaultPath()).existsSync(), isFalse);

    expect(await service.directoryPath(), defaultPath());
    expect(Directory(defaultPath()).existsSync(), isTrue);
    expect(await service.usesCustomDirectory(), isFalse);

    final file = await service.export([
      GetProduct(productId: 1, productName: 'Apples', sku: 'APL'),
    ]);
    expect(file.path, '${defaultPath()}${Platform.pathSeparator}PLU.csv');
    expect(file.existsSync(), isTrue);
  });

  test('never writes products without an SKU', () async {
    final file = await service.export([
      GetProduct(productId: 1, productName: 'Apples', sku: 'APL'),
      GetProduct(productId: 2, productName: 'Bag'),
    ]);
    final csv = await file.readAsString();
    expect(csv, contains('Apples'));
    expect(csv, isNot(contains('Bag')));

    await expectLater(
      service.export([GetProduct(productId: 2, productName: 'Bag')]),
      throwsStateError,
    );
  });

  test('uses the active store' 's stock-row SKUs', () async {
    SharedPreferences.setMockInitialValues({'active_store_id': 35});
    final file = await service.export([
      GetProduct(
        productId: 1,
        productName: 'Mutton',
        stock: [Stock(storeId: 35, sku: '4225')],
      ),
      GetProduct(
        productId: 2,
        productName: 'Other store only',
        stock: [Stock(storeId: 2, sku: '9999')],
      ),
    ]);
    final csv = await file.readAsString();
    expect(csv, contains('Mutton'));
    expect(csv, isNot(contains('Other store only')));
  });

  test('discardFile removes PLU.csv from the default folder', () async {
    final file = await service.export([
      GetProduct(productId: 1, productName: 'Apples', sku: 'APL'),
    ]);
    File('${file.path}.tmp').writeAsStringSync('half written');
    final other = File('${defaultPath()}${Platform.pathSeparator}notes.txt')
      ..writeAsStringSync('keep me');

    await service.discardFile();

    expect(file.existsSync(), isFalse);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
    // Only the PLU files go; anything else in the folder stays.
    expect(other.existsSync(), isTrue);
  });

  test('discardFile uses the active store chosen folder', () async {
    final chosen =
        await Directory('${documents.path}${Platform.pathSeparator}scale')
            .create();
    await service.setDirectoryPath(chosen.path);
    final file = await service.export([
      GetProduct(productId: 1, productName: 'Apples', sku: 'APL'),
    ]);
    expect(file.parent.path, chosen.path);

    await service.discardFile();
    expect(file.existsSync(), isFalse);
  });

  test('discardFile is safe when there is nothing to remove', () async {
    await service.discardFile();
    // It does not create the default folder just to look inside it.
    expect(Directory(defaultPath()).existsSync(), isFalse);
  });

  test('a chosen folder wins until reset to the default', () async {
    final chosen =
        await Directory('${documents.path}${Platform.pathSeparator}scale')
            .create();

    await service.setDirectoryPath(chosen.path);
    expect(await service.directoryPath(), chosen.path);
    expect(await service.usesCustomDirectory(), isTrue);

    await service.resetDirectoryPath();
    expect(await service.directoryPath(), defaultPath());
    expect(await service.usesCustomDirectory(), isFalse);
  });

  group('Keep file up to date', () {
    late _FakeCatalog catalog;
    File plu() => File('${defaultPath()}${Platform.pathSeparator}PLU.csv');

    // Lets the shortened write delay pass and the file I/O finish.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 300));

    setUp(() async {
      service.autoWriteDelay = const Duration(milliseconds: 10);
      SharedPreferences.setMockInitialValues({
        'active_store_id': 1,
        'plu_export_local_1_auto': true,
        'plu_export_local_2_auto': true,
      });
      catalog = _FakeCatalog(
          [_sku(1, 'Apples'), GetProduct(productId: 9, productName: 'Bag')]);
      service.bind(catalog);
      await settle();
    });

    test('writes every SKU product when a product changes', () async {
      expect(plu().readAsStringSync(), contains('Apples'));
      expect(plu().readAsStringSync(), isNot(contains('Bag')));

      catalog.products = [_sku(1, 'Apples'), _sku(3, 'Bananas')];
      catalog.changed();
      await settle();
      expect(plu().readAsStringSync(), contains('Bananas'));
    });

    test('does not write when the toggle is off', () async {
      plu().deleteSync();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('plu_export_local_1_auto', false);

      catalog.changed();
      await settle();
      expect(plu().existsSync(), isFalse);
    });

    test('a store switch never writes the old store back', () async {
      // Store 1 is active and its file is in place.
      expect(plu().existsSync(), isTrue);

      // bootstrapStore: discard, then clear the old catalog.
      await service.discardFile();
      expect(plu().existsSync(), isFalse);

      // A change while the old catalog is still in memory: no write.
      catalog.changed();
      await settle();
      expect(plu().existsSync(), isFalse);

      // Old catalog cleared; store 2 becomes active: still nothing.
      catalog.products = [];
      catalog.changed();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_store_id', 2);
      await settle();
      expect(plu().existsSync(), isFalse);

      // Store 2's products load: now its own file is written.
      catalog.isLoading = true;
      catalog.changed();
      catalog.products = [_sku(5, 'Dates')];
      catalog.isLoading = false;
      catalog.changed();
      await settle();
      final csv = plu().readAsStringSync();
      expect(csv, contains('Dates'));
      expect(csv, isNot(contains('Apples')));
    });

    test('a load that finishes before the clear does not release the hold',
        () async {
      await service.discardFile();

      // An old-store load was already running when the discard happened.
      catalog.isLoading = true;
      catalog.changed();
      catalog.isLoading = false;
      catalog.changed();
      await settle();
      expect(plu().existsSync(), isFalse);
    });
  });
}
