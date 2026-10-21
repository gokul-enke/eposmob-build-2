import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/view_category.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/resources/app_url.dart';

Map<String, dynamic> details({int id = 917}) => {
      'data': {
        'id': id,
        'name': 'QA Category',
        'slug': 'qa-category',
        'sellable': false,
        'purchasable': true,
        'parent_id': 16,
        'image_url': 'https://example.test/image.png',
        'icon_url': 'https://example.test/icon.png',
        'names': [
          {'code': 'en', 'name': 'QA English'},
          {'code': 'ar', 'name': 'اختبار'},
          {'code': 'hi', 'name': 'परीक्षण'},
          {'code': 'ml', 'name': 'പരീക്ഷണം'},
        ],
      },
    };

http.Response jsonResponse(Object value) =>
    http.Response(jsonEncode(value), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(
      {'api_key': 'fixture-tenant', 'active_store_id': 2}));

  test('slug details retain selected identity, tenant and store context',
      () async {
    final provider = CategoryProvider();
    addTearDown(provider.dispose);
    int notifications = 0;
    provider.addListener(() => notifications++);
    await http.runWithClient(
      () => provider.viewCategoryApi(categoryId: 917, slug: 'qa-category'),
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/category/slug/qa-category');
        expect(request.url.queryParameters, {'store_id': '2'});
        expect(request.headers['X-Tenant'], 'fixture-tenant');
        return jsonResponse(details());
      }),
    );
    final category = provider.getViewCategory!;
    expect(category.id, 917);
    expect(category.name, 'QA Category');
    expect(category.parentId, 16);
    expect(category.isSellable, false);
    expect(category.isPurchasable, true);
    expect(category.names!.en, 'QA English');
    expect(category.names!.ar, 'اختبار');
    expect(category.names!.hi, 'परीक्षण');
    expect(category.categoryImageFullPath, 'https://example.test/image.png');
    expect(category.categoryIconFullPath, 'https://example.test/icon.png');
    expect(notifications, 1);
  });

  test('slug is encoded as one path segment and store is optional', () async {
    SharedPreferences.setMockInitialValues({'api_key': 'fixture-tenant'});
    final provider = CategoryProvider();
    addTearDown(provider.dispose);
    await http.runWithClient(
      () => provider.viewCategoryApi(categoryId: 917, slug: 'قسم/a ?#'),
      () => MockClient((request) async {
        expect(
            request.url.toString(), APPUrl.categoryDetailsBySlug('قسم/a ?#'));
        expect(request.url.queryParameters, isEmpty);
        expect(request.url.fragment, isEmpty);
        return jsonResponse(details());
      }),
    );
  });

  test('blank slug prevents an HTTP request', () async {
    final provider = CategoryProvider();
    addTearDown(provider.dispose);
    await http.runWithClient(
      () => expectLater(provider.viewCategoryApi(categoryId: 917, slug: '  '),
          throwsFormatException),
      () => MockClient((_) async => fail('Must not send a blank slug')),
    );
  });

  for (final (index, response) in [
    http.Response('Not Found', 404),
    jsonResponse({'data': null}),
    jsonResponse(details(id: 918)),
    http.Response('invalid json', 200),
  ].indexed) {
    test(
        'failed or mismatched details never replace the selected model '
        'case $index', () async {
      final provider = CategoryProvider();
      addTearDown(provider.dispose);
      final previous = ViewCategory(id: 16, name: 'Previous');
      provider.viewCategory = previous;
      int notifications = 0;
      provider.addListener(() => notifications++);
      await http.runWithClient(
        () => expectLater(
            provider.viewCategoryApi(categoryId: 917, slug: 'qa-category'),
            response.statusCode == 404
                ? throwsA(isA<HttpException>())
                : throwsFormatException),
        () => MockClient((_) async => response),
      );
      expect(provider.getViewCategory, same(previous));
      expect(notifications, 0);
    });
  }

  test('legacy mapping and serialization remain supported', () {
    final category = ViewCategory.fromJson({
      'id': 917,
      'names': {'en': 'Legacy', 'ar': 'قديم', 'hi': 'पुराना'},
      'is_sellable': true,
      'is_purchasable': false,
      'category_image_full_path': 'legacy-image',
      'category_icon_full_path': 'legacy-icon',
    });
    final restored = ViewCategory.fromJson(category.toJson());
    expect(restored.names!.en, 'Legacy');
    expect(restored.names!.ar, 'قديم');
    expect(restored.isSellable, true);
    expect(restored.isPurchasable, false);
    expect(restored.categoryImageFullPath, 'legacy-image');
    expect(restored.categoryIconFullPath, 'legacy-icon');
  });
}
