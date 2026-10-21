import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers the product code generators and product create; anything else
/// (the provider's own startup loads) gets a 404.
class _Server {
  final requests = <http.Request>[];
  int skuStatus = 200;
  String skuBody = jsonEncode({
    'status': 'success',
    'message': 'SKU generated',
    'data': {'sku': '4227'}
  });

  MockClient get client => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/product/generate-sku')) {
          return http.Response(skuBody, skuStatus);
        }
        if (path.endsWith('/product/generate-barcode')) {
          return http.Response(
              jsonEncode({
                'status': 'success',
                'data': {'barcode': '1110005'}
              }),
              200);
        }
        if (request.method == 'POST') {
          return http.Response(
              jsonEncode({'status': 'success', 'data': {}}), 200);
        }
        return http.Response('not found', 404);
      });

  http.Request last(String pathEnd) =>
      requests.lastWhere((r) => r.url.path.endsWith(pathEnd));
}

/// Skips the provider's startup product loads, which this test does not use.
class _Provider extends GridSelectionProvider {
  @override
  Future<void> listAllProducts(
      {int? categoryId,
      String? filterName,
      String? filterCategory,
      String? filterBarcode,
      String? filterPrice,
      String? filterCreatedBy,
      String? filterProperties,
      String? filterStore,
      String? filterSupplier,
      int page = 1}) async {}
  @override
  Future<void> listAllProductsAPI({int? categoryId, String? barCode}) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {'api_key': 'tenant', 'active_store_id': 2}));

  Future<T> withServer<T>(
          _Server server, Future<T> Function(GridSelectionProvider) body) =>
      http.runWithClient(() async {
        return body(_Provider());
      }, () => server.client);

  test('generate SKU calls the SKU endpoint for the active store', () async {
    final server = _Server();
    final result = await withServer(
        server, (p) => p.generateSkuAPI(accessToken: 'token'));

    expect(result?['status'], 'success');
    expect(result?['data']['sku'], '4227');
    final request = server.last('/product/generate-sku');
    expect(request.method, 'GET');
    expect(request.url.queryParameters, {'store_id': '2'});
    expect(request.headers['Authorization'], 'Bearer token');
    expect(request.headers['X-Tenant'], 'tenant');
  });

  test('generate SKU reports failure on HTTP errors and bad bodies', () async {
    for (final (status, body) in [
      (500, 'boom'),
      (200, 'not json'),
      (200, '[1, 2]'),
    ]) {
      final server = _Server()
        ..skuStatus = status
        ..skuBody = body;
      final result = await withServer(
          server, (p) => p.generateSkuAPI(accessToken: 'token'));
      expect(result?['status'], 'failed', reason: '$status $body');
    }
  });

  test('generateSku returns the trimmed SKU, or null when unusable', () async {
    Future<String?> sku(int status, Object body) {
      final server = _Server()
        ..skuStatus = status
        ..skuBody = body is String ? body : jsonEncode(body);
      return withServer(server, (p) => p.generateSku(accessToken: 'token'));
    }

    expect(
        await sku(200, {
          'status': 'success',
          'data': {'sku': ' 4227 '}
        }),
        '4227');
    expect(
        await sku(200, {
          'status': 'success',
          'data': {'sku': 4228}
        }),
        '4228');
    expect(
        await sku(200, {
          'status': 'success',
          'data': {'sku': '  '}
        }),
        isNull);
    expect(await sku(200, {'status': 'success', 'data': null}), isNull);
    expect(
        await sku(200, {
          'status': 'failed',
          'data': {'sku': '1'}
        }),
        isNull);
    expect(await sku(500, 'boom'), isNull);
  });

  test('barcode generation still uses the barcode endpoint', () async {
    final server = _Server();
    final result = await withServer(
        server, (p) => p.generateBarcodeAPI(accessToken: 'token'));
    expect(result?['data']['barcode'], '1110005');
    expect(server.last('/product/generate-barcode').url.queryParameters,
        {'store_id': '2'});
  });

  test('create product sends a trimmed sku, and omits a blank one', () async {
    Future<Map<String, dynamic>> created(String? sku) async {
      final server = _Server();
      await withServer(
          server,
          (p) => p.createProductAPI(
              categoryId: '1',
              productName: 'Tea',
              sellingPrice: '10',
              mrp: '12',
              quantity: '0',
              unit: 'PCS',
              barcode: '1110005',
              accessToken: 'token',
              purchasePrice: '8',
              sku: sku));
      final post = server.requests.lastWhere((r) => r.method == 'POST');
      return jsonDecode(post.body) as Map<String, dynamic>;
    }

    expect((await created(' 4227 '))['sku'], '4227');
    expect((await created('   ')).containsKey('sku'), isFalse);
    expect((await created(null)).containsKey('sku'), isFalse);
  });

  test('edit product sends sku only when given, and clears it when blank',
      () async {
    Future<Map<String, dynamic>> edited(String? sku) async {
      final server = _Server();
      await http.runWithClient(
          () => ProductProvider().editProduct(
              productId: 7,
              name: 'Tea',
              slug: 'tea',
              barcode: '1110005',
              unit: 'PCS',
              sku: sku,
              accessToken: 'token'),
          () => server.client);
      final post = server.requests.lastWhere((r) => r.method == 'POST');
      return jsonDecode(post.body) as Map<String, dynamic>;
    }

    expect((await edited(' 4227 '))['sku'], '4227');
    final cleared = await edited('  ');
    expect(cleared.containsKey('sku'), isTrue);
    expect(cleared['sku'], isNull);
    expect((await edited(null)).containsKey('sku'), isFalse);
  });

  test('create and edit ask the server for JSON errors', () async {
    final server = _Server();
    await withServer(
        server,
        (p) => p.createProductAPI(
            categoryId: '1',
            productName: 'Tea',
            sellingPrice: '10',
            mrp: '12',
            quantity: '0',
            unit: 'PCS',
            barcode: '1',
            accessToken: 'token',
            purchasePrice: '8'));
    expect(server.requests.last.headers['Accept'], 'application/json');

    await http.runWithClient(
        () => ProductProvider().editProduct(
            productId: 7,
            name: 'Tea',
            slug: 'tea',
            barcode: '1',
            unit: 'PCS',
            accessToken: 'token'),
        () => server.client);
    expect(server.requests.last.headers['Accept'], 'application/json');
  });

  test('create errors show the server message, never an HTML page', () {
    expect(
        AddProductFormHelpers.parseCreateProductError(
            '{"message": "Class \\"Company\\" not found"}'),
        'Class "Company" not found');
    expect(
        AddProductFormHelpers.parseCreateProductError(
            '<!DOCTYPE html><html lang="en">...'),
        'Failed to add product');
    expect(AddProductFormHelpers.parseCreateProductError('Plain text error'),
        'Plain text error');
  });
}
