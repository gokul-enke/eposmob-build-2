import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/models/view_category.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/category_list_scope.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/resources/app_translations.dart';
import 'package:pos_machine/screens/category/add_category_screen.dart';
import 'package:pos_machine/screens/category/edit_category_screen.dart';

class _Auth extends AuthModel {
  @override
  String? get token => 'fixture-token';
}

class _Languages extends LanguageProvider {
  int loads = 0;
  @override
  List<Language> get languages => [
        Language(id: 1, name: 'English', code: 'en', type: 'ltr', active: true),
        Language(id: 2, name: 'Arabic', code: 'ar', type: 'rtl', active: true),
        Language(id: 3, name: 'Hindi', code: 'hi', type: 'ltr', active: true),
      ];
  @override
  Future<void> fetchLanguages({required String accessToken}) async {
    loads++;
  }

  @override
  Future<String?> translateText(
          {required String accessToken,
          required String targetLang,
          required String text}) async =>
      '$targetLang:$text';
}

class _Grid extends GridSelectionProvider {
  int loads = 0;
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
  @override
  Future<dynamic> getProductListFilesAPI({required String accessToken}) async {
    loads++;
    return {'status': 'success', 'data': []};
  }
}

class _Directory extends CategoryProvider {
  final scopes = <CategoryListScope>[];
  final requests = <Map<String, Object?>>[];
  int refreshes = 0;
  String result = 'success';
  @override
  List<Category> get allCategories => [
        Category(categoryId: 7, categoryName: 'Parent', categorySlug: 'parent'),
      ];
  @override
  ViewCategory? get getViewCategory => ViewCategory.fromJson({
        'id': 42,
        'parent_id': 7,
        'name': 'Existing Category',
        'slug': 'custom-old-slug',
        'category_image': '11',
        'category_icon': '12',
        'names': [
          {'code': 'en', 'name': 'Old English'},
          {'code': 'ar', 'name': 'قديم'},
          {'code': 'hi', 'name': 'पुराना'},
        ],
        'sellable': false,
        'purchasable': true,
      });
  @override
  int get getEditCategoryId => 42;
  @override
  Future<void> ensureCategories(CategoryListScope scope,
      {bool force = false}) async {
    scopes.add(scope);
  }

  @override
  Future<void> refreshCategories() async {
    refreshes++;
  }

  @override
  Future<dynamic> addCategory(
      {required String categoryName,
      required String slug,
      required String parentCategory,
      required String categoryNameEnglish,
      required String categoryNameHindi,
      required String categoryNameArabic,
      required String imagePath,
      required String iconPath,
      required String accessToken,
      bool isSellable = true,
      bool isPurchasable = true,
      String? description,
      List<int>? productPropertyIds,
      List<int>? taxIds,
      Map<String, String>? categoryLangNames}) async {
    requests.add({
      'name': categoryName,
      'slug': slug,
      'parent': parentCategory,
      'en': categoryNameEnglish,
      'hi': categoryNameHindi,
      'ar': categoryNameArabic,
      'image': imagePath,
      'icon': iconPath,
      'token': accessToken,
      'sellable': isSellable,
      'purchasable': isPurchasable,
      'description': description,
      'properties': productPropertyIds,
      'taxes': taxIds,
      'languages': categoryLangNames
    });
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return {'status': result, 'message': 'Fixture response'};
  }

  @override
  Future<dynamic> editCategory(
      {required int categoryId,
      required String categoryName,
      required String slug,
      required String parentCategory,
      required String categoryNameEnglish,
      required String categoryNameHindi,
      required String categoryNameArabic,
      required String imagePath,
      required String iconPath,
      required String accessToken,
      bool isSellable = true,
      bool isPurchasable = true}) async {
    requests.add({
      'id': categoryId,
      'name': categoryName,
      'slug': slug,
      'parent': parentCategory,
      'en': categoryNameEnglish,
      'hi': categoryNameHindi,
      'ar': categoryNameArabic,
      'image': imagePath,
      'icon': iconPath,
      'token': accessToken,
      'sellable': isSellable,
      'purchasable': isPurchasable
    });
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return {'status': result, 'message': 'Fixture response'};
  }
}

Map<String, String> _flatten(Map<String, dynamic> source,
    [String prefix = '']) {
  final result = <String, String>{};
  for (final entry in source.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
    } else {
      result[key] = entry.value.toString();
    }
  }
  return result;
}

Future<_Directory> _mount(WidgetTester tester,
    {bool edit = false,
    Size size = const Size(1280, 1000),
    String locale = 'en'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final directory = _Directory();
  final languages = _Languages();
  final grid = _Grid();
  final translations =
      jsonDecode(File('lib/resources/i18n/$locale.json').readAsStringSync());
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>(create: (_) => _Auth()),
        ChangeNotifierProvider<CategoryProvider>.value(value: directory),
        ChangeNotifierProvider<LanguageProvider>.value(value: languages),
        ChangeNotifierProvider<GridSelectionProvider>.value(value: grid),
      ],
      child: RepaintBoundary(
          key: const ValueKey('category-form-preview'),
          child: GetMaterialApp(
            translations: AppTranslations({locale: _flatten(translations)}),
            locale: Locale(locale),
            home: Scaffold(
                body: edit
                    ? const EditCategoryPageScreen()
                    : const AddCategoryPageScreen()),
          ))));
  await tester.pumpAndSettle();
  expect(languages.loads, 1);
  expect(grid.loads, 1);
  expect(directory.scopes, [CategoryListScope.all]);
  return directory;
}

