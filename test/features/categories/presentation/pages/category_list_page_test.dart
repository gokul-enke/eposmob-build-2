import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/categories/presentation/pages/category_list_page.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/category_list_scope.dart';
import 'package:pos_machine/resources/app_translations.dart';

class DirectoryProvider extends CategoryProvider {
  List<Category> entries = List.generate(
      45,
      (i) => Category(
          categoryId: i + 1,
          categoryName: 'Category $i',
          categorySlug: 'category-$i',
          translations: {'ar': 'قسم $i'}));
  Future<void> Function()? loader, viewer;
  final scopes = <CategoryListScope>[];
  final viewed = <int>[];
  @override
  List<Category> get allCategories => List.of(entries);
  @override
  Future<void> ensureCategories(CategoryListScope scope,
      {bool force = false}) async {
    scopes.add(scope);
    await loader?.call();
  }

  @override
  Future<void> viewCategoryApi({required int categoryId}) async {
    viewed.add(categoryId);
    await viewer?.call();
  }

  void signal() => notifyListeners();
}

Map<String, String> flatten(Map<String, dynamic> source, [String prefix = '']) {
  final result = <String, String>{};
  for (final entry in source.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      result.addAll(flatten(entry.value as Map<String, dynamic>, key));
    } else {
      result[key] = entry.value.toString();
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
  });
  tearDown(Get.reset);
  Future<void> pumpPage(WidgetTester tester, DirectoryProvider provider,
      {Size size = const Size(1280, 900),
      Widget page = const CategoryListPage(),
      String locale = 'en'}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final json =
        jsonDecode(File('lib/resources/i18n/$locale.json').readAsStringSync())
            as Map<String, dynamic>;
    await tester.pumpWidget(ChangeNotifierProvider<CategoryProvider>.value(
        value: provider,
        child: GetMaterialApp(
            translations: AppTranslations({locale: flatten(json)}),
            locale: Locale(locale),
            home: Scaffold(body: page))));
    Get.updateLocale(Locale(locale));
    await tester.pump();
  }

  HeaderAction action(WidgetTester tester, IconData icon) => tester
      .widget<PageHeader>(find.byType(PageHeader))
      .actions
      .singleWhere((action) => action.icon == icon);
  testWidgets(
      'search/reset/paging matches management filtering and keeps other buckets unchanged',
      (tester) async {
    final provider = DirectoryProvider();
    provider.categoryList = [
      Category(categoryId: 999, categoryName: 'Billing only')
    ];
    await pumpPage(tester, provider);
    await tester.pumpAndSettle();
    expect(provider.scopes, [CategoryListScope.all]);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'قسم 4');
    await tester.pump(const Duration(milliseconds: 400));
    provider.filterManagementCategories(filterName: 'قسم 4');
    expect(provider.searchCategory!.length, 6);
    expect(find.text('6 categories on this page'), findsOneWidget);
    expect(find.text('Category 44'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'queued');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('20 categories on this page'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty);
    expect(provider.categoryList!.single.categoryId, 999);
    final pagination =
        tester.widget<AppPaginationBar>(find.byType(AppPaginationBar));
    pagination.onPageChanged(2);
    await tester.pump();
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.text('Category 20'), findsOneWidget);
  });
  testWidgets(
      'Add and Edit keep the existing routes and suppress double edit requests',
      (tester) async {
    final sidebar = Get.put(SideBarController());
    final provider = DirectoryProvider();
    final pending = Completer<void>();
    provider.viewer = () => pending.future;
    await pumpPage(tester, provider);
    await tester.pumpAndSettle();
    tester.widget<PageHeader>(find.byType(PageHeader)).onAdd!();
    expect(sidebar.index.value, 16);
    final edit = tester
        .widget<AppSquareIconButton>(find
            .byWidgetPredicate((widget) =>
                widget is AppSquareIconButton &&
                widget.icon == Icons.edit_outlined)
            .first)
        .onPressed!;
    edit();
    edit();
    await tester.pump();
    expect(provider.viewed, [1]);
    expect(provider.getEditCategoryId, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(sidebar.index.value, 34);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'loading blocks captured export/edit/add controls and resumes the filtered replacement',
      (tester) async {
    final sidebar = Get.put(SideBarController());
    final provider = DirectoryProvider();
    await pumpPage(tester, provider);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Category 4');
    await tester.pump(const Duration(milliseconds: 400));
    final edit = tester
        .widget<AppSquareIconButton>(find
            .byWidgetPredicate((widget) =>
                widget is AppSquareIconButton &&
                widget.icon == Icons.edit_outlined)
            .first)
        .onPressed!;
    final export = action(tester, Icons.ios_share_rounded).onPressed!;
    final add = tester.widget<PageHeader>(find.byType(PageHeader)).onAdd!;
    provider.isLoading = true;
    provider.signal();
    await tester.pump();
    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(action(tester, Icons.ios_share_rounded).onPressed, isNull);
    expect(tester.widget<PageHeader>(find.byType(PageHeader)).onAdd, isNull);
    edit();
    export();
    add();
    await tester.pump();
    expect(provider.viewed, isEmpty);
    expect(sidebar.index.value, 0);
    provider.entries = [
      Category(categoryId: 90, categoryName: 'Category 4 updated'),
      Category(categoryId: 91, categoryName: 'Unmatched')
    ];
    provider.signal();
    await tester.pump();
    expect(find.byType(AppLoadingView), findsOneWidget);
    provider.isLoading = false;
    provider.signal();
    await tester.pumpAndSettle();
    expect(find.text('Category 4 updated'), findsOneWidget);
    expect(find.text('Unmatched'), findsNothing);
    expect(action(tester, Icons.ios_share_rounded).onPressed, isNotNull);
  });
  testWidgets(
      'load error retries and empty successful data has a separate state',
      (tester) async {
    final provider = DirectoryProvider()..entries = [];
    provider.loader = () => Future.error(StateError('offline'));
    await pumpPage(tester, provider);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load categories. Please try again.'),
        findsWidgets);
    expect(action(tester, Icons.ios_share_rounded).onPressed, isNull);
    provider.loader = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No categories available'), findsWidgets);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'pending search export freezes every matching page and remains caller-owned',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('category-page-export-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pending = Completer<void>();
    File? delivered;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered = file;
      await pending.future;
    });
    addTearDown(export.dispose);
    final provider = DirectoryProvider();
    await pumpPage(tester, provider,
        page: CategoryListPage(exportController: export, exportDirectory: dir));
    await tester.pumpAndSettle();
    tester
        .widget<AppPaginationBar>(find.byType(AppPaginationBar))
        .onPageChanged(2);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Category');
    await tester.runAsync(() async {
      action(tester, Icons.ios_share_rounded).onPressed!();
      for (var i = 0; i < 100 && delivered == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(delivered, isNotNull);
    final rows = Excel.decodeBytes(delivered!.readAsBytesSync())
        .tables
        .values
        .single
        .rows;
    expect(rows.length, 46);
    expect(rows.last[1]!.value, TextCellValue('Category 44'));
    await tester.tap(find.text('Reset'));
    await tester.pump();
    provider.entries = [
      Category(categoryId: 101, categoryName: 'New directory')
    ];
    provider.signal();
    pending.complete();
    await tester.pumpAndSettle();
    expect(export.busy, isFalse);
    expect(
        Excel.decodeBytes(delivered!.readAsBytesSync())
            .tables
            .values
            .single
            .rows
            .length,
        46);
    await tester.pumpWidget(const SizedBox());
    export.setStage('still caller-owned');
  });
  testWidgets(
      'delivery failure releases busy state and empty search does not deliver',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('category-failed-export-');
    addTearDown(() => dir.deleteSync(recursive: true));
    var attempts = 0;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      attempts++;
      throw StateError('save failed');
    });
    addTearDown(export.dispose);
    await pumpPage(tester, DirectoryProvider(),
        page: CategoryListPage(exportController: export, exportDirectory: dir));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      action(tester, Icons.ios_share_rounded).onPressed!();
      for (var i = 0; i < 100 && export.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(attempts, 1);
    expect(export.busy, isFalse);
    expect(find.text('Unable to export categories. Please try again.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'no match');
    action(tester, Icons.ios_share_rounded).onPressed!();
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('No categories available'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disposal during load or edit has no late navigation/state work',
      (tester) async {
    final provider = DirectoryProvider();
    final pending = Completer<void>();
    provider.loader = () => pending.future;
    await pumpPage(tester, provider);
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final sidebar = Get.put(SideBarController());
    final editPending = Completer<void>();
    provider.loader = null;
    provider.viewer = () => editPending.future;
    await pumpPage(tester, provider);
    await tester.pumpAndSettle();
    tester
        .widget<AppSquareIconButton>(find
            .byWidgetPredicate((widget) =>
                widget is AppSquareIconButton &&
                widget.icon == Icons.edit_outlined)
            .first)
        .onPressed!();
    await tester.pumpWidget(const SizedBox());
    editPending.complete();
    await tester.pump();
    expect(sidebar.index.value, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'populated layouts and long/missing values fit phone tablet desktop and translations',
      (tester) async {
    for (final locale in ['en', 'ar', 'ml']) {
      for (final width in [375.0, 768.0, 1280.0]) {
        final provider = DirectoryProvider();
        provider.entries[0] = Category(
            categoryId: 1,
            categoryName: 'Long category name ' * 15,
            categorySlug: 'long-slug-' * 25);
        provider.entries[1] = Category(categoryId: 2);
        await pumpPage(tester, provider,
            locale: locale, size: Size(width, 900));
        await tester.pumpAndSettle();
        final expectedCount = (jsonDecode(
                File('lib/resources/i18n/$locale.json')
                    .readAsStringSync())['category']['page_count'] as String)
            .replaceAll('@count', '20');
        final actualCount = tester
            .widget<AppPaginationBar>(find.byType(AppPaginationBar))
            .countLabel;
        expect(actualCount, expectedCount,
            reason: '$locale count interpolation');
        expect(actualCount, isNot(contains('{count}')));
        expect(actualCount, isNot(contains('@count')));
        expect(find.byWidgetPredicate((widget) => widget is ListPageScaffold),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
            width < ListLayoutBreakpoints.mobileBelow
                ? find.byType(AppListCard)
                : find.byWidgetPredicate((widget) => widget is AppDataTable),
            findsWidgets);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
  testWidgets('category preview capture', (tester) async {
    final poppins = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      poppins.addFont(Future.value(ByteData.sublistView(
          File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync())));
    }
    await poppins.load();
    final regular = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf'
    ]) {
      regular.addFont(Future.value(ByteData.sublistView(File(
              '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/$name')
          .readAsBytesSync())));
    }
    await regular.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/materialicons-regular.otf')
          .readAsBytesSync())));
    await icons.load();
    for (final width in [375.0, 768.0, 1280.0]) {
      final key = GlobalKey();
      await pumpPage(tester, DirectoryProvider(),
          size: Size(width, 900),
          page: RepaintBoundary(key: key, child: const CategoryListPage()));
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final dir =
            Directory('${Directory.systemTemp.path}/category-list-previews');
        await dir.create(recursive: true);
        await File('${dir.path}/after-${width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: Platform.environment['CATEGORY_LIST_PREVIEW'] != '1');
}