Finder _input(WidgetTester tester, String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint);

Future<void> _submit(WidgetTester tester) async {
  final submit = find.text('category.btn_submit'.tr);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

// Record the legacy edit disposal defect explicitly; do not swallow other errors.
Future<void> _unmount(WidgetTester tester, {bool edit = false}) async {
  // Let transient feedback finish before exercising the page disposal path.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  await tester.pumpWidget(const SizedBox.shrink());
  final error = tester.takeException();
  if (edit) {
    expect(error, isA<FlutterError>());
    expect(error.toString(),
        contains('TextEditingController was used after being disposed'));
  } else {
    expect(error, isNull);
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(Get.reset);

  testWidgets('Add validates required fields without submitting',
      (tester) async {
    final directory = await _mount(tester);
    await _submit(tester);
    expect(directory.requests, isEmpty);
    expect(directory.refreshes, 0);
    expect(find.text('category.err_name_required'.tr), findsWidgets);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
      'Add keeps slug, translations, switches, payload and success navigation',
      (tester) async {
    final directory = await _mount(tester);
    await tester.enterText(
        _input(tester, 'category.col_name'.tr), '  Demo & Snacks  ');
    final slug =
        tester.widget<TextField>(_input(tester, 'category.field_slug_hint'.tr));
    expect(slug.controller!.text, '-demo--snacks-');
    expect(slug.readOnly, isTrue);
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await _submit(tester);
    expect(directory.requests.single['name'], 'Demo & Snacks');
    expect(directory.requests.single['en'], 'Demo & Snacks');
    expect(directory.requests.single['slug'], '-demo--snacks-');
    expect(directory.requests.single['parent'], '0');
    expect(directory.requests.single['languages'], {'en': 'Demo & Snacks'});
    expect(directory.requests.single['sellable'], false);
    expect(directory.requests.single['purchasable'], true);
    expect(directory.requests.single['taxes'], isNull);
    expect(directory.requests.single['image'], '');
    expect(directory.requests.single['icon'], '');
    expect(directory.refreshes, 1);
    expect(Get.find<SideBarController>().index.value, 12);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('Add failure retains entered values and does not refresh',
      (tester) async {
    final directory = await _mount(tester);
    directory.result = 'failed';
    await tester.enterText(
        _input(tester, 'category.col_name'.tr), 'Retry category');
    await _submit(tester);
    expect(directory.requests, hasLength(1));
    expect(directory.refreshes, 0);
    expect(
        tester
            .widget<TextField>(_input(tester, 'category.col_name'.tr))
            .controller!
            .text,
        'Retry category');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
      'Edit prefill retains existing slug-from-name and parent behavior',
      (tester) async {
    final directory = await _mount(tester, edit: true);
    final values = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(
        values,
        containsAll(
            ['Existing Category', 'existing-category', 'قديم', 'पुराना']));
    expect(directory.getParentCategory, '7');
    expect(directory.selectedCategoryIndex, 0);
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((w) => w.value),
        [false, true]);
    expect(tester.takeException(), isNull);
    await _unmount(tester, edit: true);
  });

  testWidgets('Edit failure keeps original request contract and fields',
      (tester) async {
    final directory = await _mount(tester, edit: true);
    directory.result = 'failed';
    await _submit(tester);
    expect(directory.requests.single, {
      'id': 42,
      'name': 'Existing Category',
      'slug': 'existing-category',
      'parent': '7',
      'en': 'Old English',
      'hi': 'पुराना',
      'ar': 'قديم',
      'image': '11',
      'icon': '12',
      'token': 'fixture-token',
      'sellable': false,
      'purchasable': true,
    });
    expect(directory.refreshes, 0);
    expect(tester.takeException(), isNull);
    await _unmount(tester, edit: true);
  });

  testWidgets('Edit success refreshes, clears inputs and returns to the list',
      (tester) async {
    final directory = await _mount(tester, edit: true);
    await _submit(tester);
    expect(directory.requests.single['id'], 42);
    expect(directory.refreshes, 1);
    expect(Get.find<SideBarController>().index.value, 12);
    expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.controller!.text.isEmpty),
        isTrue);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  final preview = Platform.environment['CATEGORY_FORM_GOLDEN_MODE'];
  if (preview != null) {
    for (final edit in [false, true]) {
      for (final entry in {
        'desktop': (const Size(1280, 1000), 'en'),
        'phone': (const Size(375, 1000), 'en'),
        'arabic': (const Size(1280, 1000), 'ar'),
      }.entries) {
        testWidgets('before/after ${edit ? 'edit' : 'add'} ${entry.key}',
            (tester) async {
          await _mount(tester,
              edit: edit, size: entry.value.$1, locale: entry.value.$2);
          final errors = <String>[];
          Object? error;
          while ((error = tester.takeException()) != null) {
            errors.add(error.toString());
          }
          final name = '${edit ? 'edit' : 'add'}-${entry.key}';
          final file = File(
              '${Directory.systemTemp.path}/category-form-$name-errors.txt');
          if (preview == 'baseline') {
            file.writeAsStringSync(errors.join('\n'));
          } else {
            expect(errors.join('\n'), file.readAsStringSync());
          }
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('category-form-preview')));
          expect(boundary.debugNeedsPaint, isFalse);
          await expectLater(
              find.byKey(const ValueKey('category-form-preview')),
              matchesGoldenFile(Uri.file(
                  '${Directory.systemTemp.path}/category-form-$name.png')));
          await _unmount(tester, edit: edit);
        });
      }
    }
  }
}
